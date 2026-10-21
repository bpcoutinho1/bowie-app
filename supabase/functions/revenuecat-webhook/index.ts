// Keeps the Premium bought in the App Store or Google Play in account_plans.
// RevenueCat calls this function on every purchase, renewal, cancellation,
// expiration or transfer. The event only says whose subscription changed: the
// function then asks RevenueCat for the current state of that person, so
// events that arrive late or out of order never undo a newer one.
//
// Deploy: docs/guias/assinaturas.md (function name "revenuecat-webhook",
// "Verify JWT" off: RevenueCat sends its own secret instead). Secrets:
// REVENUECAT_WEBHOOK_SECRET (the Authorization value set in RevenueCat, after
// "Bearer ") and REVENUECAT_SECRET_API_KEY (sk_..., RevenueCat → API keys).

import { createClient } from "npm:@supabase/supabase-js@2.117.2";

const ENTITLEMENT = "premium";
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
// A purchase without an end (not sold today) is kept as a far date: the app
// reads dates, and "infinity" is not one.
const NO_END = "2999-12-31T00:00:00Z";

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Compares without leaking, through timing, how much of the secret matched. */
function sameSecret(given: string, expected: string): boolean {
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}

/** The Supabase accounts an event is about: the buyer and, in a transfer,
 * both sides. Anonymous RevenueCat ids are skipped. */
function accountsOf(event: Record<string, unknown>): string[] {
  const ids = new Set<string>();
  const add = (value: unknown) => {
    if (typeof value === "string" && UUID.test(value)) ids.add(value.toLowerCase());
  };
  add(event.app_user_id);
  add(event.original_app_user_id);
  for (const key of ["aliases", "transferred_from", "transferred_to"]) {
    const list = event[key];
    if (Array.isArray(list)) list.forEach(add);
  }
  return [...ids];
}

type Premium = { until: string | null; product: string | null };

/** The Premium RevenueCat has for the account right now. */
async function premiumOf(userId: string, apiKey: string): Promise<Premium> {
  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
    { headers: { Authorization: `Bearer ${apiKey}` } },
  );
  if (!response.ok) {
    throw new Error(`revenuecat ${response.status}`);
  }
  const body = await response.json();
  const entitlement = body?.subscriber?.entitlements?.[ENTITLEMENT];
  if (!entitlement) return { until: null, product: null };
  return {
    until: entitlement.expires_date ?? NO_END,
    product: entitlement.product_identifier ?? null,
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  const apiKey = Deno.env.get("REVENUECAT_SECRET_API_KEY");
  if (!secret || !apiKey) {
    console.error("revenuecat-webhook is missing its secrets");
    return json(503, { error: "not_configured" });
  }
  if (!sameSecret(req.headers.get("Authorization") ?? "", `Bearer ${secret}`)) {
    return json(401, { error: "unauthorized" });
  }

  let event: Record<string, unknown>;
  try {
    const body = await req.json();
    event = body?.event ?? {};
  } catch {
    return json(400, { error: "bad_request" });
  }

  const accounts = accountsOf(event);
  if (accounts.length === 0) {
    // A test event from the dashboard, or a buyer who never signed in.
    return json(200, { ok: true, accounts: 0 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  for (const userId of accounts) {
    let premium: Premium;
    try {
      premium = await premiumOf(userId, apiKey);
    } catch (error) {
      // RevenueCat sends the event again later.
      console.error("subscriber not read", (error as Error).message);
      return json(502, { error: "revenuecat_unreachable" });
    }
    const { error } = await admin.from("account_plans").upsert(
      {
        user_id: userId,
        store_premium_until: premium.until,
        store_product: premium.product,
        store_updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" },
    );
    if (error) {
      // 23503: the account was deleted. Nothing to keep.
      if (error.code === "23503") continue;
      console.error("plan not saved", error.code);
      return json(500, { error: "not_saved" });
    }
  }

  // Only counts: no ids or emails in the response or the log.
  return json(200, { ok: true, accounts: accounts.length });
});
