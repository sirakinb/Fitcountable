const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};

type EstimateBody = {
  text?: string;
  input?: string;
  context?: Record<string, unknown>;
};

const baseUrl = Deno.env.get("INSFORGE_BASE_URL") ?? "https://hxvc7grj.us-east.insforge.app";

export default async function(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const body = await req.json().catch(() => ({})) as EstimateBody;
  const text = (body.text ?? body.input ?? "").trim();
  if (!text) {
    return json({ error: "text or input is required" }, 400);
  }

  const response = await fetch(`${baseUrl}/functions/parse-command`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": req.headers.get("Authorization") ?? ""
    },
    body: JSON.stringify({
      text: `Estimate calories and macros for this meal: ${text}`,
      context: body.context ?? {}
    })
  }).catch(() => null);

  if (!response?.ok) {
    return json(localEstimate(text));
  }

  const proposal = await response.json();
  return json({
    ...proposal,
    action_type: "estimate_food",
    requires_confirmation: true,
    user_editable_fields: Array.from(new Set([
      ...(Array.isArray(proposal.user_editable_fields) ? proposal.user_editable_fields : []),
      "food_items",
      "calories",
      "protein",
      "carbs",
      "fat"
    ]))
  });
}

function localEstimate(text: string) {
  const isHighProtein = /chicken|steak|beef|turkey|fish|salmon|eggs|protein/i.test(text);
  const calories = /bowl|burger|burrito|pasta|pizza/i.test(text) ? 780 : 520;
  const protein = isHighProtein ? 42 : 24;
  return {
    action_type: "estimate_food",
    confidence: 0.68,
    requires_confirmation: true,
    summary: "Estimated this meal from text. Review calories and macros before saving.",
    title: "Meal estimate",
    meal_type: "snack",
    calories,
    protein,
    carbs: Math.round(calories * 0.45 / 4),
    fat: Math.round(calories * 0.28 / 9),
    weekly_workouts: null,
    duration_minutes: null,
    target_friend_id: null,
    entities: { input: text },
    proposed_records: {},
    user_editable_fields: ["meal_type", "food_items", "calories", "protein", "carbs", "fat"],
    missing_fields: [],
    assumptions: ["Fallback estimator used; values are informational estimates."],
    workout_sets: [],
    food_items: [{
      name: text,
      quantity_text: "1 described meal",
      calories,
      protein_g: protein,
      carbs_g: Math.round(calories * 0.45 / 4),
      fat_g: Math.round(calories * 0.28 / 9),
      confidence: 0.68
    }]
  };
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}
