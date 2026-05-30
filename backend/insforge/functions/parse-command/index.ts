const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};

type CommandBody = {
  text?: string;
  context?: Record<string, unknown>;
};

export default async function(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const body = await req.json().catch(() => ({})) as CommandBody;
  const text = body.text?.trim();
  if (!text) {
    return json({ error: "text is required" }, 400);
  }

  const apiKey = Deno.env.get("AI_GATEWAY_API_KEY") ?? Deno.env.get("API_KEY");
  const model = Deno.env.get("AI_GATEWAY_MODEL") ?? "moonshotai/kimi-k2.6";

  if (!apiKey) {
    return json(await nutritionAwareFallback(text, body.context ?? {}));
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 18000);
  let gatewayResponse: Response;
  try {
    gatewayResponse = await fetch("https://ai-gateway.vercel.sh/v1/chat/completions", {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model,
        messages: [
          {
            role: "system",
            content: [
              "Parse Fitcountable commands into strict JSON.",
              "Allowed action_type values: log_workout, log_meal, estimate_food, update_goal, create_workout_plan, create_nutrition_plan, create_accountability_nudge, summarize_progress, correct_last_log.",
              "Include top-level title, meal_type, calories, protein, carbs, fat, weekly_workouts, duration_minutes, and target_friend_id when the command implies them.",
              "food_items must use name, quantity_text, calories, protein_g, carbs_g, fat_g, confidence.",
              "workout_sets must use exercise_name, set_index, reps, weight, unit, rpe, notes.",
              "Return only JSON with action_type, confidence, requires_confirmation, summary, title, meal_type, calories, protein, carbs, fat, weekly_workouts, duration_minutes, target_friend_id, entities, proposed_records, user_editable_fields, missing_fields, assumptions, workout_sets, and food_items.",
              "Nutrition values are informational estimates and must be editable.",
              "Preserve the user's exact food words. Do not turn a burrito into a burrito bowl, a sandwich into a salad, or a generic food into a restaurant item unless the user said that.",
              "Classify food and drink as log_meal or estimate_food even if a food word contains an exercise substring, such as espresso containing press. Only classify log_workout when the text clearly describes exercise, sets, reps, weights, cardio, or training.",
              "For meal and food estimates, use this sequence: user's saved_foods context first, then Spoonacular/database evidence, then AI reconciles the final food list, portions, and estimate from the available context. Do not use hardcoded nutrition defaults. If there is not enough information for a meaningful estimate after that reasoning pass, say more info is needed and include a specific missing_fields value."
            ].join(" ")
          },
          {
            role: "user",
            content: JSON.stringify({ text, context: body.context ?? {} })
          }
        ],
        response_format: { type: "json" },
        temperature: 0.1,
        max_tokens: 900
      })
    });
  } catch (error) {
    const fallback = await nutritionAwareFallback(text, body.context ?? {});
    fallback.assumptions.push(error instanceof DOMException && error.name === "AbortError"
      ? "Fast parser used because AI took longer than the realtime UX target."
      : "AI Gateway request failed; fallback parser used.");
    return json(fallback);
  } finally {
    clearTimeout(timeout);
  }

  if (!gatewayResponse.ok) {
    const fallback = await nutritionAwareFallback(text, body.context ?? {});
    fallback.assumptions.push(`AI Gateway request failed with status ${gatewayResponse.status}; fallback parser used.`);
    return json(fallback);
  }

  const payload = await gatewayResponse.json();
  const content = payload?.choices?.[0]?.message?.content;
  if (!content) {
    const fallback = await nutritionAwareFallback(text, body.context ?? {});
    fallback.assumptions.push("AI Gateway returned an empty response; fallback parser used.");
    return json(fallback);
  }

  try {
    return json(await enrichFoodProposal(normalizeProposal(JSON.parse(content), text, body.context ?? {}), text, body.context ?? {}));
  } catch {
    const fallback = await nutritionAwareFallback(text, body.context ?? {});
    fallback.assumptions.push("AI Gateway returned invalid JSON; fallback parser used.");
    return json(fallback);
  }
}

async function nutritionAwareFallback(text: string, context: Record<string, unknown>) {
  return await enrichFoodProposal(localFallback(text, context), text, context);
}

