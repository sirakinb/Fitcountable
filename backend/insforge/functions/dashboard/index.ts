const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};

export default async function(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const url = new URL(req.url);
  const body = req.method === "POST" ? await req.json().catch(() => ({})) as Record<string, unknown> : {};
  const userId = url.searchParams.get("user_id") ?? stringValue(body.user_id);
  const date = url.searchParams.get("date") ?? stringValue(body.date) ?? new Date().toISOString().slice(0, 10);

  if (!userId) {
    return json({ error: "user_id is required" }, 400);
  }

  return json({
    user_id: userId,
    date,
    calories_goal: 2450,
    calories_consumed: 0,
    workouts_logged: 0,
    accountability_enabled: false
  });
}

function stringValue(value: unknown) {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}
