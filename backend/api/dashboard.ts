import type { HttpRequest, JsonResponse } from "./_types";
import { getDashboard } from "../src/handlers";

export default async function handler(request: HttpRequest, response: JsonResponse) {
  const userId = String(request.query.user_id ?? "");
  const date = String(request.query.date ?? new Date().toISOString().slice(0, 10));

  if (!userId) {
    response.status(400).json({ error: "user_id is required" });
    return;
  }

  const dashboard = await getDashboard(userId, date);
  response.status(200).json(dashboard);
}
