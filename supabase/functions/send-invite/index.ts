// Sends the email inviting someone to care for a pet
// (docs/produto/contas-e-tutores.md#convite). The main tutor creates the
// pending tutor row in the app; once it is on the server, the app calls this
// function with the row's id, and the person gets an email from the Bowie
// address saying who invited them, for which pet, and how to accept.
//
// Deploy: docs/guias/convites.md (function name "send-invite", "Verify JWT"
// on). Secrets: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS (the mailbox that
// sends, contato@bowieapp.pet) and, optionally, INVITE_URL (where to get the
// app; https://bowieapp.pet by default).

import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import nodemailer from "npm:nodemailer@6.9.16";
import { z } from "npm:zod@4.6.5";

// Minutes before the same invitation can be sent again.
const RESEND_MINUTES = 2;

const Body = z.object({ tutor_id: z.uuid() });

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function failure(status: number, code: string, message: string) {
  return json(status, { error: code, message });
}

function escape(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

/** "do Bowie" / "da Mia", as the app says it. */
function ofPet(name: string, sex: string | null): string {
  return sex === "female" ? `da ${name}` : sex === "male" ? `do ${name}` : `de ${name}`;
}

function message(inviter: string, pet: string, of: string, email: string, link: string) {
  const subject = `${inviter} convidou você para cuidar ${of} no Bowie`;
  const text = [
    `${inviter} convidou você para cuidar ${of} junto no Bowie, o app para registrar a vida do pet: vacinas, remédios, diário de saúde e a ficha para hotel, creche ou veterinário.`,
    "",
    "Para aceitar:",
    `1. Baixe o Bowie: ${link}`,
    `2. Entre ou crie a sua conta com este email: ${email}`,
    `3. Na aba Pets, toque em "Aceitar" no convite ${of}.`,
    "",
    "Se você não conhece quem enviou, pode ignorar este email.",
    "",
    "Bowie · Quem ama, lembra.",
  ].join("\n");
  const html = `<!doctype html>
<html lang="pt-BR"><body style="margin:0;background:#F4F6F8;font-family:Figtree,Helvetica,Arial,sans-serif;color:#1D2B45">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F4F6F8;padding:24px 16px">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#FFFFFF;border-radius:18px;padding:32px 24px">
<tr><td>
<p style="margin:0 0 24px;font-size:28px;font-weight:800;letter-spacing:-0.5px">bowie</p>
<h1 style="margin:0 0 12px;font-size:22px;line-height:1.3;font-weight:800">${escape(inviter)} convidou você para cuidar ${escape(of)}</h1>
<p style="margin:0 0 20px;font-size:16px;line-height:1.5;color:#4A5670">No Bowie, quem cuida ${escape(of)} registra e acompanha tudo junto: vacinas, remédios, diário de saúde e a ficha para hotel, creche ou veterinário.</p>
<p style="margin:0 0 8px;font-size:16px;font-weight:600">Para aceitar:</p>
<ol style="margin:0 0 24px;padding-left:20px;font-size:16px;line-height:1.6">
<li>Baixe o Bowie.</li>
<li>Entre ou crie a sua conta com este email: <strong>${escape(email)}</strong></li>
<li>Na aba Pets, toque em <strong>Aceitar</strong> no convite ${escape(of)}.</li>
</ol>
<p style="margin:0 0 28px"><a href="${escape(link)}" style="display:inline-block;background:#1D2B45;color:#FFFFFF;text-decoration:none;font-weight:600;font-size:16px;padding:14px 24px;border-radius:12px">Baixar o Bowie</a></p>
<p style="margin:0;font-size:13px;line-height:1.5;color:#4A5670">Se você não conhece quem enviou, pode ignorar este email. O convite para cuidar ${escape(pet)} só vale para este endereço.</p>
</td></tr>
</table>
<p style="margin:16px 0 0;font-size:12px;color:#4A5670">Bowie · Quem ama, lembra.</p>
</td></tr>
</table>
</body></html>`;
  return { subject, text, html };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return failure(405, "method_not_allowed", "Use POST.");

  const authorization = req.headers.get("Authorization") ?? "";
  const asUser = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authorization } } },
  );
  const { data: auth, error: authError } = await asUser.auth.getUser();
  if (authError || !auth.user) {
    return failure(401, "unauthorized", "Entre na sua conta de novo para convidar.");
  }

  const smtp = {
    host: Deno.env.get("SMTP_HOST"),
    port: Number(Deno.env.get("SMTP_PORT") ?? "465"),
    user: Deno.env.get("SMTP_USER"),
    pass: Deno.env.get("SMTP_PASS"),
  };
  if (!smtp.host || !smtp.user || !smtp.pass) {
    console.error("send-invite is missing its SMTP secrets");
    return failure(503, "not_configured", "O envio de convites ainda não foi configurado no servidor.");
  }

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

  const { data: invite } = await admin
    .from("pet_tutors")
    .select("id, pet_id, email, role, status, deleted_at, invited_at")
    .eq("id", body.tutor_id)
    .maybeSingle();
  if (!invite || invite.deleted_at || invite.role !== "tutor" || invite.status !== "pending") {
    return failure(404, "not_found", "Este convite não está mais pendente.");
  }

  // Only the pet's main tutor sends its invitations.
  const { data: owner } = await admin
    .from("pet_tutors")
    .select("id")
    .eq("pet_id", invite.pet_id)
    .eq("user_id", auth.user.id)
    .eq("role", "owner")
    .eq("status", "accepted")
    .is("deleted_at", null)
    .maybeSingle();
  if (!owner) {
    return failure(403, "forbidden", "Só o tutor principal pode enviar o convite.");
  }

  if (invite.invited_at) {
    const wait = Date.parse(invite.invited_at) + RESEND_MINUTES * 60_000 - Date.now();
    if (wait > 0) {
      return failure(429, "too_soon", "O convite acabou de ser enviado. Espere alguns minutos para reenviar.");
    }
  }

  const { data: pet } = await admin
    .from("pets")
    .select("name, sex, deleted_at")
    .eq("id", invite.pet_id)
    .maybeSingle();
  if (!pet || pet.deleted_at) return failure(404, "not_found", "Este pet não está mais disponível.");

  const meta = auth.user.user_metadata ?? {};
  const inviter = typeof meta.name === "string" && meta.name.trim()
    ? meta.name.trim()
    : (auth.user.email ?? "Um tutor");
  const link = Deno.env.get("INVITE_URL") || "https://bowieapp.pet";
  const { subject, text, html } = message(
    inviter,
    pet.name,
    ofPet(pet.name, pet.sex),
    invite.email,
    link,
  );

  try {
    const transport = nodemailer.createTransport({
      host: smtp.host,
      port: smtp.port,
      secure: smtp.port === 465,
      auth: { user: smtp.user, pass: smtp.pass },
    });
    await transport.sendMail({
      from: { name: "Bowie", address: smtp.user },
      to: invite.email,
      subject,
      text,
      html,
    });
  } catch (error) {
    // No addresses or content in the log: only the kind of failure.
    console.error("invite not sent", (error as { code?: string }).code ?? "unknown");
    return failure(502, "not_sent", "Não foi possível enviar o email agora. Tente de novo.");
  }

  await admin
    .from("pet_tutors")
    .update({ invited_at: new Date().toISOString() })
    .eq("id", invite.id);

  return json(200, { sent: true });
});
