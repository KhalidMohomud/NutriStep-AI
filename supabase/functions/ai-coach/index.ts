// ai-coach: a short nutrition conversation grounded in the user's own data.
//
// The app sends the conversation so far; this adds who they are (goal, daily
// targets), what they ate today and this week, and today's steps, then asks
// Gemini for a reply in the user's language. One question spends one of the
// day's allowance (Free 3, Pro 50) — spent before Gemini is called, given back
// if the call fails.
//
// Secrets: GEMINI_API_KEY. SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected.

import { createClient } from "jsr:@supabase/supabase-js@2";

const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash-lite";
const GEMINI_BASE = Deno.env.get("GEMINI_API_BASE") ?? "https://generativelanguage.googleapis.com";

const LANGUAGES: Record<string, string> = { en: "English", so: "Somali", ar: "Arabic" };
const MAX_TURNS = 12; // the conversation the model sees
const MAX_CHARS = 1000; // per message

type Turn = { role: "user" | "model"; text: string };

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

function localDate(offsetMinutes: number, daysAgo = 0): string {
  return new Date(Date.now() + offsetMinutes * 60_000 - daysAgo * 86_400_000).toISOString().slice(0, 10);
}

// deno-lint-ignore no-explicit-any
function context(profile: any, meals: any[], steps: number | null, offset: number): string {
  const today = localDate(offset);
  const dayOf = (iso: string) => new Date(new Date(iso).getTime() + offset * 60_000).toISOString().slice(0, 10);

  const todays = meals.filter((m) => dayOf(m.logged_at) === today);
  const eaten = todays.reduce(
    (t, m) => ({
      kcal: t.kcal + (m.calories ?? 0),
      p: t.p + (m.protein_g ?? 0),
      c: t.c + (m.carbs_g ?? 0),
      f: t.f + (m.fat_g ?? 0),
    }),
    { kcal: 0, p: 0, c: 0, f: 0 },
  );

  const byDay = new Map<string, number>();
  for (const m of meals) byDay.set(dayOf(m.logged_at), (byDay.get(dayOf(m.logged_at)) ?? 0) + (m.calories ?? 0));
  const week = [...byDay.entries()].sort().map(([d, kcal]) => `${d}: ${kcal} kcal`).join("; ");

  return [
    `Goal: ${profile.goal} weight. Now ${profile.weight_kg} kg, target ${profile.target_weight_kg} kg, pace ${profile.pace_kg_per_week} kg/week.`,
    `Diet preference: ${profile.diet_preference}. Activity: ${profile.activity_level}.`,
    `Daily targets: ${profile.daily_calories} kcal, protein ${profile.protein_g} g, carbs ${profile.carbs_g} g, fat ${profile.fat_g} g. Step goal ${profile.step_goal}.`,
    `Today so far: ${eaten.kcal} kcal, protein ${eaten.p} g, carbs ${eaten.c} g, fat ${eaten.f} g, ${steps ?? "unknown"} steps.`,
    `Today's meals: ${todays.map((m) => `${m.name} (${m.calories} kcal)`).join(", ") || "none logged yet"}.`,
    `Last 7 days: ${week || "no meals logged"}.`,
  ].join("\n");
}

const instructions = (language: string, facts: string) => `You are NutriStep AI's nutrition coach.

Answer in ${language}. Keep it short: 2-5 sentences, or a few bullet points when listing foods.
Be warm, practical and specific to the numbers below — say how much is left today, suggest real foods.
You are not a doctor. For medical conditions, pregnancy, eating disorders or medication, give general
information only and suggest seeing a doctor or dietitian. Never suggest eating under 1200 kcal a day.
If asked about something unrelated to food, activity or health, say briefly that you can only help with those.

What you know about this person:
${facts}`;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  const token = req.headers.get("Authorization")?.replace(/^Bearer /, "");
  const { data: auth, error: authError } = token ? await admin.auth.getUser(token) : { data: null, error: true };
  const user = auth?.user;
  if (authError || !user) return json({ error: "unauthorized" }, 401);

  const body = await req.json().catch(() => null);
  const turns: Turn[] = (Array.isArray(body?.messages) ? body.messages : [])
    .filter((t: Turn) => (t?.role === "user" || t?.role === "model") && typeof t?.text === "string" && t.text.trim())
    .slice(-MAX_TURNS)
    .map((t: Turn) => ({ role: t.role, text: t.text.slice(0, MAX_CHARS) }));
  if (turns.length === 0 || turns[turns.length - 1].role !== "user") {
    return json({ error: "invalid_messages" }, 400);
  }
  const offset = Math.max(-840, Math.min(840, Number(body?.utc_offset_minutes) || 0));
  const date = localDate(offset);

  const { data: used, error: quotaError } = await admin.rpc("consume_coach", { p_user: user.id, p_date: date });
  if (quotaError) {
    console.error("consume_coach failed", quotaError);
    return json({ error: "server_error" }, 500);
  }
  const { data: limit } = await admin.rpc("coach_limit", { p_user: user.id });
  if (used === null) return json({ error: "quota_exceeded", limit }, 429);

  try {
    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) throw new Error("GEMINI_API_KEY is not set");

    const since = new Date(Date.now() - 7 * 86_400_000).toISOString();
    const [{ data: profile }, { data: meals }, { data: activity }] = await Promise.all([
      admin.from("profiles").select("*").eq("id", user.id).single(),
      admin
        .from("meals")
        .select("name, calories, protein_g, carbs_g, fat_g, logged_at")
        .eq("user_id", user.id)
        .eq("status", "completed")
        .gte("logged_at", since)
        .order("logged_at"),
      admin.from("activity_logs").select("steps").eq("user_id", user.id).eq("date", date).maybeSingle(),
    ]);
    if (!profile) throw new Error("no profile");

    const language = LANGUAGES[profile.language] ?? "English";
    const res = await fetch(`${GEMINI_BASE}/v1beta/models/${MODEL}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      signal: AbortSignal.timeout(30_000),
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: instructions(language, context(profile, meals ?? [], activity?.steps ?? null, offset)) }] },
        contents: turns.map((t) => ({ role: t.role, parts: [{ text: t.text }] })),
        generationConfig: { temperature: 0.6, maxOutputTokens: 500 },
      }),
    });
    if (!res.ok) throw new Error(`Gemini ${res.status}: ${(await res.text()).slice(0, 300)}`);

    const out = await res.json();
    const reply: string | undefined = out?.candidates?.[0]?.content?.parts
      ?.map((p: { text?: string }) => p.text ?? "")
      .join("")
      .trim();
    if (!reply) throw new Error("Gemini returned no text");

    return json({ reply, used, limit });
  } catch (e) {
    console.error("ai-coach failed", e);
    await admin.rpc("refund_coach", { p_user: user.id, p_date: date });
    return json({ error: "coach_failed" }, 502);
  }
});
