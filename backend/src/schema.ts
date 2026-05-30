import { z } from "zod";

export const actionTypeSchema = z.enum([
  "log_workout",
  "log_meal",
  "estimate_food",
  "update_goal",
  "create_workout_plan",
  "create_nutrition_plan",
  "create_accountability_nudge",
  "summarize_progress",
  "correct_last_log"
]);

export const workoutSetSchema = z.object({
  exercise_name: z.string(),
  set_index: z.number().int().min(1),
  reps: z.number().int().min(0),
  weight: z.number().min(0),
  unit: z.enum(["lb", "kg"]).default("lb"),
  rpe: z.number().min(0).max(10).nullable().default(null),
  notes: z.string().optional()
});

export const foodItemSchema = z.object({
  name: z.string(),
  quantity_text: z.string(),
  calories: z.number().int().min(0),
  protein_g: z.number().min(0),
  carbs_g: z.number().min(0),
  fat_g: z.number().min(0),
  confidence: z.number().min(0).max(1)
});

export const actionProposalSchema = z.object({
  action_type: actionTypeSchema,
  confidence: z.number().min(0).max(1),
  requires_confirmation: z.boolean(),
  summary: z.string(),
  entities: z.record(z.unknown()).default({}),
  proposed_records: z.record(z.unknown()).default({}),
  user_editable_fields: z.array(z.string()).default([]),
  missing_fields: z.array(z.string()).default([]),
  assumptions: z.array(z.string()).default([]),
  workout_sets: z.array(workoutSetSchema).default([]),
  food_items: z.array(foodItemSchema).default([])
});

export type ActionProposal = z.infer<typeof actionProposalSchema>;

export const parseCommandRequestSchema = z.object({
  user_id: z.string(),
  text: z.string().min(1),
  context: z.record(z.unknown()).default({})
});

export type ParseCommandRequest = z.infer<typeof parseCommandRequestSchema>;

