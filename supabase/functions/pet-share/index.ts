// The pet sheet a tutor shares with a hotel, a daycare or a vet: given the
// token of a link that is still valid, returns the pet's current data as JSON
// for the page in web-share/ to show.
//
// Public on purpose: whoever has the link sees the sheet, as the tutor chose.
// The token (32+ random characters) is the only key, so the function never
// says whether a token exists, only that the link does not work.
//
// Deploy: docs/guias/ficha-compartilhada.md (function name "pet-share",
// "Verify JWT" off). Uses the SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY that
// Supabase gives every function; no other secret.

import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import { z } from "npm:zod@4.6.5";

const BUCKET = "pet-photos";
// Long enough to read the sheet, open the photos and the PDFs.
const URL_SECONDS = 60 * 60;
const DUE_SOON_DAYS = 30;
const MAX_EVENTS = 200;
const MAX_OTHER_TUTORS = 10;

const Body = z.object({ token: z.string().regex(/^[A-Za-z0-9_-]{32,64}$/) });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS,
      "Content-Type": "application/json",
      // Health data: never kept by a proxy or the browser cache.
      "Cache-Control": "no-store",
    },
  });
}

const GONE = {
  error: "not_found",
  message: "Este link expirou ou foi cancelado. Peça um novo a quem cuida do pet.",
};

/** Today in Brazil, as YYYY-MM-DD. */
function today(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo" }).format(new Date());
}

function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
}

function fold(text: string): string {
  return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim();
}

function list<T>(raw: unknown): T[] {
  try {
    const value = typeof raw === "string" ? JSON.parse(raw) : raw;
    return Array.isArray(value) ? value : [];
  } catch {
    return [];
  }
}

const UNITS: Record<string, [string, string]> = {
  tablet: ["comprimido", "comprimidos"],
  chew: ["tablete", "tabletes"],
  capsule: ["cápsula", "cápsulas"],
  drop: ["gota", "gotas"],
  ml: ["ml", "ml"],
  sachet: ["sachê", "sachês"],
  pipette: ["pipeta", "pipetas"],
  application: ["aplicação", "aplicações"],
  collar: ["coleira", "coleiras"],
  unit: ["unidade", "unidades"],
};

const PERIODS: Record<string, string> = { morning: "Manhã", afternoon: "Tarde", night: "Noite" };

function joinPt(items: string[]): string {
  if (items.length <= 1) return items.join("");
  return `${items.slice(0, -1).join(", ")} e ${items[items.length - 1].toLowerCase()}`;
}

type Med = {
  name: string;
  strength: string | null;
  amount: number;
  unit: string;
  frequency: string;
  interval_count: number;
  times: unknown;
  start_on: string;
  end_on: string | null;
  notes: string | null;
};

