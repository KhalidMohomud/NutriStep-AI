// delete-account: erase a user everywhere — required by the App Store for any
// app that lets people sign up.
//
// Widest to narrowest, so a failure leaves an account that can still sign in
// and retry:
//   1. their meal photos (the bucket isn't covered by the database cascade)
//   2. the auth user — profiles, meals, scan/coach usage and activity_logs all
//      cascade from it
// Each step is safe to repeat.

import { createClient } from "jsr:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  const token = req.headers.get("Authorization")?.replace(/^Bearer /, "");
  const { data: auth, error: authError } = token ? await admin.auth.getUser(token) : { data: null, error: true };
  const user = auth?.user;
  if (authError || !user) return json({ error: "unauthorized" }, 401);

  try {
    // 1. photos, a page at a time
    let removed = 0;
    for (;;) {
      const { data: files, error } = await admin.storage.from("meal-photos").list(user.id, { limit: 1000 });
      if (error) throw new Error(`list failed: ${error.message}`);
      if (!files || files.length === 0) break;
      const { error: removeError } = await admin.storage
        .from("meal-photos")
        .remove(files.map((f) => `${user.id}/${f.name}`));
      if (removeError) throw new Error(`remove failed: ${removeError.message}`);
      removed += files.length;
      if (files.length < 1000) break;
    }

    // 2. the account; the rest of their rows go with it
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw new Error(`deleteUser failed: ${deleteError.message}`);

    console.log(`deleted ${user.id}: ${removed} photo(s), account and rows`);
    return json({ deleted: true });
  } catch (e) {
    console.error("delete-account failed", e);
    return json({ error: "delete_failed" }, 500);
  }
});
