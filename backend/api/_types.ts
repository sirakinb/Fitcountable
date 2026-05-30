export type JsonResponse = {
  status(code: number): JsonResponse;
  json(payload: unknown): void;
};

export type HttpRequest = {
  method?: string;
  body?: unknown;
  query: Record<string, string | string[] | undefined>;
};

