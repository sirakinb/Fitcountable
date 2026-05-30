const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};

type ConfirmBody = {
  raw_text?: string;
  proposal?: Record<string, unknown>;
};

const baseUrl = Deno.env.get("INSFORGE_BASE_URL") ?? "https://hxvc7grj.us-east.insforge.app";

export default async function(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) {
    return json({ error: "Authorization bearer token is required" }, 401);
  }

  const userId = decodeJwtSubject(token);
  if (!userId) {
    return json({ error: "Invalid auth token" }, 401);
  }

  const body = await req.json().catch(() => ({})) as ConfirmBody;
  const proposal = body.proposal;
  if (!proposal || typeof proposal !== "object") {
    return json({ error: "proposal is required" }, 400);
  }

  const actionType = stringValue(proposal.action_type, proposal.actionType) ?? "unknown";
  const rawText = body.raw_text ?? stringValue(proposal.summary) ?? "";

  try {
    const command = await insertRecord(token, "ai_commands", {
      user_id: userId,
      raw_text: rawText,
      action_type: actionType,
      model: "moonshotai/kimi-k2.6",
      parsed_json: proposal,
      status: "confirmed"
    });

    if (actionType === "log_workout") {
      const workout = await insertRecord(token, "workouts", {
        user_id: userId,
        title: stringValue(proposal.title) ?? inferWorkoutTitle(rawText),
        duration_minutes: numberValue(proposal.duration_minutes, proposal.durationMinutes, 45),
        source: "ai",
        notes: stringValue(proposal.summary),
        visibility: "friends"
      });
      const workoutId = stringValue(workout?.id);
      const sets = Array.isArray(proposal.workout_sets) ? proposal.workout_sets : [];
      if (workoutId && sets.length > 0) {
        await insertRecords(token, "workout_sets", sets.map((raw, index) => normalizeWorkoutSet(raw, workoutId, index + 1)));
      }
      return json({ persisted: true, record_type: "workout", record_id: workoutId, command_id: command?.id ?? null });
    }

    if (actionType === "log_meal" || actionType === "estimate_food") {
      const meal = await insertRecord(token, "meals", {
        user_id: userId,
        meal_type: normalizeMealType(stringValue(proposal.meal_type, proposal.mealType)) ?? "snack",
        source: "ai",
        notes: stringValue(proposal.summary)
      });
      const mealId = stringValue(meal?.id);
      const items = Array.isArray(proposal.food_items) ? proposal.food_items : [];
      if (mealId && items.length > 0) {
        await insertRecords(token, "food_items", items.map((raw) => normalizeFoodItem(raw, mealId)));
        await insertRecords(token, "saved_foods", items.map((raw) => normalizeSavedFood(raw, userId))).catch(() => null);
      }
      return json({ persisted: true, record_type: "meal", record_id: mealId, command_id: command?.id ?? null });
    }

    if (actionType === "update_goal") {
      const goal = await insertRecord(token, "goals", {
        user_id: userId,
        calories: numberOrNull(proposal.calories),
        protein_g: numberOrNull(proposal.protein, proposal.protein_g),
        carbs_g: numberOrNull(proposal.carbs, proposal.carbs_g),
        fat_g: numberOrNull(proposal.fat, proposal.fat_g),
        weekly_workouts: numberOrNull(proposal.weekly_workouts, proposal.weeklyWorkouts),
        target_pace: stringValue(proposal.summary),
        active: true
      });
      return json({ persisted: true, record_type: "goal", record_id: goal?.id ?? null, command_id: command?.id ?? null });
    }

    return json({ persisted: true, record_type: "command", record_id: null, command_id: command?.id ?? null });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Persistence failed" }, 500);
  }
}

async function insertRecord(token: string, table: string, record: Record<string, unknown>) {
  const records = await insertRecords(token, table, [record]);
  return Array.isArray(records) ? records[0] : null;
}

async function insertRecords(token: string, table: string, records: Array<Record<string, unknown>>) {
  const response = await fetch(`${baseUrl}/api/database/records/${table}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    },
    body: JSON.stringify(records)
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Insert failed for ${table}: ${response.status} ${text}`);
  }

  return response.json();
}

function normalizeWorkoutSet(raw: unknown, workoutId: string, fallbackIndex: number) {
  const item = isRecord(raw) ? raw : {};
  return {
    workout_id: workoutId,
    exercise_name: stringValue(item.exercise_name, item.exerciseName) ?? "Exercise",
    set_index: Math.round(numberValue(item.set_index, item.setIndex, fallbackIndex)),
    reps: Math.round(numberValue(item.reps, 0)),
    weight: numberValue(item.weight, 0),
    unit: stringValue(item.unit) ?? "lb",
    rpe: numberOrNull(item.rpe),
    notes: stringValue(item.notes)
  };
}

function normalizeFoodItem(raw: unknown, mealId: string) {
  const item = isRecord(raw) ? raw : {};
  return {
    meal_id: mealId,
    name: stringValue(item.name) ?? "Food",
    quantity_text: stringValue(item.quantity_text, item.quantityText) ?? "1 serving",
    calories: Math.round(numberValue(item.calories, 0)),
    protein_g: numberValue(item.protein_g, item.protein, 0),
    carbs_g: numberValue(item.carbs_g, item.carbs, 0),
    fat_g: numberValue(item.fat_g, item.fat, 0),
    confidence: numberValue(item.confidence, 0.6)
  };
}

function normalizeSavedFood(raw: unknown, userId: string) {
  const item = isRecord(raw) ? raw : {};
  const name = stringValue(item.name) ?? "Food";
  return {
    user_id: userId,
    name,
    normalized_name: normalizeFoodName(name),
    quantity_text: stringValue(item.quantity_text, item.quantityText) ?? "1 serving",
    calories: Math.round(numberValue(item.calories, 0)),
    protein_g: numberValue(item.protein_g, item.protein, 0),
    carbs_g: numberValue(item.carbs_g, item.carbs, 0),
    fat_g: numberValue(item.fat_g, item.fat, 0),
    confidence: numberValue(item.confidence, 0.6),
    source: stringValue(item.nutrition_source, item.nutritionSource) ?? "ai"
  };
}

function normalizeFoodName(value: string) {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

function decodeJwtSubject(token: string) {
  try {
    const payload = token.split(".")[1];
    const padded = payload + "=".repeat((4 - payload.length % 4) % 4);
    const decoded = atob(padded.replace(/-/g, "+").replace(/_/g, "/"));
    const jsonPayload = JSON.parse(decoded);
    return typeof jsonPayload.sub === "string" ? jsonPayload.sub : null;
  } catch {
    return null;
  }
}

function inferWorkoutTitle(text: string) {
  return text.toLowerCase().includes("push") ? "Push Day" : "Workout";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }
  return null;
}

function numberValue(...values: unknown[]): number {
  for (const value of values) {
    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }
  }
  return 0;
}

function numberOrNull(...values: unknown[]): number | null {
  for (const value of values) {
    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }
  }
  return null;
}

function normalizeMealType(value: string | null): string | null {
  const lower = value?.toLowerCase();
  if (lower === "breakfast" || lower === "lunch" || lower === "dinner" || lower === "snack") {
    return lower;
  }
  return null;
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}
