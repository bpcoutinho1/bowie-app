# Planos

A regra de produto está em [planos e preço](../produto/planos.md). Nada é cobrado ainda: o plano é mudado à mão no Supabase ([guia](../guias/planos.md)).

## No Supabase

**`public.account_plans`** (migração `20261019120000_account_plans.sql`), uma linha por conta:

| Coluna | Descrição |
| --- | --- |
| `user_id`, `email` | A conta. O email é copiado na criação, para a tabela ser fácil de ler no painel. |
| `plan` | `free` ou `premium`. |
| `premium_until` | Até quando vale o Premium; vazio é sem fim. |
| `trial_ends_at` | Fim de um teste do Premium. Contas novas nascem com o momento da criação (gatilho `on_auth_user_created_plan` em `auth.users`, padrão `now()` desde a migração `20261024120000_no_trial.sql`), ou seja, sem teste. Um teste só existe quando é dado à mão ([guia](../guias/planos.md)). |
| `ai_photos_used`, `diary_files_used` | O que o plano grátis conta, para sempre: apagar não devolve. |

- RLS: cada pessoa só lê a própria linha. Ninguém muda o plano pelo app; só pelo painel (ou, no futuro, pelo serviço de pagamento).
- `consume_quota(kind, amount)` (`ai_photos` ou `diary_files`, de 1 a 20): soma ao contador de quem chama.

## No app

`lib/features/plans/`:

- `AccountPlan`: o nível (`free`, `trial` ou `premium`) a partir da linha. O teste conta como Premium. Limites: 1 pet no grátis e 10 no Premium; 3 fotos lidas pela IA e 5 envios ao diário no grátis.
- `PlanRepository.current` lê a linha a cada verificação e guarda a última no celular. Sem internet, usa a guardada; sem nenhuma, `AccountPlan.unknown`, que não bloqueia nada. Se o servidor responde mas a conta não tem linha, ela fica no grátis (o padrão).
- Atenção: a coluna `plan` diz `free` também durante um teste dado à mão. Quem está no teste tem o Premium até `trial_ends_at`.
- `ensureCanAddPet` (todos os botões de novo pet e o salvar do formulário): conta os pets em que a pessoa é tutor principal; os pets em que ela é convidada não contam.
- `ensureQuota`: antes de enviar fotos para a leitura da carteirinha e antes de salvar um registro do diário com fotos ou PDFs novos (os que já estavam no registro não contam). `consumeQuota` soma depois que deu certo.
- No limite, `showPremiumSheet` abre "Bowie Premium" com o motivo e o que o Premium dá. Com a loja ligada, mostra "Assinar por R$ 99,90 por ano" e "Assinar por R$ 9,90 por mês" (preços vindos da loja), o aviso de renovação automática, "Restaurar compras" e os links dos termos de uso (https://bowieapp.pet/termos/) e da política de privacidade (https://bowieapp.pet/privacidade/). Sem a loja, mostra o preço fixo e "Assinatura em breve".
- "Minha conta" mostra sempre o plano no topo, em "Conta": Grátis (com quanto de cada limite já foi usado), Teste grátis do Premium (com "Acaba em" e a data) ou Premium. Se o plano não pôde ser lido, diz isso e oferece "Tentar de novo". Fora do Premium pago, o botão "Mudar para Premium" abre "Bowie Premium". Com o Premium da loja, "Gerenciar assinatura" abre as assinaturas da App Store (ou do Google Play).

Os limites são conferidos no app. Antes de cobrar, a conferência precisa ir também para o servidor (a função `read-vaccine-card` e o envio de arquivos), para não depender do app.

## Assinatura pelas lojas

A cobrança passa pela App Store (e, no futuro, pelo Google Play), por meio do RevenueCat. Configuração: [guia](../guias/assinaturas.md).

- **Produtos:** `bowie.premium.monthly` e `bowie.premium.yearly`, no entitlement `premium` do RevenueCat, na offering marcada como Current (pacotes Monthly e Annual).
- **App** (`lib/features/plans/data/store_billing.dart`): `RevenueCatBilling` usa a chave pública de `REVENUECAT_IOS_KEY` ou `REVENUECAT_ANDROID_KEY` (`dart_defines.json`). Sem a chave, `NoStoreBilling` e nada para vender. Toda chamada passa o id da conta do Supabase, que vira o id do cliente no RevenueCat: é ele que liga a compra à conta. Uma compra cancelada na tela da loja não muda nada.
- **Servidor:** a cada compra, renovação, cancelamento, expiração ou transferência, o RevenueCat chama a Edge Function `revenuecat-webhook` ([backend](backend-supabase.md#edge-function-revenuecat-webhook)), que pergunta ao RevenueCat o estado atual da conta e grava `store_premium_until` e `store_product` em `account_plans`.
- **Plano:** `AccountPlan.fromRow` conta como Premium o `plan = 'premium'` dado à mão (até `premium_until`) ou o da loja (até `store_premium_until`). Um não apaga o outro. `fromStore` indica o da loja.
- **Logo depois da compra:** o aviso do RevenueCat leva alguns segundos. Enquanto isso, `PlanRepository.current` pergunta à loja (`StoreBilling.current`, com o cache do RevenueCat) quando o servidor diz que a conta não é Premium. Assim o limite já sai na hora.

