// Deletes the account of the person signed in, for good
// (docs/produto/contas-e-tutores.md#exclusão-da-conta):
//   1. delete_account (migration 20261020120000) hands each pet with other
//      tutors to the one the person chose, deletes the pets without other
//      tutors with all their records, and takes the person out of the rest;
//   2. the files of the deleted pets leave the storage;
//   3. the login goes, and with it the plan, the shopping list and the
//      contacts.
//
// Deploy: docs/guias/excluir-conta.md (function name "delete-account",
// "Verify JWT" on). Uses the SUPABASE_URL, SUPABASE_ANON_KEY and
// SUPABASE_SERVICE_ROLE_KEY that Supabase gives every function.

import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import { z } from "npm:zod@4.6.5";

const BUCKET = "pet-photos";

// {"<pet id>": "<pet_tutors id of the new main tutor>"}
const Body = z.object({
  transfers: z.record(z.uuid(), z.uuid()).default({}),
});

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function failure(status: number, code: string, message: string) {
  return json(status, { error: code, message });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return failure(405, "method_not_allowed", "Use POST.");
  }

  // Only the person signed in can delete their own account.
  const authorization = req.headers.get("Authorization") ?? "";
  const asUser = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authorization } } },
  );
  const { data: auth, error: authError } = await asUser.auth.getUser();
  if (authError || !auth.user) {
    return failure(401, "unauthorized", "Entre na sua conta de novo para excluí-la.");
  }
  const userId = auth.user.id;

  let body: z.infer<typeof Body>;
  try {
    body = Body.parse(await req.json());
  } catch {
    return failure(400, "bad_request", "Pedido inválido. Atualize o app e tente de novo.");
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const { data: gone, error: eraseError } = await admin.rpc("delete_account", {
    target: userId,
    transfers: body.transfers,
  });
  if (eraseError) {
    if (eraseError.code === "P0001") {
      return failure(
        409,
        "choose_main_tutor",
        "Escolha quem fica com cada pet que tem outros tutores e tente de novo.",
      );
    }
    // No personal data in the log: only the error code.
    console.error("delete_account failed", eraseError.code);
    return failure(500, "erase_failed", "Não foi possível excluir a conta agora. Tente de novo.");
  }

  // The files of the deleted pets: <pet id>/<file>. A failure here leaves
  // files nobody can open (their pet is gone), so the account still goes.
  for (const petId of (gone as string[] | null) ?? []) {
    for (let round = 0; round < 20; round++) {
      const { data: files, error } = await admin.storage
        .from(BUCKET)
        .list(petId, { limit: 1000 });
      if (error || !files || files.length === 0) break;
      const { error: removeError } = await admin.storage
        .from(BUCKET)
        .remove(files.map((file) => `${petId}/${file.name}`));
      if (removeError) {
        console.error("pet files not removed", removeError.name);
        break;
      }
    }
  }

  const { error: userError } = await admin.auth.admin.deleteUser(userId);
  if (userError) {
    console.error("auth user not deleted", userError.status);
    return failure(500, "delete_failed", "Não foi possível excluir a conta agora. Tente de novo.");
  }

  return json(200, { deleted: true });
});