function normalizeProposal(raw: Record<string, unknown>, text: string, context: Record<string, unknown> = {}) {
  const allowedActions = new Set([
    "log_workout",
    "log_meal",
    "estimate_food",
    "update_goal",
    "create_workout_plan",
    "create_nutrition_plan",
    "create_accountability_nudge",
    "summarize_progress",
    "correct_last_log"
  ]);
  let action = typeof raw.action_type === "string"
    ? raw.action_type === "log_food" ? "log_meal" : raw.action_type
    : "log_meal";
  const workoutSets = Array.isArray(raw.workout_sets) ? raw.workout_sets.map(normalizeWorkoutSet) : [];
  const foodItems = Array.isArray(raw.food_items) ? raw.food_items.map((item) => normalizeFoodItem(item, text)) : [];
  if (isLikelyFoodCommand(text) && !isLikelyWorkoutCommand(text)) {
    action = foodItems.length > 0 ? "log_meal" : action === "estimate_food" ? "estimate_food" : "log_meal";
  }
  if (action === "log_workout" && workoutSets.length === 0 && isLikelyFoodCommand(text)) {
    action = "log_meal";
  }
  const proposedRecords = isRecord(raw.proposed_records) ? raw.proposed_records : {};
  const workoutRecord = isRecord(proposedRecords.workout) ? proposedRecords.workout : {};
  const mealRecord = isRecord(proposedRecords.meal) ? proposedRecords.meal : {};
  const goalRecord = isRecord(proposedRecords.goal) ? proposedRecords.goal : {};
  const contextMealType = mealTypeFromContext(context);
  const rawMealType = normalizeMealType(stringValue(raw.meal_type, mealRecord.meal_type, mealRecord.type, ""));

  return {
    action_type: allowedActions.has(action) ? action : "log_meal",
    confidence: clampNumber(raw.confidence, 0.7, 0, 1),
    requires_confirmation: typeof raw.requires_confirmation === "boolean" ? raw.requires_confirmation : true,
    summary: typeof raw.summary === "string" ? raw.summary : "Review this parsed command before saving.",
    title: stringValue(raw.title, workoutRecord.title, mealRecord.title, action === "log_workout" ? inferWorkoutTitle(text) : ""),
    meal_type: shouldUseContextMealType(text, contextMealType) ? contextMealType : rawMealType,
    calories: integerOrNull(raw.calories, raw.calories_target, goalRecord.calories),
    protein: integerOrNull(raw.protein, raw.protein_g, raw.protein_target, goalRecord.protein, goalRecord.protein_g),
    carbs: integerOrNull(raw.carbs, raw.carbs_g, raw.carbs_target, goalRecord.carbs, goalRecord.carbs_g),
    fat: integerOrNull(raw.fat, raw.fat_g, raw.fat_target, goalRecord.fat, goalRecord.fat_g),
    weekly_workouts: integerOrNull(raw.weekly_workouts, raw.workouts_per_week, goalRecord.weekly_workouts, goalRecord.workouts_per_week),
    duration_minutes: integerOrNull(raw.duration_minutes, raw.duration, workoutRecord.duration_minutes, workoutRecord.duration),
    target_friend_id: stringValue(raw.target_friend_id, raw.friend_id, proposedRecords.target_friend_id, ""),
    entities: isRecord(raw.entities) ? raw.entities : {},
    proposed_records: proposedRecords,
    user_editable_fields: stringArray(raw.user_editable_fields),
    missing_fields: stringArray(raw.missing_fields),
    assumptions: stringArray(raw.assumptions),
    workout_sets: workoutSets,
    food_items: foodItems
  };
}

function normalizeWorkoutSet(raw: unknown) {
  const item = isRecord(raw) ? raw : {};
  return {
    exercise_name: stringValue(item.exercise_name, item.exercise, "Exercise"),
    set_index: Math.max(1, Math.round(numberValue(item.set_index, item.set, 1))),
    reps: Math.max(0, Math.round(numberValue(item.reps, item.repetitions, 0))),
    weight: Math.max(0, numberValue(item.weight, item.weight_lb, 0)),
    unit: item.unit === "kg" ? "kg" : "lb",
    rpe: item.rpe == null ? null : clampNumber(item.rpe, 0, 0, 10),
    notes: typeof item.notes === "string" ? item.notes : ""
  };
}

function normalizeFoodItem(raw: unknown, text: string) {
  const item = isRecord(raw) ? raw : {};
  const nutrition = isRecord(item.estimated_nutrition) ? item.estimated_nutrition : {};
  return {
    name: stringValue(item.name, item.food, text),
    quantity_text: stringValue(item.quantity_text, item.estimated_quantity, item.serving_estimate, "1 serving"),
    calories: Math.max(0, Math.round(numberValue(item.calories, item.estimated_calories, nutrition.calories, 0))),
    protein_g: Math.max(0, numberValue(item.protein_g, item.estimated_protein_g, nutrition.protein_g, 0)),
    carbs_g: Math.max(0, numberValue(item.carbs_g, item.estimated_carbs_g, nutrition.carbs_g, 0)),
    fat_g: Math.max(0, numberValue(item.fat_g, item.estimated_fat_g, nutrition.fat_g, 0)),
    confidence: clampNumber(item.confidence, 0.72, 0, 1)
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function stringValue(...values: unknown[]): string {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }
  return "";
}

function numberValue(...values: unknown[]): number {
  for (const value of values) {
    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }
  }
  return 0;
}

function clampNumber(value: unknown, fallback: number, min: number, max: number): number {
  const number = numberValue(value, fallback);
  return Math.min(max, Math.max(min, number));
}

function localFallback(text: string, context: Record<string, unknown> = {}) {
  const lower = text.toLowerCase();

  if (isGoalUpdate(lower)) {
    return {
      action_type: "update_goal",
      confidence: 0.8,
      requires_confirmation: true,
      summary: "Drafted goal changes from your command. Review targets before saving.",
      title: "Goal update",
      meal_type: null,
      calories: matchNumber(lower, /\b(\d{3,4})\s*(?:cal|cals|calories)\b/),
      protein: matchNumber(lower, /\b(\d{2,3})\s*(?:g\s*)?protein\b/),
      carbs: matchNumber(lower, /\b(\d{2,3})\s*(?:g\s*)?carbs?\b/),
      fat: matchNumber(lower, /\b(\d{2,3})\s*(?:g\s*)?fat\b/),
      weekly_workouts: matchNumber(lower, /\b(\d)\s*(?:workouts?|gym sessions?|lifts?)\s*(?:per|a)?\s*week\b/),
      duration_minutes: null,
      target_friend_id: null,
      entities: {},
      proposed_records: {},
      user_editable_fields: ["calories", "protein", "carbs", "fat", "weekly_workouts"],
      missing_fields: [],
      assumptions: ["Fast parser used; verify goal targets before saving."],
      workout_sets: [],
      food_items: []
    };
  }

  if (lower.includes("nudge") || lower.includes("accountability") || lower.includes("accountable")) {
    return {
      action_type: "create_accountability_nudge",
      confidence: 0.76,
      requires_confirmation: true,
      summary: "Drafted an accountability nudge. Review before sending or saving.",
      title: "Accountability nudge",
      meal_type: null,
      calories: null,
      protein: null,
      carbs: null,
      fat: null,
      weekly_workouts: null,
      duration_minutes: null,
      target_friend_id: null,
      entities: {},
      proposed_records: {},
      user_editable_fields: ["target_friend_id", "summary"],
      missing_fields: ["target friend"],
      assumptions: ["Fast parser used; choose the recipient before sending a nudge."],
      workout_sets: [],
      food_items: []
    };
  }

  if (isLikelyWorkoutCommand(lower) && !isLikelyFoodCommand(lower)) {
    const workoutSets = inferWorkoutSets(text);
    return {
      action_type: "log_workout",
      confidence: workoutSets.length > 1 ? 0.82 : 0.78,
      requires_confirmation: true,
      summary: "Drafted a workout from the command. Review before saving.",
      title: inferWorkoutTitle(text),
      meal_type: null,
      calories: null,
      protein: null,
      carbs: null,
      fat: null,
      weekly_workouts: null,
      duration_minutes: inferDuration(text),
      target_friend_id: null,
      entities: {},
      proposed_records: {},
      user_editable_fields: ["workout_sets", "duration"],
      missing_fields: [],
      assumptions: ["Fast parser used; review exercise names, loads, and reps before saving."],
      workout_sets: workoutSets,
      food_items: []
    };
  }

  const foodItems = inferFoodItems(text);

  return {
    action_type: "log_meal",
    confidence: foodItems.length > 1 ? 0.82 : 0.8,
    requires_confirmation: true,
    summary: "Estimated a meal from your description. Review before saving.",
    title: "Estimated meal",
    meal_type: mealTypeFromContext(context) ?? inferMealType(text),
    calories: null,
    protein: null,
    carbs: null,
    fat: null,
    weekly_workouts: null,
    duration_minutes: null,
    target_friend_id: null,
    entities: {},
    proposed_records: {},
    user_editable_fields: ["food_items"],
    missing_fields: [],
    assumptions: needsFoodPortionDetail(text, foodItems)
      ? ["Fast parser used; portion was inferred from a typical serving."]
      : ["Fast parser used; serving detail was applied where possible."],
    workout_sets: [],
    food_items: foodItems
  };
}

