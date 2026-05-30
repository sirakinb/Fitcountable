import { actionProposalSchema, type ActionProposal } from "./schema";

const gatewayURL = "https://ai-gateway.vercel.sh/v1/chat/completions";

export async function parseWithGateway(input: {
  text: string;
  context: Record<string, unknown>;
}): Promise<ActionProposal> {
  const apiKey = process.env.AI_GATEWAY_API_KEY;
  const model = process.env.AI_GATEWAY_MODEL ?? "moonshotai/kimi-k2.6";

  if (!apiKey) {
    return localFallback(input.text);
  }

  const response = await fetch(gatewayURL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "system",
          content:
            "You parse fitness app commands into strict JSON. Return only JSON matching the Fitcountable action proposal contract. Nutrition values are informational estimates and must be editable."
        },
        {
          role: "user",
          content: JSON.stringify(input)
        }
      ],
      response_format: { type: "json" },
      temperature: 0.1,
      max_tokens: 900
    })
  });

  if (!response.ok) {
    throw new Error(`AI Gateway request failed: ${response.status}`);
  }

  const payload = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const content = payload.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error("AI Gateway returned an empty response.");
  }

  return actionProposalSchema.parse(JSON.parse(content));
}

function localFallback(text: string): ActionProposal {
  const lower = text.toLowerCase();
  if (lower.includes("bench") || lower.includes("workout") || lower.includes("push")) {
    return {
      action_type: "log_workout",
      confidence: 0.78,
      requires_confirmation: true,
      summary: "Drafted a workout from the command. Review before saving.",
      entities: {},
      proposed_records: {},
      user_editable_fields: ["workout_sets", "duration"],
      missing_fields: [],
      assumptions: ["Local fallback parser used because AI_GATEWAY_API_KEY is not configured."],
      workout_sets: [
        { exercise_name: "Bench Press", set_index: 1, reps: 5, weight: 185, unit: "lb", rpe: 8, notes: "" }
      ],
      food_items: []
    };
  }

  return {
    action_type: "log_meal",
    confidence: 0.72,
    requires_confirmation: true,
    summary: "Estimated a meal from text. Review portions before saving.",
    entities: {},
    proposed_records: {},
    user_editable_fields: ["food_items"],
    missing_fields: ["exact portion size"],
    assumptions: ["Local fallback parser used because AI_GATEWAY_API_KEY is not configured."],
    workout_sets: [],
    food_items: [
      {
        name: text,
        quantity_text: "1 serving",
        calories: 650,
        protein_g: 35,
        carbs_g: 65,
        fat_g: 24,
        confidence: 0.62
      }
    ]
  };
}
