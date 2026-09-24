// analyze-meal: meal photo → Gemini → a `meals` row.
//
// The app uploads the (already downsized) photo to the private meal-photos
// bucket under "<user id>/…", then calls this with its path. Order matters:
//   1. who is asking (their JWT)
//   2. spend one scan from today's allowance — before Gemini costs anything
//   3. ask Gemini, validate, write the row
// Anything that doesn't end in a meal gives the scan back and leaves no row.
//
// Secrets: GEMINI_API_KEY (supabase secrets set). SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY are injected by the platform.

import { createClient } from "jsr:@supabase/supabase-js@2";

// Tested on a real meal photo (Sep 2026): ~2 s, ~1,100 input + ~80 output tokens,
// about $0.0005 a scan. gemini-2.5-flash-lite is closed to new accounts;
// gemini-3.1-flash-lite is ~20% cheaper but 2x slower. Swap here or with the
// GEMINI_MODEL secret (no redeploy needed for the secret).
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash-lite";
// Overridable so the local end-to-end test can point at a fake.
const GEMINI_BASE = Deno.env.get("GEMINI_API_BASE") ?? "https://generativelanguage.googleapis.com";

const LANGUAGES: Record<string, string> = { en: "English", so: "Somali", ar: "Arabic" };

const PROMPT = (language: string) => `You are a nutritionist estimating what is on a plate from a single photo.

Rules:
- is_food is false for anything that is not edible food or drink. When it is false, return zeros and an empty name.
- name: what a person would call this meal, 2-5 words, in ${language}, no brand names.
- Estimate the portion actually visible, using the plate, cutlery or hand for scale. Do not return a generic per-100g figure.
- portion_grams: the total weight of the food you can see.
- protein_g * 4 + carbs_g * 4 + fat_g * 9 should land within 10% of calories.`;

const SCHEMA = {
  type: "OBJECT",
  properties: {
    is_food: { type: "BOOLEAN" },
    name: { type: "STRING" },
    portion_grams: { type: "INTEGER" },
    calories: { type: "INTEGER" },
    protein_g: { type: "INTEGER" },
    carbs_g: { type: "INTEGER" },
    fat_g: { type: "INTEGER" },
  },
  required: ["is_food", "name", "portion_grams", "calories", "protein_g", "carbs_g", "fat_g"],
  propertyOrdering: ["is_food", "name", "portion_grams", "calories", "protein_g", "carbs_g", "fat_g"],
};

type Estimate = {
  is_food: boolean;
  name: string;
  portion_grams: number;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

/** The user's calendar date, from the UTC offset the device reports (clamped to real zones). */
function localDate(offsetMinutes: unknown): string {
  const offset = Math.max(-840, Math.min(840, Number(offsetMinutes) || 0));
  return new Date(Date.now() + offset * 60_000).toISOString().slice(0, 10);
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

const clampInt = (n: unknown, max: number) => Math.max(0, Math.min(max, Math.round(Number(n) || 0)));

async function askGemini(image: Uint8Array, mimeType: string, language: string): Promise<Estimate> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new Error("GEMINI_API_KEY is not set");

  const res = await fetch(`${GEMINI_BASE}/v1beta/models/${MODEL}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": key },
    signal: AbortSignal.timeout(30_000),
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [{ inline_data: { mime_type: mimeType, data: toBase64(image) } }, { text: PROMPT(language) }],
        },
      ],
      generationConfig: { responseMimeType: "application/json", responseSchema: SCHEMA, temperature: 0.2 },
    }),
  });
  if (!res.ok) throw new Error(`Gemini ${res.status}: ${(await res.text()).slice(0, 300)}`);

  const body = await res.json();
  const text: string | undefined = body?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini returned no content");
  const raw = JSON.parse(text);

  // The schema shapes the answer; it doesn't bound it.
  return {
    is_food: raw.is_food === true,
    name: String(raw.name ?? "").trim().slice(0, 80),
    portion_grams: clampInt(raw.portion_grams, 5000),
    calories: clampInt(raw.calories, 5000),
    protein_g: clampInt(raw.protein_g, 500),
    carbs_g: clampInt(raw.carbs_g, 800),
    fat_g: clampInt(raw.fat_g, 400),
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  // 1. who is asking
  const token = req.headers.get("Authorization")?.replace(/^Bearer /, "");
  const { data: auth, error: authError } = token ? await admin.auth.getUser(token) : { data: null, error: true };
  const user = auth?.user;
  if (authError || !user) return json({ error: "unauthorized" }, 401);

  const body = await req.json().catch(() => null);
  const imagePath: unknown = body?.image_path;
  // the path prefix is the ownership check — same rule as the bucket's policies
  if (typeof imagePath !== "string" || !imagePath.startsWith(`${user.id}/`) || imagePath.includes("..")) {
    return json({ error: "invalid_image_path" }, 400);
  }
  const date = localDate(body?.utc_offset_minutes);

  // 2. spend a scan
  const { data: used, error: quotaError } = await admin.rpc("consume_scan", { p_user: user.id, p_date: date });
  if (quotaError) {
    console.error("consume_scan failed", quotaError);
    return json({ error: "server_error" }, 500);
  }
  if (used === null) {
    const { data: limit } = await admin.rpc("scan_limit", { p_user: user.id });
    return json({ error: "quota_exceeded", limit }, 429);
  }

  const refund = () => admin.rpc("refund_scan", { p_user: user.id, p_date: date });

  // 3. analyse
  try {
    const { data: profile } = await admin.from("profiles").select("language").eq("id", user.id).single();
    const language = LANGUAGES[profile?.language ?? "en"] ?? "English";

    const { data: file, error: downloadError } = await admin.storage.from("meal-photos").download(imagePath);
    if (downloadError || !file) throw new Error(`download failed: ${downloadError?.message}`);

    const estimate = await askGemini(new Uint8Array(await file.arrayBuffer()), file.type || "image/jpeg", language);

    if (!estimate.is_food) {
      // a photo of a chair is not a meal that failed — it is not a meal
      await refund();
      await admin.storage.from("meal-photos").remove([imagePath]);
      return json({ error: "not_food" }, 422);
    }

    const { data: meal, error: insertError } = await admin
      .from("meals")
      .insert({
        user_id: user.id,
        image_path: imagePath,
        status: "completed",
        name: estimate.name,
        portion_grams: estimate.portion_grams,
        calories: estimate.calories,
        protein_g: estimate.protein_g,
        carbs_g: estimate.carbs_g,
        fat_g: estimate.fat_g,
        source: "ai",
      })
      .select()
      .single();
    if (insertError) throw new Error(`insert failed: ${insertError.message}`);

    return json({ meal, scans_used: used });
  } catch (e) {
    console.error("analyze-meal failed", e);
    await refund();
    return json({ error: "analysis_failed" }, 502);
  }
});