function needsFoodPortionDetail(text: string, foodItems: Array<{ confidence: number; quantity_text: string }>): boolean {
  const lower = text.toLowerCase();
  const hasPortionClue = [
    /\b\d+(\.\d+)?\s*(cup|cups|oz|ounce|ounces|g|grams|lb|lbs|pound|pounds|slice|slices|piece|pieces|bowl|plate|serving|servings)\b/,
    /\b(one|two|three|four|five|six|half)\s+(cup|cups|bowl|plate|serving|servings|slice|slices|piece|pieces)\b/,
    /\b(small|medium|large)\s+(bowl|plate|serving|portion|order)\b/,
    /\b(chipotle|mcdonald|starbucks|sweetgreen|cava|subway|restaurant|menu)\b/
  ].some((pattern) => pattern.test(lower));
  if (hasPortionClue) return false;
  return foodItems.some((item) => item.confidence < 0.72 || item.quantity_text === "1 serving" || item.quantity_text === "1 typical serving");
}

function isLikelyFoodCommand(text: string): boolean {
  const lower = text.toLowerCase();
  const foodPatterns = [
    /\b(ate|eat|eating|drank|drink|drinking|had|having|meal|breakfast|lunch|dinner|snack|food|calories|macros?)\b/,
    /\b(coffee|espresso|latte|juice|smoothie|milk|yogurt|cereal|oats|rice|yam|fries|sauce|stew|soup|salad|sandwich|burrito|chicken|beef|goat|fish|eggs?|protein shake|chobani|starbucks|mcdonald|lucky charms)\b/,
    /\b(cup|cups|bowl|plate|serving|servings|slice|slices|packet|packets|oz|ounce|ounces|grams?)\b/
  ];
  return foodPatterns.some((pattern) => pattern.test(lower));
}

function isLikelyWorkoutCommand(text: string): boolean {
  const lower = text.toLowerCase();
  const workoutPatterns = [
    /\b(workout|training|trained|lifted|lifting|gym|cardio|run|ran|treadmill|elliptical)\b/,
    /\b(bench(?:\s+press)?|chest\s+press|leg\s+press|overhead\s+press|shoulder\s+press|squat|deadlift|row|curl|pushdown|pull[-\s]?up|push[-\s]?up)\b/,
    /\b\d+\s*(?:x|sets?\s+of)\s*\d+\b/,
    /\b\d+\s*reps?\b/,
    /\b(?:at|@|with)\s*\d{2,4}\s*(?:lb|lbs|pounds|kg)\b/
  ];
  return workoutPatterns.some((pattern) => pattern.test(lower));
}

function inferWorkoutSets(text: string) {
  const lower = text.toLowerCase();
  const sets = [];
  const exerciseHints = [
    { tokens: ["bench"], name: "Bench Press", defaultWeight: 185, defaultReps: 5 },
    { tokens: ["squat"], name: "Back Squat", defaultWeight: 225, defaultReps: 5 },
    { tokens: ["deadlift"], name: "Deadlift", defaultWeight: 275, defaultReps: 5 },
    { tokens: ["row"], name: "Row", defaultWeight: 135, defaultReps: 8 },
    { tokens: ["curl"], name: "Curl", defaultWeight: 30, defaultReps: 12 },
    { tokens: ["pushdown", "tricep"], name: "Triceps Pushdown", defaultWeight: 70, defaultReps: 12 },
    { tokens: ["press"], name: "Overhead Press", defaultWeight: 95, defaultReps: 8 },
    { tokens: ["run", "cardio"], name: "Cardio", defaultWeight: 0, defaultReps: 1 }
  ];
  const firstWeight = inferFirstWeight(lower);
  const firstReps = inferFirstReps(lower);
  const setCount = inferSetCount(lower);

  for (const hint of exerciseHints) {
    if (hint.name === "Overhead Press" && (lower.includes("bench press") || lower.includes("chest press"))) {
      continue;
    }
    if (hint.tokens.some((token) => lower.includes(token))) {
      const inferredWeight = hint.tokens.includes("bench") && firstWeight ? firstWeight : hint.defaultWeight;
      for (let index = 0; index < setCount; index += 1) {
        sets.push({
          exercise_name: hint.name,
          set_index: sets.length + 1,
          reps: firstReps ?? hint.defaultReps,
          weight: inferredWeight,
          unit: "lb",
          rpe: null,
          notes: ""
        });
      }
    }
  }

  return sets.length > 0 ? sets : [
    { exercise_name: "Workout", set_index: 1, reps: 1, weight: 0, unit: "lb", rpe: null, notes: text }
  ];
}

