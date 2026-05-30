import type { HttpRequest, JsonResponse } from "./_types";
import { syncRevenueCatWebhook } from "../src/handlers";

export default async function handler(request: HttpRequest, response: JsonResponse) {
  if (request.method !== "POST") {
    response.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const result = await syncRevenueCatWebhook(request.body);
    response.status(200).json(result);
  } catch (error) {
    response.status(400).json({ error: error instanceof Error ? error.message : "Webhook processing failed" });
  }
}
