import { parseWithGateway } from "./aiGateway";
import { parseCommandRequestSchema, type ActionProposal } from "./schema";

export async function parseCommand(body: unknown): Promise<ActionProposal> {
  const request = parseCommandRequestSchema.parse(body);
  return parseWithGateway({ text: request.text, context: request.context });
}

export async function confirmCommand(body: unknown): Promise<{ ok: true; saved: unknown }> {
  return { ok: true, saved: body };
}

export async function estimateNutrition(body: unknown): Promise<ActionProposal> {
  const request = parseCommandRequestSchema.parse(body);
  return parseWithGateway({
    text: `Estimate calories and macros for: ${request.text}`,
    context: request.context
  });
}

export async function generatePlan(body: unknown): Promise<{
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  weekly_workouts: number;
}> {
  void body;
  return {
    calories: 2450,
    protein_g: 185,
    carbs_g: 260,
    fat_g: 75,
    weekly_workouts: 4
  };
}

export async function sendNudge(body: unknown): Promise<{ ok: true; status: "queued"; body: unknown }> {
  return { ok: true, status: "queued", body };
}

export async function syncRevenueCatWebhook(body: unknown): Promise<{ ok: true; processed: true }> {
  void body;
  return { ok: true, processed: true };
}

export async function searchUsers(query: string): Promise<Array<{ id: string; display_name: string }>> {
  return [{ id: "demo-friend", display_name: query || "Jordan" }];
}

export async function getDashboard(userId: string, date: string): Promise<Record<string, unknown>> {
  return {
    user_id: userId,
    date,
    calories_goal: 2450,
    calories_consumed: 0,
    workouts_logged: 0,
    accountability_enabled: false
  };
}

export async function createSupportTicket(body: unknown): Promise<{ ok: true; routed_to: string }> {
  void body;
  return { ok: true, routed_to: process.env.SUPPORT_EMAIL ?? "aki.b@pentridgemedia.com" };
}