function inferFirstWeight(lower: string): number | null {
  return matchNumber(lower, /\b(?:at|@|with)\s*(\d{2,4})\s*(?:lb|lbs|pounds|kg)?\b/)
    ?? matchNumber(lower, /\b(?:bench|squat|deadlift|row|curl|press)\s+(?:press\s+)?(\d{2,4})\b/)
    ?? matchNumber(lower, /\b(\d{2,4})\s*(?:lb|lbs|pounds|kg)\b/);
}

function inferFirstReps(lower: string): number | null {
  return matchNumber(lower, /\b(\d{1,2})\s*reps?\b/)
    ?? matchNumber(lower, /\b\d{1,2}\s*sets?\s+of\s+(\d{1,2})\b/)
    ?? matchNumber(lower, /\bfor\s+\d{1,2}\s*x\s*(\d{1,2})\b/)
    ?? matchNumber(lower, /\b\d{1,2}\s*x\s*(\d{1,2})\b/)
    ?? matchNumber(lower, /\bfor\s+(\d{1,2})\b/);
}

function inferSetCount(lower: string): number {
  const count = matchNumber(lower, /\b(\d{1,2})\s*sets?\b/)
    ?? matchNumber(lower, /\b(\d{1,2})\s*x\s*\d{1,2}\b/);
  if (!count) return 1;
  return Math.min(12, Math.max(1, count));
}

function inferFoodItems(text: string) {
  const lower = text.toLowerCase();
  const names = splitFoodNames(cleanupFoodName(text), lower);
  return names.map((name) => ({
    name,
    quantity_text: inferQuantityText(lower),
    calories: 0,
    protein_g: 0,
    carbs_g: 0,
    fat_g: 0,
    confidence: 0.45
  }));
}

function splitFoodNames(text: string, lowerText: string): string[] {
  const knownMatches = knownFoodPhraseMatches(lowerText);
  if (knownMatches.length > 0) return knownMatches;
  const clean = text
    .replace(/\bwith\b/gi, ",")
    .replace(/\bplus\b/gi, ",")
    .replace(/\s+&\s+/g, ",")
    .replace(/\s+and\s+(?=(?:a|an|one|two|three|four|five|six|half|small|medium|large|\d|[a-z]+\\s+(?:starbucks|mcdonald|burger king|wendy|chipotle|cava|sweetgreen|subway)))/gi, ",")
    .split(",")
    .map((item) => titleCase(stripQuantityWords(item).trim()))
    .filter((item) => item.length > 0);
  return clean.length > 0 ? clean : [titleCase(cleanupFoodName(text))];
}

function knownFoodPhraseMatches(lowerText: string): string[] {
  const knownPhrases = [
    "medium starbucks coffee",
    "starbucks coffee",
    "medium mcdonald's fries",
    "mcdonald's fries",
    "mcdonalds fries",
    "sweet and sour sauce",
    "medium fries",
    "jollof rice",
    "pounded yam",
    "egusi soup",
    "efo riro",
    "goat meat",
    "corned beef stew"
  ];
  const matches: Array<{ index: number; phrase: string }> = [];
  const consumedRanges: Array<[number, number]> = [];
  for (const phrase of knownPhrases.sort((left, right) => right.length - left.length)) {
    const match = matchPhrase(lowerText, phrase);
    if (!match) continue;
    const index = match.index + match[1].length;
    const end = index + phrase.length;
    if (consumedRanges.some(([start, stop]) => index < stop && end > start)) continue;
    consumedRanges.push([index, end]);
    matches.push({ index, phrase });
  }
  return matches
    .sort((left, right) => left.index - right.index)
    .map((match) => titleCase(match.phrase));
}

function matchPhrase(text: string, phrase: string): RegExpExecArray | null {
  const escapedPhrase = phrase.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s+");
  return new RegExp(`(^|[^a-z0-9])(${escapedPhrase})(?=$|[^a-z0-9])`, "i").exec(text);
}

