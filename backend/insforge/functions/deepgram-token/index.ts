export default async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405 });
  }

  const apiKey = Deno.env.get("DEEPGRAM_API_KEY");
  if (!apiKey) {
    return Response.json({ error: "DEEPGRAM_API_KEY is not configured" }, { status: 500 });
  }

  const deepgramResponse = await fetch("https://api.deepgram.com/v1/auth/grant", {
    method: "POST",
    headers: {
      Authorization: `Token ${apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ ttl_seconds: 300 })
  });

  if (!deepgramResponse.ok) {
    return Response.json(
      { error: `Deepgram token request failed with status ${deepgramResponse.status}` },
      { status: 502 }
    );
  }

  const payload = await deepgramResponse.json();
  return Response.json({
    accessToken: payload.access_token,
    expiresIn: payload.expires_in
  });
}
