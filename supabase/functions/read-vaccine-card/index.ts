// Reads a photo of a pet's vaccine card with Claude and returns the doses and
// weights it finds, for the app to show for review before saving anything.
//
// Deploy: docs/guias/publicar-leitura-da-carteirinha.md (Supabase dashboard,
// function name "read-vaccine-card", "Verify JWT" on, secret ANTHROPIC_API_KEY).
//
// The rules in SYSTEM come from docs/produto/carteirinha-de-vacinacao.md.

import Anthropic from "npm:@anthropic-ai/sdk@0.131.0";
import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import { z } from "npm:zod@4.6.5";

const MODEL = "claude-opus-5-5";
const MAX_IMAGES = 4;
// Base64 of a ~3.7 MB photo. The app resizes to 2000 px, well under this.
const MAX_IMAGE_CHARS = 5_000_000;

const SYSTEM = `Você lê fotos de carteirinhas de vacinação de cães e gatos do Brasil e transcreve as doses registradas. Uma pessoa vai conferir o resultado antes de salvar, então prefira deixar um campo vazio e marcá-lo como incerto a adivinhar.

Como a carteirinha é organizada:
- Cada página costuma ser de uma vacina; o título da página é o nome da vacina ("Vacina V10", "Vacina contra Raiva" -> "Raiva", "Vacina contra Giardíase" -> "Giardíase", "Vacina contra Tosse dos Canis" -> "Tosse dos canis").
- Cada linha é uma dose: "Data" (aplicação) e "Revacinar em" (próxima dose), escritos à mão no formato dd/mm/aa.
- Há uma etiqueta adesiva do frasco com produto, fabricante, "Part." (lote), "Fabr." (fabricação) e "Venc." (validade do frasco).
- Há um carimbo do veterinário com nome e CRMV, muitas vezes com assinatura por cima.
- Algumas carteirinhas têm páginas de vermífugo (data, produto, peso) e de peso (data, peso).

Regras:
1. O vencimento da dose (next_due_on) é SEMPRE o "Revacinar em" escrito à mão. NUNCA use o "Venc." da etiqueta: ele é a validade do frasco, não a data da próxima dose.
2. Anos com dois dígitos são do século 21: "26" é 2026.
3. Linhas vazias (só os traços, ou com "Anual" impresso de fundo) não são doses: ignore.
4. Registre todas as doses da página, inclusive as antigas da mesma vacina.
5. Com etiquetas sobrepostas (vacina e diluente), use os dados da etiqueta da vacina.
6. Cabeçalhos e logotipos de clínica não são doses.
7. Datas no formato AAAA-MM-DD. Se não conseguir ler uma data com segurança, deixe "" e inclua o campo em uncertain_fields.
8. product: nome comercial e fabricante, como "Vanguard Plus (Zoetis)". lot: o "Part.". veterinarian: nome e CRMV do carimbo, como "Josiane Borges Viana · CRMV-SP 43507". Use "" para o que não houver.
9. Inclua em uncertain_fields todo campo que você leu com dúvida (letra ruim, assinatura por cima, foto cortada ou desfocada).
10. Se a foto não for de uma carteirinha de vacinação, responda is_vaccine_card = false e listas vazias.
11. Em issues, escreva em português, em uma frase curta, qualquer problema da foto que a pessoa deva saber (por exemplo, "A parte de baixo da página está cortada."). Use "" se não houver.`;

const DOSE_FIELDS = [
  "kind",
  "name",
  "applied_on",
  "next_due_on",
  "product",
  "lot",
  "veterinarian",
] as const;

// Structured outputs: every object closed and every field required, so the
// response always parses into this shape.
const OUTPUT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["is_vaccine_card", "doses", "weights", "issues"],
  properties: {
    is_vaccine_card: { type: "boolean" },
    doses: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: [...DOSE_FIELDS, "uncertain_fields"],
        properties: {
          kind: { type: "string", enum: ["vaccine", "dewormer"] },
          name: { type: "string" },
          applied_on: { type: "string", description: "AAAA-MM-DD ou vazio" },
          next_due_on: { type: "string", description: "AAAA-MM-DD ou vazio" },
          product: { type: "string" },
          lot: { type: "string" },
          veterinarian: { type: "string" },
          uncertain_fields: {
            type: "array",
            items: { type: "string", enum: [...DOSE_FIELDS] },
          },
        },
      },
    },
    weights: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["measured_on", "weight_kg"],
        properties: {
          measured_on: { type: "string", description: "AAAA-MM-DD ou vazio" },
          weight_kg: { type: "number" },
        },
      },
    },
    issues: { type: "string" },
  },
};

const Dose = z.object({
  kind: z.enum(["vaccine", "dewormer"]),
  name: z.string(),
  applied_on: z.string(),
  next_due_on: z.string(),
  product: z.string(),
  lot: z.string(),
  veterinarian: z.string(),
  uncertain_fields: z.array(z.enum(DOSE_FIELDS)),
});

const Reading = z.object({
  is_vaccine_card: z.boolean(),
  doses: z.array(Dose),
  weights: z.array(z.object({ measured_on: z.string(), weight_kg: z.number() })),
  issues: z.string(),
});

