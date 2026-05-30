import { z } from "zod";

const deepgramGrantResponseSchema = z.object({
  access_token: z.string().min(1),
  expires_in: z.number().int().positive()
});

export type DeepgramTokenResponse = {
  accessToken: string;
  expiresIn: number;
};

export async function createDeepgramToken(ttlSeconds = 300): Promise<DeepgramTokenResponse> {
  const apiKey = process.env.DEEPGRAM_API_KEY;
  if (!apiKey) {
    throw new Error("DEEPGRAM_API_KEY is not configured");
  }

  const response = await fetch("https://api.deepgram.com/v1/auth/grant", {
    method: "POST",
    headers: {
      Authorization: `Token ${apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ ttl_seconds: ttlSeconds })
  });

  if (!response.ok) {
    throw new Error(`Deepgram token request failed with status ${response.status}`);
  }

  const payload = deepgramGrantResponseSchema.parse(await response.json());
  return {
    accessToken: payload.access_token,
    expiresIn: payload.expires_in
  };
}
