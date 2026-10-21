# Ligar as assinaturas (App Store e RevenueCat)

Passo a passo para o botão "Assinar" do Bowie Premium cobrar pela App Store. Faça uma vez. Como funciona: [planos](../funcionamento/planos.md#assinatura-pelas-lojas). O Google Play fica para quando o app for para o Android.

Os nomes que o código espera, escritos exatamente assim:

| O quê | Valor |
| --- | --- |
| Produtos na App Store | `bowie.premium.monthly` (mensal) e `bowie.premium.yearly` (anual) |
| Entitlement no RevenueCat | `premium` |
| Offering no RevenueCat | a marcada como **Current**, com os pacotes **Monthly** e **Annual** |
| Função no Supabase | `revenuecat-webhook` |

## 1. App Store Connect

1. **Contrato:** em https://appstoreconnect.apple.com/agreements, o **Paid Apps Agreement** precisa estar **Active**, com os dados bancários e fiscais (pessoa física no Brasil: formulário W-8BEN). Sem ele, a loja não mostra os produtos, nem nos testes.
2. **Produtos:** em Apps → Bowie → **Subscriptions**, no grupo "Bowie Premium", confira os dois produtos. Cada um precisa de preço, nome de exibição e descrição em português, e de uma imagem de revisão (um print da tela "Bowie Premium"). O status deve ficar **Ready to Submit**.
3. **Chave para o RevenueCat:** em **Users and Access → Integrations → In-App Purchase**, clique em **+** e dê o nome "RevenueCat". Baixe o arquivo `.p8` (ele só pode ser baixado uma vez) e anote o **Key ID** e o **Issuer ID**, que aparece no topo da página.

## 2. RevenueCat

1. Em https://app.revenuecat.com, crie o projeto "Bowie" e adicione um app **App Store**:
   - Bundle ID: `app.bowie`
   - **In-App Purchase Key:** envie o `.p8` e preencha o Key ID e o Issuer ID do passo anterior.
2. **Products:** importe `bowie.premium.monthly` e `bowie.premium.yearly`.
3. **Entitlements:** crie `premium` e anexe os dois produtos.
4. **Offerings:** a offering `default` (marcada como Current) com dois pacotes: **Monthly** (`$rc_monthly`) com o produto mensal e **Annual** (`$rc_annual`) com o anual.
5. **Chaves:** em **API keys**:
   - a **chave pública da Apple** (começa com `appl_`) vai para o app, no passo 4;
   - crie uma **Secret API key** (começa com `sk_`), com permissão de leitura de clientes. Ela vai só para o Supabase, no passo 3. Nunca coloque essa chave no app, no repositório ou numa conversa.

## 3. Supabase

1. **Banco:** no SQL Editor, rode `supabase/migrations/20261021120000_store_subscriptions.sql` (Copy raw file no GitHub, colar, Run). Pode rodar mais de uma vez.
2. **Segredos:** em **Edge Functions → Secrets**, adicione:
   - `REVENUECAT_SECRET_API_KEY`: a chave `sk_...` do RevenueCat;
   - `REVENUECAT_WEBHOOK_SECRET`: uma senha longa que você inventa (por exemplo, gerada com `openssl rand -hex 32` no Terminal). Guarde-a para o passo 3.4.
3. **Função:** em **Edge Functions → Deploy a new function → Via Editor**, com o nome `revenuecat-webhook`. Cole todo o conteúdo de `supabase/functions/revenuecat-webhook/index.ts` e clique em **Deploy**. Nos detalhes da função, **desligue "Verify JWT"**: quem chama é o RevenueCat, que se identifica com a senha do passo anterior.
4. **Aviso no RevenueCat:** em **Integrations → Webhooks → Add**:
   - URL: `https://SEU_PROJETO.supabase.co/functions/v1/revenuecat-webhook` (a mesma URL do `SUPABASE_URL`, com `/functions/v1/revenuecat-webhook` no fim);
   - Authorization header: `Bearer ` seguido da senha `REVENUECAT_WEBHOOK_SECRET` (com o espaço depois de Bearer);
   - Environment: **Both** (produção e sandbox, para os testes funcionarem).
   - Salve e clique em **Send test event**: deve voltar 200.

## 4. App

1. No `dart_defines.json` (no Mac, fora do Git), acrescente a chave pública:
   ```json
   "REVENUECAT_IOS_KEY": "appl_..."
   ```
2. No Xcode, em Runner → **Signing & Capabilities**, confira se o **Team** é o pago (o seu nome, sem "Personal Team"): o time gratuito não permite compras dentro do app. A compra já vem ligada em todo app da conta paga; se **In-App Purchase** não aparecer em **+ Capability**, não precisa adicionar.
3. Gere o build como sempre ([TestFlight](testflight.md) ou [Xcode](rodar-no-iphone.md#atualizar-para-uma-versão-nova)).

Sem a chave no `dart_defines.json`, o app continua funcionando e a tela do Premium mostra "Assinatura em breve".

## 5. Testar sem pagar

A Apple não cobra nas compras feitas pelo Xcode nem pelo TestFlight: elas usam o **Sandbox**.

1. No App Store Connect, em **Users and Access → Sandbox → Test Accounts**, crie uma conta de teste com um email que você não usa na Apple (por exemplo, `teste1@bowieapp.pet`).
2. No iPhone, em **Ajustes → App Store → Conta Sandbox** (aparece depois de rodar um app de desenvolvimento), entre com essa conta.
3. No Bowie, com uma conta em que o teste grátis já acabou ([guia](planos.md)), toque em **Mudar para Premium** e assine.
4. "Minha conta" deve mostrar "Conta: Premium" e "Gerenciar assinatura". No Supabase, a linha da conta em `account_plans` ganha `store_premium_until`.
5. No Sandbox, a assinatura mensal renova a cada 5 minutos e para sozinha depois de algumas renovações. Quando ela acaba, a conta volta para o grátis.

Se a tela mostrar "A assinatura ainda não está disponível", confira o contrato (passo 1.1), os nomes dos produtos e a offering marcada como Current.
