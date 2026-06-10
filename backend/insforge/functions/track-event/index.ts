const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type TrackRequest = {
  event?: string;
  distinct_id?: string;
  distinctId?: string;
  properties?: Record<string, unknown>;
  timestamp?: string;
};

const blockedPropertyNames = new Set([
  "authorization",
  "access_token",
  "accessToken",
  "refresh_token",
  "refreshToken",
  "password",
  "api_key",
  "apiKey",
  "audio_base64",
  "audioBase64",
  "media_base64",
  "mediaBase64",
  "photo_data",
  "photoData",
]);

export default async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
  }

  const posthogKey = Deno.env.get("POSTHOG_API_KEY");
  if (!posthogKey) {
    return json({ ok: false, error: "POSTHOG_NOT_CONFIGURED" }, 500);
  }

  let body: TrackRequest;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: "INVALID_JSON" }, 400);
  }

  const event = String(body.event ?? "").trim();
  if (event.length < 2 || event.length > 120) {
    return json({ ok: false, error: "INVALID_EVENT" }, 400);
  }

  const tokenUserId = userIdFromAuthHeader(req.headers.get("authorization"));
  const distinctId = tokenUserId ?? String(body.distinct_id ?? body.distinctId ?? "").trim();
  if (!distinctId) {
    return json({ ok: false, error: "DISTINCT_ID_REQUIRED" }, 400);
  }

  const timestamp = validTimestamp(body.timestamp) ?? new Date().toISOString();
  const posthogHost = (Deno.env.get("POSTHOG_HOST") ?? "https://us.i.posthog.com").replace(/\/$/, "");
  const properties = sanitizeProperties(body.properties ?? {});

  try {
    const response = await fetch(`${posthogHost}/capture/`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        api_key: posthogKey,
        event,
        distinct_id: distinctId,
        timestamp,
        properties: {
          ...properties,
          app: "fitcountable",
          platform: "ios",
          backend: "insforge",
          authenticated: Boolean(tokenUserId),
          user_id: tokenUserId,
        },
      }),
    });

    if (!response.ok) {
      return json({ ok: false, error: "POSTHOG_CAPTURE_FAILED" }, 502);
    }

    return json({ ok: true });
  } catch {
    return json({ ok: false, error: "POSTHOG_UNREACHABLE" }, 502);
  }
}

function json(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function userIdFromAuthHeader(header: string | null): string | undefined {
  if (!header?.toLowerCase().startsWith("bearer ")) {
    return undefined;
  }

  const token = header.slice("bearer ".length).trim();
  const parts = token.split(".");
  if (parts.length < 2) {
    return undefined;
  }

  try {
    const payload = JSON.parse(base64UrlDecode(parts[1])) as Record<string, unknown>;
    const subject = payload.sub;
    return typeof subject === "string" && subject.length > 0 ? subject : undefined;
  } catch {
    return undefined;
  }
}

function base64UrlDecode(input: string): string {
  const base64 = input.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(input.length / 4) * 4, "=");
  return atob(base64);
}

function validTimestamp(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }

  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

function sanitizeProperties(input: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  let count = 0;

  for (const [key, value] of Object.entries(input)) {
    if (count >= 40 || blockedPropertyNames.has(key)) {
      continue;
    }

    const clean = sanitizeValue(value, 0);
    if (clean !== undefined) {
      result[key] = clean;
      count += 1;
    }
  }

  return result;
}

function sanitizeValue(value: unknown, depth: number): unknown {
  if (value === null || value === undefined) {
    return value;
  }
  if (typeof value === "string") {
    return value.slice(0, 500);
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return value;
  }
  if (Array.isArray(value)) {
    return value.slice(0, 20).map((item) => sanitizeValue(item, depth + 1)).filter((item) => item !== undefined);
  }
  if (typeof value === "object" && depth < 2) {
    return sanitizeProperties(value as Record<string, unknown>);
  }
  return undefined;
}
