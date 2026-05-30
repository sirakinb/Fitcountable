const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};

type SupportBody = {
  message?: string;
  email?: string;
  category?: string;
};

const baseUrl = Deno.env.get("INSFORGE_BASE_URL") ?? "https://hxvc7grj.us-east.insforge.app";
const supportEmail = Deno.env.get("SUPPORT_EMAIL") ?? "aki.b@pentridgemedia.com";

export default async function(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const body = await req.json().catch(() => ({})) as SupportBody;
  const message = body.message?.trim();
  if (!message) {
    return json({ error: "message is required" }, 400);
  }

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  const userId = token ? decodeJwtSubject(token) : null;
  if (token) {
    await fetch(`${baseUrl}/api/database/records/events`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify([{
        user_id: userId,
        name: "support_ticket_created",
        properties_json: {
          category: body.category ?? "support",
          email: body.email ?? null,
          message
        }
      }])
    }).catch(() => null);
  }

  return json({
    ok: true,
    routed_to: supportEmail,
    status: "received",
    message: "Support request received. Email support if you need a direct reply."
  });
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