const Body = z.object({
  images: z
    .array(
      z.object({
        media_type: z.enum(["image/jpeg", "image/png", "image/webp"]),
        data: z.string().min(1).max(MAX_IMAGE_CHARS),
      }),
    )
    .min(1)
    .max(MAX_IMAGES),
});

/** A real calendar day as AAAA-MM-DD, or "" when the text is not one. */
function cleanDay(value: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value.trim());
  if (!match) return "";
  const [, y, m, d] = match.map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  const ok = date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 &&
    date.getUTCDate() === d && y >= 2000 && y <= 2100;
  return ok ? value.trim() : "";
}

/** Drops unreadable dates and flags them, so the app asks the person. */
function normalize(reading: z.infer<typeof Reading>) {
  const doses = reading.doses
    .map((dose) => {
      const uncertain = new Set(dose.uncertain_fields);
      const applied = cleanDay(dose.applied_on);
      const due = cleanDay(dose.next_due_on);
      if (!applied) uncertain.add("applied_on");
      if (!due) uncertain.add("next_due_on");
      if (applied && due && due <= applied) uncertain.add("next_due_on");
      return {
        kind: dose.kind,
        name: dose.name.trim(),
        applied_on: applied,
        next_due_on: due,
        product: dose.product.trim(),
        lot: dose.lot.trim(),
        veterinarian: dose.veterinarian.trim(),
        uncertain_fields: [...uncertain],
      };
    })
    .filter((dose) => dose.name || dose.applied_on || dose.next_due_on);
  const weights = reading.weights
    .map((w) => ({ measured_on: cleanDay(w.measured_on), weight_kg: w.weight_kg }))
    .filter((w) => w.weight_kg > 0 && w.weight_kg <= 150);
  return {
    is_vaccine_card: reading.is_vaccine_card,
    doses,
    weights,
    issues: reading.issues.trim(),
  };
}

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function failure(status: number, code: string, message: string) {
  return json(status, { error: code, message });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return failure(405, "method_not_allowed", "Use POST.");
  }

  // Only signed-in people can spend the API budget.
  const authorization = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authorization } } },
  );
  const { data: auth, error: authError } = await supabase.auth.getUser();
  if (authError || !auth.user) {
    return failure(401, "unauthorized", "Entre na sua conta para ler a carteirinha.");
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return failure(503, "not_configured", "A leitura da carteirinha ainda não foi configurada no servidor.");
  }

  let body: z.infer<typeof Body>;
  try {
    body = Body.parse(await req.json());
  } catch {
    return failure(400, "bad_request", "Envie de 1 a 4 fotos em JPEG, PNG ou WebP.");
  }

  // One attempt that fits in the 150 s an Edge Function may run. Server-side
  // fallbacks already cover an overloaded model.
  const client = new Anthropic({ apiKey, timeout: 140_000, maxRetries: 0 });
  let response: Anthropic.Beta.BetaMessage;
  try {
    response = await client.beta.messages.create({
      model: MODEL,
      max_tokens: 16000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: {
        effort: "high",
        format: { type: "json_schema", schema: OUTPUT_SCHEMA },
      },
      system: SYSTEM,
      messages: [
        {
          role: "user",
          content: [
            ...body.images.map((image) => ({
              type: "image" as const,
              source: {
                type: "base64" as const,
                media_type: image.media_type,
                data: image.data,
              },
            })),
            {
              type: "text" as const,
              text: "Transcreva as doses e os pesos destas fotos da carteirinha.",
            },
          ],
        },
      ],
    });
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) {
      return failure(503, "busy", "Muitas leituras agora. Tente de novo em alguns minutos.");
    }
    if (error instanceof Anthropic.BadRequestError) {
      console.error("anthropic bad request", error.status);
      return failure(422, "unreadable", "Não foi possível ler esta foto. Tente outra.");
    }
    if (error instanceof Anthropic.APIError) {
      console.error("anthropic error", error.status);
      return failure(502, "upstream", "O serviço de leitura falhou. Tente de novo.");
    }
    console.error("anthropic connection error");
    return failure(502, "upstream", "O serviço de leitura não respondeu. Tente de novo.");
  }

  if (response.stop_reason === "refusal") {
    return failure(422, "refused", "Não foi possível ler esta foto. Tente outra.");
  }
  if (response.stop_reason === "max_tokens") {
    return failure(422, "too_long", "A foto tem informação demais. Fotografe uma página por vez.");
  }

  const text = response.content
    .flatMap((block) => (block.type === "text" ? [block.text] : []))
    .join("");
  let reading: z.infer<typeof Reading>;
  try {
    reading = Reading.parse(JSON.parse(text));
  } catch {
    console.error("unparseable reading");
    return failure(502, "upstream", "A leitura voltou incompleta. Tente de novo.");
  }

  // No photo content or personal data in logs: only counts.
  console.log(
    `read-vaccine-card user=${auth.user.id} images=${body.images.length} ` +
      `doses=${reading.doses.length} weights=${reading.weights.length}`,
  );
  return json(200, normalize(reading));
});
