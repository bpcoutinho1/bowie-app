# Planos

A regra de produto está em [planos e preço](../produto/planos.md). Nada é cobrado ainda: o plano é mudado à mão no Supabase ([guia](../guias/planos.md)).

## No Supabase

**`public.account_plans`** (migração `20261019120000_account_plans.sql`), uma linha por conta:

| Coluna | Descrição |
| --- | --- |
| `user_id`, `email` | A conta. O email é copiado na criação, para a tabela ser fácil de ler no painel. |
| `plan` | `free` ou `premium`. |
| `premium_until` | Até quando vale o Premium; vazio é sem fim. |
| `trial_ends_at` | Fim do teste de 30 dias. Contas novas: 30 dias a partir da criação (gatilho `on_auth_user_created_plan` em `auth.users`). Contas anteriores à migração: 30 dias depois de criadas, então já estão no grátis. |
| `ai_photos_used`, `diary_files_used` | O que o plano grátis conta, para sempre: apagar não devolve. |

- RLS: cada pessoa só lê a própria linha. Ninguém muda o plano pelo app; só pelo painel (ou, no futuro, pelo serviço de pagamento).
- `consume_quota(kind, amount)` (`ai_photos` ou `diary_files`, de 1 a 20): soma ao contador de quem chama.

## No app

`lib/features/plans/`:

- `AccountPlan`: o nível (`free`, `trial` ou `premium`) a partir da linha. O teste conta como Premium. Limites: 1 pet no grátis e 5 no Premium; 3 fotos lidas pela IA e 10 envios ao diário no grátis.
- `PlanRepository.current` lê a linha a cada verificação e guarda a última no celular. Sem internet, usa a guardada; sem nenhuma, `AccountPlan.unknown`, que não bloqueia nada. Se o servidor responde mas a conta não tem linha, ela fica no grátis (o padrão).
- Atenção: a coluna `plan` diz `free` também durante o teste de 30 dias. Quem está no teste tem o Premium até `trial_ends_at`.
- `ensureCanAddPet` (todos os botões de novo pet e o salvar do formulário): conta os pets em que a pessoa é tutor principal; os pets em que ela é convidada não contam.
- `ensureQuota`: antes de enviar fotos para a leitura da carteirinha e antes de salvar um registro do diário com fotos ou PDFs novos (os que já estavam no registro não contam). `consumeQuota` soma depois que deu certo.
- No limite, `showPremiumSheet` abre "Bowie Premium" com o motivo, o que o Premium dá e o preço. O botão "Mudar para Premium" abre no navegador a página de assinatura fora das lojas, definida em `PREMIUM_URL` no `dart_defines.json`. Sem ela, o botão diz "Assinatura em breve".
- "Minha conta" mostra sempre o plano no topo, em "Conta": Grátis (com quanto de cada limite já foi usado), Teste grátis do Premium (com "Acaba em" e a data) ou Premium. Se o plano não pôde ser lido, diz isso e oferece "Tentar de novo". Fora do Premium pago, o botão "Mudar para Premium" abre "Bowie Premium".

Os limites são conferidos no app. Antes de cobrar, a conferência precisa ir também para o servidor (a função `read-vaccine-card` e o envio de arquivos), para não depender do app.
