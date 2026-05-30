const corsHeaders = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Methods":"GET, POST, OPTIONS","Access-Control-Allow-Headers":"Content-Type, Authorization"};
const baseUrl = Deno.env.get("INSFORGE_BASE_URL") ?? "https://hxvc7grj.us-east.insforge.app";
function decodeJwtSubject(token: string) { try { const payload = token.split(".")[1]; const padded = payload + "=".repeat((4 - payload.length % 4) % 4); const decoded = atob(padded.replace(/-/g, "+").replace(/_/g, "/")); const jsonPayload = JSON.parse(decoded); return typeof jsonPayload.sub === "string" ? jsonPayload.sub : null; } catch { return null; } }
async function rpc(token: string, name: string, body: Record<string, unknown> = {}) { const response = await fetch(`${baseUrl}/api/database/rpc/${name}`, { method: "POST", headers: {"Authorization": `Bearer ${token}`, "Content-Type": "application/json"}, body: JSON.stringify(body) }); if (!response.ok) throw new Error(`${name} failed: ${response.status} ${await response.text()}`); return response.json(); }
function json(payload: unknown, status = 200) { return new Response(JSON.stringify(payload), { status, headers: {...corsHeaders, "Content-Type": "application/json"} }); }
async function socialHandler(req: Request, run: (token: string, body: Record<string, unknown>, userId: string) => Promise<unknown>) { if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders }); if (req.method !== "GET" && req.method !== "POST") return json({ error: "Method not allowed" }, 405); const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? ""; const userId = decodeJwtSubject(token); if (!token || !userId) return json({ error: "Authorization bearer token is required" }, 401); const url = new URL(req.url); const queryBody = Object.fromEntries(url.searchParams.entries()); const requestBody = req.method === "POST" ? await req.json().catch(() => ({})) : {}; try { return json(await run(token, { ...queryBody, ...requestBody }, userId)); } catch (error) { return json({ error: error instanceof Error ? error.message : "Request failed" }, 500); } }

export default async function(req: Request): Promise<Response> {
  return socialHandler(req, async (token, body) => ({
    proof_posts: await rpc(token, "fc_proof_feed", {
      p_target_user_id: body.target_user_id ?? body.targetUserId ?? null
    })
  }));
}