async function enrichFoodProposal(proposal: ReturnType<typeof localFallback>, text: string, context: Record<string, unknown>) {
  if (proposal.action_type !== "log_meal" && proposal.action_type !== "estimate_food") {
    return proposal;
  }
  const apiKey = Deno.env.get("SPOONACULAR_API_KEY");
  const aiKey = Deno.env.get("AI_GATEWAY_API_KEY") ?? Deno.env.get("API_KEY");
  const model = Deno.env.get("AI_GATEWAY_MODEL") ?? "moonshotai/kimi-k2.6";

  const sourceItems = proposal.food_items.length > 0
    ? proposal.food_items
    : [{ name: foodNameForLookup(proposal, text), quantity_text: inferQuantityText(text.toLowerCase()), calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0, confidence: 0.45 }];
  let enrichedItems = await Promise.all(sourceItems.map((item) => enrichFoodItem(item, apiKey, aiKey, model, context)));
  const aiReviewedItems = aiKey ? await refineMealItemsWithAi(text, enrichedItems, aiKey, model) : null;
  if (aiReviewedItems?.length) {
    enrichedItems = aiReviewedItems;
  }
  if (enrichedItems.every((item, index) => item === sourceItems[index])) return proposal;
  const nutritionSources = enrichedItems.map((item) => stringValue(item.nutrition_source, ""));
  const hasUnresolvedItems = enrichedItems.some((item) => numberValue(item.calories, 0) <= 0 && numberValue(item.protein_g, 0) <= 0 && numberValue(item.carbs_g, 0) <= 0 && numberValue(item.fat_g, 0) <= 0);
  const totals = enrichedItems.reduce((sum, item) => ({
    calories: sum.calories + Math.round(numberValue(item.calories, 0)),
    protein: sum.protein + numberValue(item.protein_g, 0),
    carbs: sum.carbs + numberValue(item.carbs_g, 0),
    fat: sum.fat + numberValue(item.fat_g, 0)
  }), { calories: 0, protein: 0, carbs: 0, fat: 0 });
  const hasSpecificQuantity = enrichedItems.some((item) => item.quantity_text !== "1 typical serving" && item.quantity_text !== "1 serving");

  return {
    ...proposal,
    confidence: Math.max(proposal.confidence, 0.82),
    summary: hasUnresolvedItems
      ? "I need more info before I can estimate this meal reliably."
      : enrichedItems.length > 1
      ? "Matched these foods to nutrition estimates. Review servings before saving."
      : "Matched this food to a nutrition database estimate. Review the serving before saving.",
    calories: totals.calories,
    protein: Math.round(totals.protein),
    carbs: Math.round(totals.carbs),
    fat: Math.round(totals.fat),
    missing_fields: hasUnresolvedItems ? ["more food detail"] : [],
    assumptions: [
      `Nutrition estimate sources: ${Array.from(new Set(nutritionSources.filter(Boolean))).join(", ") || "unresolved"}.`,
      aiReviewedItems?.length ? "AI reviewed the final food list against the available nutrition evidence." : "",
      hasSpecificQuantity
        ? "Adjusted nutrition for the provided serving detail."
        : "Serving size still affects accuracy; edit quantity if needed.",
      ...proposal.assumptions.filter((item) => {
        const lower = item.toLowerCase();
        return !lower.includes("rough informational") && !lower.includes("fast parser");
      })
    ].filter(Boolean),
    food_items: enrichedItems
  };
}

async function enrichFoodItem(item: Record<string, unknown>, apiKey: string | undefined, aiKey: string | undefined, model: string, context: Record<string, unknown>) {
  const foodName = stringValue(item.name, "Food");
  const quantityText = stringValue(item.quantity_text, "1 typical serving");
  const savedFood = findSavedFoodMatch(foodName, quantityText, context);
  if (savedFood) return savedFood;
  const menuNutrition = apiKey ? await lookupMenuNutrition(foodName, quantityText, apiKey) : null;
  if (menuNutrition) {
    return buildFoodItem(item, foodName, quantityText, menuNutrition, "spoonacular_menu", Math.max(numberValue(item.confidence, 0), 0.86));
  }
  const nutrition = apiKey ? await guessNutrition(foodName, apiKey) : null;
  if (!nutrition && aiKey) {
    const aiNutrition = await reasonNutrition(foodName, quantityText, aiKey, model);
    if (aiNutrition) {
      return buildFoodItem(item, foodName, quantityText, aiNutrition, "ai_reasoned_estimate", Math.max(numberValue(item.confidence, 0), 0.76));
    }
  }
  if (!nutrition) {
    return {
      ...item,
      name: titleCase(foodName),
      quantity_text: quantityText,
      calories: 0,
      protein_g: 0,
      carbs_g: 0,
      fat_g: 0,
      confidence: 0.2,
      nutrition_source: "needs_more_info"
    };
  }
  return buildFoodItem(item, foodName, quantityText, nutrition, "spoonacular", Math.max(numberValue(item.confidence, 0), 0.82));
}

function buildFoodItem(item: Record<string, unknown>, foodName: string, quantityText: string, nutrition: { calories: number; protein: number; carbs: number; fat: number }, source: string, confidence: number) {
  const multiplier = quantityMultiplier(quantityText);
  const adjustedNutrition = scaleNutrition(nutrition, multiplier);
  return {
    ...item,
    name: titleCase(foodName),
    quantity_text: quantityText,
    calories: adjustedNutrition.calories,
    protein_g: adjustedNutrition.protein,
    carbs_g: adjustedNutrition.carbs,
    fat_g: adjustedNutrition.fat,
    confidence,
    nutrition_source: source
  };
}

function foodNameForLookup(proposal: ReturnType<typeof localFallback>, text: string): string {
  const proposedName = proposal.food_items[0]?.name;
  const cleaned = stripQuantityWords(cleanupFoodName(text)
    .replace(/\.\s*more detail:.*$/i, "")
    .replace(/\bmore detail:.*$/i, ""));
  if (cleaned && cleaned.length <= 80 && /[a-z]/i.test(cleaned)) {
    return titleCase(cleaned);
  }
  return proposedName || "Food";
}

function scaleNutrition(nutrition: { calories: number; protein: number; carbs: number; fat: number }, multiplier: number) {
  const safeMultiplier = Number.isFinite(multiplier) && multiplier > 0 ? multiplier : 1;
  return {
    calories: Math.round(nutrition.calories * safeMultiplier),
    protein: roundMacro(nutrition.protein * safeMultiplier),
    carbs: roundMacro(nutrition.carbs * safeMultiplier),
    fat: roundMacro(nutrition.fat * safeMultiplier)
  };
}

function roundMacro(value: number): number {
  return Math.round(value * 10) / 10;
}

async function guessNutrition(title: string, apiKey: string): Promise<{ calories: number; protein: number; carbs: number; fat: number } | null> {
  const url = new URL("https://api.spoonacular.com/recipes/guessNutrition");
  url.searchParams.set("title", title);
  url.searchParams.set("apiKey", apiKey);
  const response = await fetch(url, { headers: { "Accept": "application/json" } }).catch(() => null);
  if (!response?.ok) return null;
  const payload = await response.json().catch(() => null);
  if (!isRecord(payload)) return null;
  const calories = nutrientValue(payload.calories);
  const protein = nutrientValue(payload.protein);
  const carbs = nutrientValue(payload.carbs);
  const fat = nutrientValue(payload.fat);
  if (!calories || !Number.isFinite(protein) || !Number.isFinite(carbs) || !Number.isFinite(fat)) {
    return null;
  }
  return { calories: Math.round(calories), protein, carbs, fat };
}