function medication(med: Med) {
  const amount = Number(med.amount);
  const number = Number.isInteger(amount) ? String(amount) : String(amount).replace(".", ",");
  const [one, many] = UNITS[med.unit] ?? UNITS.unit;
  const times = list<{ period?: string; time?: string }>(med.times)
    .filter((t) => t.period && PERIODS[t.period] && typeof t.time === "string")
    .map((t) => ({ period: PERIODS[t.period!], time: t.time! }));
  const schedule = {
    daily: joinPt(times.map((t) => `${t.period} (${t.time})`)) || "Todo dia",
    weekly: "Toda semana",
    monthly: "Todo mês",
    every_days: `A cada ${med.interval_count} dias`,
    every_months: `A cada ${med.interval_count} meses`,
  }[med.frequency] ?? "";
  return {
    name: med.name,
    dose: [`${number} ${amount <= 1 ? one : many}`, med.strength].filter(Boolean).join(" · "),
    schedule,
    start_on: med.start_on,
    end_on: med.end_on,
    notes: med.notes,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed", message: "Use POST." });

  let token: string;
  try {
    token = Body.parse(await req.json()).token;
  } catch {
    return json(404, GONE);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const { data: share } = await admin
    .from("pet_shares")
    .select("id, pet_id, preset, expires_at, revoked_at")
    .eq("token", token)
    .maybeSingle();
  if (!share || share.revoked_at || Date.parse(share.expires_at) <= Date.now()) {
    return json(404, GONE);
  }
  const petId: string = share.pet_id;
  const vet = share.preset === "vet";

  const { data: pet } = await admin
    .from("pets")
    .select("name, species, sex, breed, birth_date, birth_date_estimated, weight_kg, photo_path, deleted_at")
    .eq("id", petId)
    .maybeSingle();
  if (!pet || pet.deleted_at) return json(404, GONE);

  const [vaccines, notes, meds, owner, others, events] = await Promise.all([
    admin
      .from("pet_vaccines")
      .select("kind, name, applied_on, next_due_on, product, lot, veterinarian, proof_paths")
      .eq("pet_id", petId)
      .is("deleted_at", null),
    admin
      .from("pet_health_notes")
      .select("kind, title, details")
      .eq("pet_id", petId)
      .is("deleted_at", null),
    admin
      .from("pet_medications")
      .select("name, strength, amount, unit, frequency, interval_count, times, start_on, end_on, notes")
      .eq("pet_id", petId)
      .is("deleted_at", null),
    admin
      .from("pet_tutors")
      .select("user_id, email")
      .eq("pet_id", petId)
      .eq("role", "owner")
      .eq("status", "accepted")
      .is("deleted_at", null)
      .limit(1)
      .maybeSingle(),
    // The other tutors, for when the main one does not answer.
    admin
      .from("pet_tutors")
      .select("user_id, email")
      .eq("pet_id", petId)
      .eq("role", "tutor")
      .eq("status", "accepted")
      .not("user_id", "is", null)
      .is("deleted_at", null)
      .limit(MAX_OTHER_TUTORS),
    vet
      ? admin
        .from("pet_events")
        .select("kind, title, occurs_on, occurs_time, notes, contact_id, photo_paths, files")
        .eq("pet_id", petId)
        .is("deleted_at", null)
        .order("occurs_on", { ascending: false })
        .limit(MAX_EVENTS)
      : Promise.resolve({ data: [] as Record<string, unknown>[] }),
  ]);
  if (
    vaccines.error || notes.error || meds.error || owner.error || others.error ||
    ("error" in events && events.error)
  ) {
    console.error(`pet-share failed reading share=${share.id}`);
    return json(500, { error: "server", message: "Não foi possível abrir a ficha agora. Tente de novo em alguns minutos." });
  }

  // Every file is private; the page gets short-lived links to each one.
  const paths = new Set<string>();
  if (pet.photo_path) paths.add(pet.photo_path);
  for (const dose of vaccines.data ?? []) list<string>(dose.proof_paths).forEach((p) => paths.add(p));
  for (const event of events.data ?? []) {
    list<string>(event.photo_paths).forEach((p) => paths.add(p));
    list<{ path?: string }>(event.files).forEach((f) => f.path && paths.add(f.path));
  }
  const urls = new Map<string, string>();
  if (paths.size > 0) {
    const { data: signed } = await admin.storage.from(BUCKET).createSignedUrls([...paths], URL_SECONDS);
    for (const item of signed ?? []) {
      if (item.path && item.signedUrl && !item.error) urls.set(item.path, item.signedUrl);
    }
  }
  const url = (path: string) => urls.get(path) ?? null;

  const day = today();

  // One group per vaccine, the latest dose deciding the status.
  const groups = new Map<string, Record<string, unknown>[]>();
  for (const dose of vaccines.data ?? []) {
    const key = `${dose.kind}:${fold(dose.name)}`;
    groups.set(key, [...(groups.get(key) ?? []), dose]);
  }
  const vaccineList = [...groups.values()]
    .map((doses) => {
      doses.sort((a, b) => String(b.applied_on).localeCompare(String(a.applied_on)));
      const latest = doses[0];
      const days = daysBetween(day, String(latest.next_due_on));
      return {
        kind: latest.kind,
        name: latest.name,
        status: days < 0 ? "overdue" : days <= DUE_SOON_DAYS ? "due_soon" : "up_to_date",
        days_left: days,
        doses: doses.map((dose) => ({
          applied_on: dose.applied_on,
          next_due_on: dose.next_due_on,
          product: dose.product,
          lot: dose.lot,
          veterinarian: dose.veterinarian,
          proofs: list<string>(dose.proof_paths).map(url).filter(Boolean),
        })),
      };
    })
    .sort((a, b) => a.days_left - b.days_left);

  const order = { special_care: 0, allergy: 1, diet: 2 } as Record<string, number>;
  const noteList = (notes.data ?? [])
    .sort((a, b) => (order[a.kind] ?? 9) - (order[b.kind] ?? 9) || a.title.localeCompare(b.title, "pt-BR"));

  const medList = (meds.data as Med[] ?? [])
    .filter((med) => !med.end_on || med.end_on >= day)
    .sort((a, b) => a.name.localeCompare(b.name, "pt-BR"))
    .map(medication);

  type Contact = { name: string | null; phone: string | null; email: string | null };
  // Name and phone from the account; the email only when there is no phone
  // to call.
  const contactOf = async (row: { user_id: string | null; email: string }): Promise<Contact> => {
    let name: string | null = null;
    let phone: string | null = null;
    if (row.user_id) {
      const { data } = await admin.auth.admin.getUserById(row.user_id);
      const meta = data?.user?.user_metadata ?? {};
      name = typeof meta.name === "string" && meta.name.trim() ? meta.name.trim() : null;
      phone = typeof meta.phone === "string" && meta.phone.trim() ? meta.phone.trim() : null;
    }
    return { name, phone, email: phone ? null : row.email };
  };
  const tutor = owner.data ? await contactOf(owner.data) : null;
  const otherTutors = await Promise.all((others.data ?? []).map(contactOf));

  let eventList: unknown[] | undefined;
  if (vet) {
    const contactIds = [...new Set((events.data ?? []).map((e) => e.contact_id).filter(Boolean))] as string[];
    const contacts = new Map<string, string>();
    if (contactIds.length > 0) {
      const { data } = await admin.from("house_contacts").select("id, name").in("id", contactIds);
      for (const contact of data ?? []) contacts.set(contact.id, contact.name);
    }
    eventList = (events.data ?? []).map((event) => ({
      kind: event.kind,
      title: event.title,
      occurs_on: event.occurs_on,
      time: typeof event.occurs_time === "string" ? event.occurs_time.slice(0, 5) : null,
      notes: event.notes,
      contact: event.contact_id ? contacts.get(event.contact_id as string) ?? null : null,
      photos: list<string>(event.photo_paths).map(url).filter(Boolean),
      files: list<{ path?: string; name?: string }>(event.files)
        .filter((f) => f.path && urls.has(f.path))
        .map((f) => ({ name: f.name ?? "Arquivo.pdf", url: url(f.path!) })),
    }));
  }

  // Lets the tutors see that the sheet was opened. Best effort.
  await admin.from("pet_shares").update({ last_viewed_at: new Date().toISOString() }).eq("id", share.id);

  // Counts only: nothing about the pet or the people in the logs.
  console.log(`pet-share ok share=${share.id} preset=${share.preset}`);

  return json(200, {
    preset: share.preset,
    expires_at: share.expires_at,
    today: day,
    pet: {
      name: pet.name,
      species: pet.species,
      sex: pet.sex,
      breed: pet.breed,
      birth_date: pet.birth_date,
      birth_date_estimated: pet.birth_date_estimated,
      weight_kg: pet.weight_kg,
      photo_url: pet.photo_path ? url(pet.photo_path) : null,
    },
    notes: noteList,
    medications: medList,
    vaccines: vaccineList,
    tutor,
    other_tutors: otherTutors,
    ...(vet ? { events: eventList } : {}),
  });
});
