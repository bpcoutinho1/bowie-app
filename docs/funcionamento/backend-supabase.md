# Backend no Supabase

O backend é só o Supabase: autenticação por email e duas tabelas no Postgres protegidas por Row Level Security (RLS). Não há funções de servidor nem API própria. O esquema está em `supabase/migrations/`, aplicado em ordem de data:

1. `20260930120000_pets_and_tutors.sql`: tabelas, funções e RLS.
2. `20261006120000_pet_profile.sql`: perfil do pet (tipo, raça, nascimento, peso) e o gatilho que só deixa o tutor principal excluir.
3. `20261007120000_pet_vaccines.sql`: tabela de doses de vacinas e vermífugos.

## Configuração do app

O app lê duas variáveis de compilação, passadas com `--dart-define-from-file=dart_defines.json`:

| Variável | Conteúdo |
| --- | --- |
| `SUPABASE_URL` | URL do projeto (`https://<ref>.supabase.co`). |
| `SUPABASE_ANON_KEY` | Chave pública (anon) do projeto. |

`AppConfig.problem` (`lib/core/config/app_config.dart`) recusa valores vazios, os textos de exemplo de `dart_defines.example.json`, URLs sem `https://` e chaves com caracteres inválidos, como as bolinhas (`•`) de uma chave copiada mascarada do painel. Nesses casos o app não chama o Supabase, e a tela de login explica o que corrigir.

## Tabelas

**`public.pets`**: `id uuid`, `name text` (1 a 80 caracteres sem espaços nas pontas), `species text` (`dog` ou `cat`), `breed text` (até 80), `birth_date date`, `birth_date_estimated boolean`, `weight_kg numeric(4,1)` (0,1 a 150), `updated_at timestamptz`, `deleted_at timestamptz`.

**`public.pet_vaccines`**: doses de vacinas e vermífugos (veja [saúde](saude.md)). `next_due_on` precisa ser depois de `applied_on`. O gatilho `pet_vaccines_protect_identity` impede mudar `id` e `pet_id`. RLS: qualquer tutor `accepted` do pet lê, insere e altera, e `updated_by` precisa ser o próprio usuário.

**`public.pet_tutors`**: `id uuid`, `pet_id` (referência a `pets`, com `on delete cascade`), `user_id` (referência a `auth.users`, opcional), `email` (precisa conter `@`), `role` (`owner` ou `tutor`), `status` (`pending` ou `accepted`), `updated_at`, `deleted_at`.

Restrições extras:

- `pet_tutors_one_owner_idx`: um único dono ativo por pet.
- `pet_tutors_active_email_idx`: um email aparece no máximo uma vez por pet entre os vínculos ativos (sem diferenciar maiúsculas).
- Gatilho `pet_tutors_protect_identity`: num update, `id`, `pet_id`, `email` e `role` não podem mudar.
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

## Aplicando o esquema

Rode cada arquivo de migração, em ordem, no SQL Editor do Supabase (New query → colar → Run). Cada um roda uma única vez. Novas alterações de banco devem virar um novo arquivo em `supabase/migrations/` com o prefixo `AAAAMMDDHHMMSS_`.
