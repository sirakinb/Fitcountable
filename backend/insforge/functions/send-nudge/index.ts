const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};

type NudgeBody = {
  target_user_id?: string;
  recipient_id?: string;
  type?: string;
  message?: string;
  reason?: string;
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

  const senderId = decodeJwtSubject(token);
  if (!senderId) {
    return json({ error: "Invalid auth token" }, 401);
  }

  const body = await req.json().catch(() => ({})) as NudgeBody;
  const recipientId = body.target_user_id ?? body.recipient_id;
  if (!recipientId) {
    return json({ error: "target_user_id or recipient_id is required" }, 400);
  }

  const message = (body.message ?? body.reason ?? "Accountability check-in from Fitcountable.").trim();
  const friendship = await fetch(`${baseUrl}/api/database/rpc/fc_are_friends`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ a: senderId, b: recipientId })
  }).catch(() => null);
  const areFriends = friendship?.ok ? await friendship.json().catch(() => false) : false;
  if (areFriends !== true) {
    return json({ error: "Nudges can only be sent to approved friends." }, 403);
  }

  const record = {
    sender_id: senderId,
    recipient_id: recipientId,
    type: body.type ?? "accountability",
    message,
    status: "queued"
  };

  const response = await fetch(`${baseUrl}/api/database/records/nudges`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    },
    body: JSON.stringify([record])
  });

  if (!response.ok) {
    return json({ error: `Nudge save failed: ${response.status} ${await response.text()}` }, 500);
  }

  const rows = await response.json();
  return json({ ok: true, status: "queued", nudge: Array.isArray(rows) ? rows[0] : rows });
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

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}
