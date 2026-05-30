const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};

type PlanBody = {
  goal_type?: string;
  weight?: number;
  activity_level?: string;
  weekly_workouts?: number;
  training_experience?: string;
  answers?: Record<string, unknown>;
};

export default async function(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const body = await req.json().catch(() => ({})) as PlanBody;
  const answers = isRecord(body.answers) ? body.answers : {};
  const goalType = stringValue(body.goal_type, answers.goal_type, answers.goal) ?? "recomp";
  const weight = numberValue(body.weight, answers.weight, 180);
  const weeklyWorkouts = Math.max(2, Math.min(6, Math.round(numberValue(body.weekly_workouts, answers.weekly_workouts, 4))));
  const activityMultiplier = activityOffset(stringValue(body.activity_level, answers.activity_level));
  const maintenance = Math.round((weight * 14.5 + activityMultiplier) / 25) * 25;
  const calories = goalType.includes("lose") || goalType.includes("fat")
    ? maintenance - 350
    : goalType.includes("build") || goalType.includes("muscle")
      ? maintenance + 200
      : maintenance;
  const protein = Math.round(weight);
  const fat = Math.round(calories * 0.27 / 9);
  const carbs = Math.max(120, Math.round((calories - protein * 4 - fat * 9) / 4));

  return json({
    calories,
    protein_g: protein,
    carbs_g: carbs,
    fat_g: fat,
    weekly_workouts: weeklyWorkouts,
    training_focus: goalType.includes("consistency") ? "consistency" : "progressive overload",
    reminders: ["Workout reminder", "Meal logging reminder"],
    assumptions: [
      "Plan is an informational starting point and should be edited by the user.",
      "HealthKit is deferred for this MVP, so activity is based on onboarding answers."
    ]
  });
}

function activityOffset(value: string | null) {
  switch (value?.toLowerCase()) {
    case "high":
    case "very active":
      return 350;
    case "moderate":
    case "active":
      return 175;
    case "low":
    case "sedentary":
      return -100;
    default:
      return 0;
  }
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
    if (typeof value === "string" && Number.isFinite(Number(value))) {
      return Number(value);
    }
  }
  return 0;
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}
