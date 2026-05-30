const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};

const baseUrl = Deno.env.get("INSFORGE_BASE_URL") ?? "https://hxvc7grj.us-east.insforge.app";
const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");

export default async function(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  if (webhookSecret) {
    const provided = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "")
      ?? req.headers.get("X-RevenueCat-Signature");
    if (provided !== webhookSecret) {
      return json({ error: "Unauthorized webhook" }, 401);
    }
  }

  const body = await req.json().catch(() => ({}));
  const event = isRecord(body.event) ? body.event : isRecord(body) ? body : {};
  const appUserId = stringValue(event.app_user_id, event.original_app_user_id, event.subscriber_attributes?.app_user_id);
  const productId = stringValue(event.product_id);
  const entitlement = stringValue(event.entitlement_id) ?? "premium";
  const expiresAt = stringValue(event.expiration_at_ms)
    ? new Date(Number(event.expiration_at_ms)).toISOString()
    : stringValue(event.expiration_at);
  const active = !["EXPIRATION", "CANCELLATION", "BILLING_ISSUE"].includes(stringValue(event.type)?.toUpperCase() ?? "");

  if (!appUserId) {
    return json({ ok: true, processed: false, reason: "No RevenueCat app user ID supplied." });
  }

  const serviceToken = Deno.env.get("INSFORGE_SERVICE_ROLE_KEY") ?? Deno.env.get("INSFORGE_SERVICE_KEY");
  if (!serviceToken) {
    return json({
      ok: true,
      processed: false,
      reason: "RevenueCat event accepted, but service key is not configured for subscription persistence."
    });
  }

  const response = await fetch(`${baseUrl}/api/database/records/subscriptions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${serviceToken}`,
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    },
    body: JSON.stringify([{
      user_id: appUserId,
      revenuecat_app_user_id: appUserId,
      entitlement,
      active,
      product_id: productId,
      expires_at: expiresAt
    }])
  });

  if (!response.ok) {
    return json({ error: `Subscription sync failed: ${response.status} ${await response.text()}` }, 500);
  }

  return json({ ok: true, processed: true });
}

function isRecord(value: unknown): value is Record<string, any> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
    if (typeof value === "number" && Number.isFinite(value)) {
      return String(value);
    }
  }
  return null;
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}
