# Backend no Supabase

O backend é só o Supabase: autenticação por email, tabelas no Postgres protegidas por Row Level Security (RLS) e uma Edge Function para ler a carteirinha de vacinação. O esquema está em `supabase/migrations/`, aplicado em ordem de data:

1. `20260930120000_pets_and_tutors.sql`: tabelas, funções e RLS.
2. `20261006120000_pet_profile.sql`: perfil do pet (tipo, raça, nascimento, peso) e o gatilho que só deixa o tutor principal excluir.
3. `20261007120000_pet_vaccines.sql`: tabela de doses de vacinas e vermífugos.
4. `20261008120000_pet_photo_sex_transfer.sql`: sexo e foto do pet, o bucket `pet-photos` com suas políticas e a função `transfer_pet`. Pode rodar mais de uma vez.
5. `20261009120000_shopping_items.sql`: lista de compras da casa (tabela `shopping_items` e função `is_house_member`). Pode rodar mais de uma vez.
6. `20261010120000_diary_and_contacts.sql`: diário (`pet_events`) e contatos da casa (`house_contacts`). Precisa da 5. Pode rodar mais de uma vez.
7. `20261012120000_medications.sql`: medicações (`pet_medications`) e doses dadas (`pet_medication_doses`). Pode rodar mais de uma vez.

## Configuração do app

O app lê duas variáveis de compilação, passadas com `--dart-define-from-file=dart_defines.json`:

| Variável | Conteúdo |
| --- | --- |
| `SUPABASE_URL` | URL do projeto (`https://<ref>.supabase.co`). |
| `SUPABASE_ANON_KEY` | Chave pública (anon) do projeto. |

`AppConfig.problem` (`lib/core/config/app_config.dart`) recusa valores vazios, os textos de exemplo de `dart_defines.example.json`, URLs sem `https://` e chaves com caracteres inválidos, como as bolinhas (`•`) de uma chave copiada mascarada do painel. Nesses casos o app não chama o Supabase, e a tela de login explica o que corrigir.

## Tabelas

**`public.pets`**: `id uuid`, `name text` (1 a 80 caracteres sem espaços nas pontas), `species text` (`dog` ou `cat`), `sex text` (`male` ou `female`), `photo_path text` (precisa começar com o id do pet), `breed text` (até 80), `birth_date date`, `birth_date_estimated boolean`, `weight_kg numeric(4,1)` (0,1 a 150), `updated_at timestamptz`, `deleted_at timestamptz`.

**`public.pet_vaccines`**: doses de vacinas e vermífugos (veja [saúde](saude.md)). `next_due_on` precisa ser depois de `applied_on`. O gatilho `pet_vaccines_protect_identity` impede mudar `id` e `pet_id`. RLS: qualquer tutor `accepted` do pet lê, insere e altera, e `updated_by` precisa ser o próprio usuário.

**`public.pet_tutors`**: `id uuid`, `pet_id` (referência a `pets`, com `on delete cascade`), `user_id` (referência a `auth.users`, opcional), `email` (precisa conter `@`), `role` (`owner` ou `tutor`), `status` (`pending` ou `accepted`), `updated_at`, `deleted_at`.

Restrições extras:

- `pet_tutors_one_owner_idx`: um único dono ativo por pet.
- `pet_tutors_active_email_idx`: um email aparece no máximo uma vez por pet entre os vínculos ativos (sem diferenciar maiúsculas).
- Gatilho `pet_tutors_protect_identity`: num update, `id`, `pet_id`, `email` e `role` não podem mudar. O `role` só muda dentro de `transfer_pet`.
- Gatilho `pets_protect_deletion`: só o tutor principal pode mudar `deleted_at` de um pet.

## Funções auxiliares

Rodam com `security definer` para que as políticas possam consultar `pet_tutors` sem cair em recursão de RLS.

| Função | Retorna verdadeiro quando |
| --- | --- |
| `is_accepted_member(pet)` | O usuário atual tem vínculo `accepted` e ativo no pet. |
| `is_pet_owner(pet)` | O usuário atual é o dono `accepted` e ativo do pet. |
| `pet_has_owner(pet)` | O pet já tem dono ativo. |

## Políticas de RLS

Só o papel `authenticated` acessa as tabelas. O `anon` não tem permissão nenhuma. Não há política de `delete`.

**`pets`**

| Operação | Regra |
| --- | --- |
| select | Membro `accepted`, ou existe convite `pending` para o email do JWT. |
| insert | Qualquer usuário autenticado. |
| update | Membro `accepted` (antes e depois da alteração). |

**`pet_tutors`**

| Operação | Regra |
| --- | --- |
| select | O vínculo é do usuário (`user_id`), ou é para o email dele, ou ele é membro `accepted` do pet. |
| insert | (a) Dono: `role = owner`, `status = accepted`, `user_id` do próprio usuário, email do JWT, e o pet ainda sem dono. Ou (b) convite: quem insere é o dono do pet, com `role = tutor`, `status = pending` e `user_id` vazio. |
| update | O dono do pet pode alterar qualquer vínculo. O convidado pode alterar o próprio convite `pending` só para `accepted`, preenchendo `user_id` com o próprio id, com o email do JWT e sem `deleted_at`. |

Comparações de email usam `lower(...)` dos dois lados, com o email vindo de `auth.jwt() ->> 'email'`.

## Como a criação de um pet passa pelo RLS