async function lookupMenuNutrition(title: string, quantityText: string, apiKey: string): Promise<{ calories: number; protein: number; carbs: number; fat: number } | null> {
  const query = menuLookupQuery(title, quantityText);
  const searchUrl = new URL("https://api.spoonacular.com/food/menuItems/search");
  searchUrl.searchParams.set("query", query);
  searchUrl.searchParams.set("number", "8");
  searchUrl.searchParams.set("apiKey", apiKey);
  const searchResponse = await fetch(searchUrl, { headers: { "Accept": "application/json" } }).catch(() => null);
  if (!searchResponse?.ok) return null;
  const searchPayload = await searchResponse.json().catch(() => null);
  if (!isRecord(searchPayload) || !Array.isArray(searchPayload.menuItems)) return null;
  const best = bestMenuItem(searchPayload.menuItems, title, quantityText);
  const id = isRecord(best) ? integerOrNull(best.id) : null;
  if (!id) return null;

  const detailUrl = new URL(`https://api.spoonacular.com/food/menuItems/${id}`);
  detailUrl.searchParams.set("apiKey", apiKey);
  const detailResponse = await fetch(detailUrl, { headers: { "Accept": "application/json" } }).catch(() => null);
  if (!detailResponse?.ok) return null;
  const detailPayload = await detailResponse.json().catch(() => null);
  return nutritionFromMenuItem(detailPayload);
}

function menuLookupQuery(title: string, quantityText: string): string {
  const lower = `${title} ${quantityText}`.toLowerCase();
  if (lower.includes("mcdonald") && /\bfries?|french fries?\b/.test(lower)) {
    return "mcdonalds fries";
  }
  if (lower.includes("starbucks") && lower.includes("coffee") && !/\blatte|frappuccino|macchiato|mocha|chai|milk\b/.test(lower)) {
    return "starbucks brewed coffee";
  }
  if (lower.includes("sweet and sour") && lower.includes("mcdonald")) {
    return "mcdonalds sweet sour sauce";
  }
  return title.replace(/mcdonald's/gi, "mcdonalds");
}

function bestMenuItem(items: unknown[], title: string, quantityText: string): unknown | null {
  let best: { item: unknown; score: number } | null = null;
  for (const item of items) {
    if (!isRecord(item)) continue;
    const haystack = normalizeFoodKey(`${stringValue(item.title, "")} ${stringValue(item.restaurantChain, "")} ${servingUnit(item)}`);
    const score = menuMatchScore(haystack, title, quantityText);
    if (!best || score > best.score) {
      best = { item, score };
    }
  }
  return best && best.score > 0 ? best.item : null;
}

function menuMatchScore(haystack: string, title: string, quantityText: string): number {
  const target = normalizeFoodKey(`${title} ${quantityText}`);
  let score = 0;
  for (const token of target.split(" ").filter((token) => token.length > 2)) {
    if (haystack.includes(token)) score += 1;
  }
  if (target.includes("mcdonald") && haystack.includes("mcdonald")) score += 5;
  if (target.includes("starbucks") && haystack.includes("starbucks")) score += 5;
  if (target.includes("fries") && haystack.includes("fries")) score += 4;
  if (target.includes("coffee") && haystack.includes("coffee")) score += 4;
  if (target.includes("medium") && haystack.includes("medium")) score += 3;
  if (target.includes("small") && haystack.includes("small")) score += 3;
  if (target.includes("large") && haystack.includes("large")) score += 3;
  return score;
}

function servingUnit(item: Record<string, unknown>): string {
  const servings = isRecord(item.servings) ? item.servings : {};
  return stringValue(servings.unit, "");
}

function nutritionFromMenuItem(payload: unknown): { calories: number; protein: number; carbs: number; fat: number } | null {
  if (!isRecord(payload) || !isRecord(payload.nutrition) || !Array.isArray(payload.nutrition.nutrients)) return null;
  const nutrients = payload.nutrition.nutrients.filter(isRecord);
  const nutrient = (name: string) => {
    const match = nutrients.find((item) => stringValue(item.name, "").toLowerCase() === name);
    return match ? numberValue(match.amount, 0) : 0;
  };
  const calories = nutrient("calories");
  if (!calories) return null;
  return {
    calories: Math.round(calories),
    protein: nutrient("protein"),
    carbs: nutrient("carbohydrates"),
    fat: nutrient("fat")
  };
}

async function refineMealItemsWithAi(text: string, items: Array<Record<string, unknown>>, apiKey: string, model: string): Promise<Array<Record<string, unknown>> | null> {
  const reviewModel = Deno.env.get("AI_NUTRITION_MODEL") ?? "openai/gpt-4o-mini";
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 16000);
  try {
    const response = await fetch("https://ai-gateway.vercel.sh/v1/chat/completions", {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: reviewModel || model,
        messages: [
          {
            role: "system",
            content: [
              "You are Fitcountable's nutrition QA pass.",
              "Review the user's original meal text and the evidence-backed food items.",
              "Use saved-food/database numbers as grounding, but correct obvious parsing, portion, or item mistakes.",
              "Preserve distinct foods the user mentioned. Do not merge separate foods into one generic item.",
              "Do not invent restaurant items the user did not say.",
              "Return strict JSON with enough_info and food_items.",
              "Each food item must include name, quantity_text, calories, protein_g, carbs_g, fat_g, confidence.",
              "If the evidence and common nutrition knowledge are enough for a useful consumer estimate, enough_info must be true.",
              "Set enough_info false only if the specific food is too ambiguous to estimate at all."
            ].join(" ")
          },
          {
            role: "user",
            content: JSON.stringify({
              user_text: text,
              evidence_items: items.map((item) => ({
                name: stringValue(item.name, ""),
                quantity_text: stringValue(item.quantity_text, ""),
                calories: numberValue(item.calories, 0),
                protein_g: numberValue(item.protein_g, 0),
                carbs_g: numberValue(item.carbs_g, 0),
                fat_g: numberValue(item.fat_g, 0),
                confidence: numberValue(item.confidence, 0),
                nutrition_source: stringValue(item.nutrition_source, "")
              }))
            })
          }
        ],
        response_format: { type: "json" },
        temperature: 0.1,
        max_tokens: 700
      })
    });
    if (!response.ok) return null;
    const payload = await response.json().catch(() => null);
    const content = payload?.choices?.[0]?.message?.content;
    if (typeof content !== "string") return null;
    const parsed = parseJsonContent(content);
    if (!isRecord(parsed) || parsed.enough_info === false || !Array.isArray(parsed.food_items)) return null;
    const reviewed = parsed.food_items
      .map((raw, index) => mergeReviewedFoodItem(items[index], raw))
      .filter((item): item is Record<string, unknown> => item !== null);
    return reviewed.length > 0 ? reviewed : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

