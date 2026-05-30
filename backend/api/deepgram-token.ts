import type { HttpRequest, JsonResponse } from "./_types";
import { createDeepgramToken } from "../src/deepgram";

export default async function handler(request: HttpRequest, response: JsonResponse) {
  if (request.method !== "POST") {
    response.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const token = await createDeepgramToken();
    response.status(200).json(token);
  } catch (error) {
    response.status(500).json({
      error: error instanceof Error ? error.message : "Unable to create voice session"
    });
  }
}