1. O app envia o `pet`. A política de insert de `pets` só exige estar autenticado.
2. Em seguida envia o vínculo de dono. A política (a) aceita porque o pet ainda não tem dono.
3. A partir daí o usuário é `is_accepted_member` e `is_pet_owner` desse pet.

É por isso que o push envia os pets antes dos tutores (veja [Sincronização](sincronizacao.md#um-ciclo-de-sincronização)).

**`public.shopping_items`**: itens da lista de compras de uma casa (veja [compras](compras.md)). `house_id` é o id de usuário do tutor principal. `status` é `to_buy` ou `bought`. O gatilho `shopping_items_protect_identity` impede mudar `id` e `house_id`. RLS: quem é da casa (`is_house_member`) lê, insere e altera, e `updated_by` precisa ser o próprio usuário.

`is_house_member(casa)`: verdadeiro quando a casa é do próprio usuário, ou quando ele é tutor `accepted` de um pet ativo cujo tutor principal é o dono da casa.

**`public.house_contacts`**: contatos de uma casa (veja [contatos](contatos.md)). `category` é um dos tipos fixos, `phone` só dígitos (10 ou 11). RLS igual à de `shopping_items`, com `is_house_member`.

**`public.pet_events`**: registros do diário (veja [diário](diario.md)). `kind` é `symptom`, `vet_visit`, `exam` ou `other`; `occurs_on` é o dia e `occurs_time` o horário opcional. `contact_id` aponta para `house_contacts` (vira vazio se o contato for apagado de vez). RLS igual à de `pet_vaccines`: tutores `accepted` do pet, com `updated_by` do próprio usuário.

**`public.pet_medications`** e **`public.pet_medication_doses`**: remédios e doses dadas (veja [saúde](saude.md#medicações)). RLS como em `pet_vaccines`; numa dose nova, `given_by` precisa ser o próprio usuário.

## Fotos dos pets (Storage)

Bucket privado `pet-photos`, até 5 MB por arquivo, só JPEG, PNG e WebP. Cada foto fica em `<id do pet>/<id da foto>.<extensão>`. A função `pet_of_photo(name)` tira o id do pet do caminho, e as políticas de `storage.objects` deixam ver, enviar, substituir e apagar só quem é tutor `accepted` daquele pet. Não há links públicos.

## Transferência do pet

`transfer_pet(target_pet uuid, new_owner uuid)`, chamada pelo app com `rpc`. Roda com `security definer`:

1. Só o tutor principal do pet pode chamar (erro `42501` se não for).
2. `new_owner` precisa ser um vínculo `tutor`, `accepted`, com `user_id` e ativo, do mesmo pet (erro `P0002` se não for).
3. Rebaixa o tutor principal atual a `tutor` e depois promove o novo, numa transação só, respeitando o índice de um dono por pet. Uma configuração local da transação (`bowie.transferring`) libera a troca de `role` no gatilho `pet_tutors_protect_identity`.

## Edge Function `read-vaccine-card`

`supabase/functions/read-vaccine-card/index.ts` (Deno). Recebe `POST {images: [{media_type, data}]}` com 1 a 4 fotos em base64 (JPEG, PNG ou WebP) e devolve as doses e os pesos lidos:

```json
{
  "is_vaccine_card": true,
  "doses": [{"kind": "vaccine", "name": "V10", "applied_on": "2026-05-04", "next_due_on": "2027-05-04",
             "product": "Vanguard Plus (Zoetis)", "lot": "003/25", "veterinarian": "…", "uncertain_fields": []}],
  "weights": [{"measured_on": "2026-05-04", "weight_kg": 21.4}],
  "issues": ""
}
```

- **Quem pode chamar:** só usuários logados. A função confere o token com `auth.getUser()` e responde 401 sem ele.
- **IA:** chama a API da Anthropic (modelo `claude-opus-5-5`, esforço alto) com saída estruturada por JSON Schema, para a resposta sempre ter esse formato. Com o modelo sobrecarregado, a API usa um modelo reserva automaticamente (`fallbacks: "default"`). As regras de leitura (o "Revacinar em" e não o "Venc." da etiqueta, anos com dois dígitos, linhas vazias) estão no prompt e vêm de [`docs/produto/carteirinha-de-vacinacao.md`](../produto/carteirinha-de-vacinacao.md).
- **Conferência:** a resposta é validada com zod. Datas impossíveis viram `""` e entram em `uncertain_fields`; uma próxima dose antes da aplicação também. Pesos fora de 0 a 150 kg são descartados.
- **Erros:** sempre `{error, message}`, com `message` em português para o app mostrar. 400 (pedido inválido), 401, 422 (foto ilegível ou recusada), 502 (falha da IA), 503 (sem chave configurada ou limite de uso).
- **Privacidade:** as fotos não são gravadas. O log só tem o id do usuário e contagens (fotos, doses, pesos).
- **Segredo:** `ANTHROPIC_API_KEY`, guardado em Edge Functions → Secrets. Nunca vai para o app nem para o repositório.

Para publicar ou atualizar, veja o [guia](../guias/publicar-leitura-da-carteirinha.md).

## Aplicando o esquema

Rode cada arquivo de migração, em ordem, no SQL Editor do Supabase (New query → colar → Run). Cada um roda uma única vez. Novas alterações de banco devem virar um novo arquivo em `supabase/migrations/` com o prefixo `AAAAMMDDHHMMSS_`.