function mergeReviewedFoodItem(original: Record<string, unknown> | undefined, raw: unknown): Record<string, unknown> | null {
  if (!isRecord(raw)) return null;
  const calories = Math.round(numberValue(raw.calories, raw.estimated_calories, 0));
  const protein = numberValue(raw.protein_g, raw.protein, 0);
  const carbs = numberValue(raw.carbs_g, raw.carbs, raw.carbohydrates, 0);
  const fat = numberValue(raw.fat_g, raw.fat, 0);
  if (calories <= 0 && protein <= 0 && carbs <= 0 && fat <= 0) return null;
  const source = stringValue(original?.nutrition_source, raw.nutrition_source, "ai_reviewed");
  return {
    ...(original ?? {}),
    name: titleCase(stringValue(raw.name, original?.name, "Food")),
    quantity_text: stringValue(raw.quantity_text, original?.quantity_text, "1 typical serving"),
    calories,
    protein_g: roundMacro(protein),
    carbs_g: roundMacro(carbs),
    fat_g: roundMacro(fat),
    confidence: clampNumber(raw.confidence, numberValue(original?.confidence, 0.82), 0, 1),
    nutrition_source: source.includes("ai_reviewed") ? source : `${source}+ai_reviewed`
  };
}

async function reasonNutrition(title: string, quantityText: string, apiKey: string, model: string): Promise<{ calories: number; protein: number; carbs: number; fat: number } | null> {
  const models = Array.from(new Set([
    Deno.env.get("AI_NUTRITION_MODEL") ?? "openai/gpt-4o-mini",
    model
  ]));
  for (const candidateModel of models) {
    const nutrition = await reasonNutritionWithModel(title, quantityText, apiKey, candidateModel);
    if (nutrition) return nutrition;
  }
  return null;
}

async function reasonNutritionWithModel(title: string, quantityText: string, apiKey: string, model: string): Promise<{ calories: number; protein: number; carbs: number; fat: number } | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 14000);
  try {
    const response = await fetch("https://ai-gateway.vercel.sh/v1/chat/completions", {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model,
        messages: [
          {
            role: "system",
            content: "Estimate nutrition for the named food only when there is enough information for a reasonable consumer nutrition estimate. Use general nutrition knowledge and cuisine context. Return strict JSON with calories, protein, carbs, fat, and enough_info. If not enough info, set enough_info false and zeros."
          },
          {
            role: "user",
            content: JSON.stringify({ food: title, quantity_text: quantityText })
          }
        ],
        response_format: { type: "json" },
        temperature: 0.1,
        max_tokens: 220
      })
    });
    if (!response.ok) return null;
    const payload = await response.json().catch(() => null);
    const content = payload?.choices?.[0]?.message?.content;
    if (typeof content !== "string") return null;
    const parsed = parseJsonContent(content);
    const nutrition = nutritionFromAiJson(parsed);
    return nutrition.calories > 0 ? nutrition : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

function parseJsonContent(content: string): unknown {
  const trimmed = content.trim();
  try {
    return JSON.parse(trimmed);
  } catch {
    const match = trimmed.match(/\{[\s\S]*\}/);
    return match ? JSON.parse(match[0]) : {};
  }
}

function nutritionFromAiJson(parsed: unknown): { calories: number; protein: number; carbs: number; fat: number } {
  if (!isRecord(parsed) || parsed.enough_info === false) {
    return { calories: 0, protein: 0, carbs: 0, fat: 0 };
  }
  const nutrition = isRecord(parsed.nutrition) ? parsed.nutrition : parsed;
  return {
    calories: Math.round(numberValue(nutrition.calories, nutrition.kcal, 0)),
    protein: numberValue(nutrition.protein, nutrition.protein_g, 0),
    carbs: numberValue(nutrition.carbs, nutrition.carbohydrates, nutrition.carbs_g, 0),
    fat: numberValue(nutrition.fat, nutrition.fat_g, 0)
  };
}

function findSavedFoodMatch(foodName: string, quantityText: string, context: Record<string, unknown>) {
  const savedFoods = Array.isArray(context.saved_foods)
    ? context.saved_foods
    : Array.isArray(context.savedFoods)
      ? context.savedFoods
      : [];
  const normalizedFoodName = normalizeFoodKey(foodName);
  for (const raw of savedFoods) {
    if (!isRecord(raw)) continue;
    const savedName = stringValue(raw.name, "");
    if (!savedName) continue;
    if (normalizeFoodKey(savedName) !== normalizedFoodName) continue;
    return buildFoodItem(raw, savedName, quantityText || stringValue(raw.quantity_text, raw.quantityText, "1 typical serving"), {
      calories: numberValue(raw.calories, 0),
      protein: numberValue(raw.protein_g, raw.protein, 0),
      carbs: numberValue(raw.carbs_g, raw.carbs, 0),
      fat: numberValue(raw.fat_g, raw.fat, 0)
    }, "saved_foods", 0.92);
  }
  return null;
}

function normalizeFoodKey(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function nutrientValue(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (isRecord(value)) {
    return numberValue(value.value, value.amount);
  }
  return 0;
}

function inferQuantityText(lower: string): string {
  const patterns = [
    /\b\d+(\.\d+)?\s*(cup|cups|oz|ounce|ounces|g|grams|lb|lbs|pound|pounds|slice|slices|piece|pieces|bowl|plate|serving|servings)\b/,
    /\b(one|two|three|four|five|six|half)\s+(cup|cups|bowl|plate|serving|servings|slice|slices|piece|pieces)\b/,
    /\b(small|medium|large)\s+(bowl|plate|serving|portion|order|burrito|sandwich|salad)\b/
  ];
  for (const pattern of patterns) {
    const match = lower.match(pattern);
    if (match?.[0]) return match[0];
  }
  return "1 typical serving";
}

function quantityMultiplier(quantityText: string): number {
  const lower = quantityText.toLowerCase();
  const numeric = lower.match(/\b(\d+(?:\.\d+)?)\b/);
  if (numeric?.[1]) return Number(numeric[1]);
  const wordValues: Record<string, number> = {
    half: 0.5,
    one: 1,
    two: 2,
    three: 3,
    four: 4,
    five: 5,
    six: 6
  };
  for (const [word, value] of Object.entries(wordValues)) {
    if (new RegExp(`\\b${word}\\b`).test(lower)) return value;
  }
  if (/\bsmall\b/.test(lower)) return 0.75;
  if (/\bmedium|regular\b/.test(lower)) return 1;
  if (/\blarge\b/.test(lower)) return 1.3;
  return 1;
}

function stripQuantityWords(text: string): string {
  return text
    .replace(/\b\d+(\.\d+)?\s*(cup|cups|oz|ounce|ounces|g|grams|lb|lbs|pound|pounds|slice|slices|piece|pieces|bowl|plate|serving|servings)\b/gi, "")
    .replace(/\b(one|two|three|four|five|six|half)\s+(cup|cups|bowl|plate|serving|servings|slice|slices|piece|pieces)\b/gi, "")
    .replace(/\b(small|medium|large)\s+(bowl|plate|serving|portion|order)\b/gi, "")
    .replace(/\b(a|an)\b/gi, "")
    .replace(/\s+/g, " ")
    .trim();
}

function cleanupFoodName(text: string): string {
  return text
    .replace(/^(log|estimate|add|track)\s+/i, "")
    .replace(/^(calories and macros for|calories for|macros for)\s+/i, "")
    .replace(/\bmore detail:\s*/i, "")
    .replace(/\b(a|an)\b\s+/i, "")
    .replace(/\s+/g, " ")
    .trim() || "Food";
}

function titleCase(value: string): string {
  return value
    .replace(/[.,;:]+$/g, "")
    .split(" ")
    .map((word) => word ? word[0].toUpperCase() + word.slice(1) : word)
    .join(" ");
}

function matchNumber(text: string, pattern: RegExp): number | null {
  const match = text.match(pattern);
  return match?.[1] ? Number(match[1]) : null;
}

function isGoalUpdate(text: string): boolean {
  const hasGoalVerb = /\b(update|set|change|make|goal|target)\b/.test(text);
  const hasGoalMetric = /\b(cal|cals|calories|protein|carbs?|fat|workouts?|gym sessions?|lifts?)\b/.test(text);
  return hasGoalVerb && hasGoalMetric;
}

function integerOrNull(...values: unknown[]): number | null {
  for (const value of values) {
    if (typeof value === "number" && Number.isFinite(value)) {
      return Math.round(value);
    }
  }
  return null;
}

function normalizeMealType(value: string): string | null {
  const lower = value.toLowerCase().trim();
  if (["breakfast", "lunch", "dinner", "snack"].includes(lower)) {
    return lower;
  }
  return null;
}

function mealTypeFromContext(context: Record<string, unknown>): string | null {
  const raw = stringValue(
    context.current_meal_type,
    context.currentMealType,
    context.meal_type,
    context.mealType,
    ""
  );
  return normalizeMealType(raw);
}

function shouldUseContextMealType(text: string, contextMealType: string | null): boolean {
  if (!contextMealType) return false;
  const lower = text.toLowerCase();
  const explicitMealType = normalizeMealType(
    ["breakfast", "lunch", "dinner", "snack"].find((type) => lower.includes(type)) ?? ""
  );
  return !explicitMealType || explicitMealType === contextMealType;
}

function inferMealType(text: string): string {
  const lower = text.toLowerCase();
  if (lower.includes("breakfast")) return "breakfast";
  if (lower.includes("dinner")) return "dinner";
  if (lower.includes("snack")) return "snack";
  return "lunch";
}

function inferDuration(text: string): number | null {
  const lower = text.toLowerCase();
  return matchNumber(lower, /\b(\d{1,3})\s*(?:min|mins|minutes)\b/);
}

function inferWorkoutTitle(text: string): string {
  const lower = text.toLowerCase();
  if (lower.includes("push")) return "Push Day";
  if (lower.includes("pull")) return "Pull Day";
  if (lower.includes("leg")) return "Leg Day";
  if (lower.includes("cardio") || lower.includes("run")) return "Cardio";
  return "Workout";
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(sanitizePayload(payload)), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}

function sanitizePayload(payload: unknown): unknown {
  if (!isRecord(payload) || !Array.isArray(payload.assumptions)) return payload;
  return {
    ...payload,
    assumptions: payload.assumptions.filter((item) => {
      if (typeof item !== "string") return false;
      const lower = item.toLowerCase();
      return !lower.includes("fast parser") && !lower.includes("gateway request failed") && !lower.includes("fallback parser");
    })
  };
}
