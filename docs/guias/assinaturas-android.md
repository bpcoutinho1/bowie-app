# Ligar as assinaturas no Android (Google Play e RevenueCat)

Passo a passo para o botão "Assinar" do Bowie Premium cobrar pelo Google Play. É o mesmo caminho do [iPhone](assinaturas.md), com o Google Play no lugar da App Store. Faça uma vez, na ordem: primeiro o teste, depois a produção.

**O código do app já está pronto.** Falta configurar o Google Play e o RevenueCat e pôr a chave pública do Android no `dart_defines.json`. A função `revenuecat-webhook` do Supabase serve aos dois sistemas: não muda nada nela.

Os nomes que o código e o RevenueCat esperam, escritos exatamente assim:

| O quê | Valor |
| --- | --- |
| Pacote do app | `app.bowie` |
| Assinaturas no Google Play | `bowie.premium.monthly` (plano base `monthly`) e `bowie.premium.yearly` (plano base `yearly`), os mesmos nomes da App Store |
| Entitlement no RevenueCat | `premium` (o mesmo do iPhone) |
| Offering no RevenueCat | a `default`, marcada como **Current**, com os pacotes **Monthly** e **Annual** (os mesmos do iPhone) |
| Chave no app | `REVENUECAT_ANDROID_KEY` no `dart_defines.json`, começa com `goog_` |

Os nomes dos menus da Play Console e do Google Cloud mudam de tempos em tempos. Se algum não bater, procure pela busca no topo da página.

## 1. Perfil de pagamentos (uma vez só)

Sem ele, a Play Console não deixa criar assinaturas.

1. Na Play Console, vá em **Configuração → Perfil de pagamentos** (ou no ícone de engrenagem, **Configurações da conta de desenvolvedor → Perfil de pagamentos**).
2. Crie o perfil como **empresa**, com os dados da **Arca Lab** (CNPJ, endereço) e a **conta bancária da empresa no Brasil**.
3. A Google paga em reais, direto na conta bancária, uma vez por mês. Não passa pela StoneX, que é só da Apple.
4. Nas assinaturas, a Google fica com 15% do valor. Confira a taxa atual na Central de Ajuda do Google Play.

## 2. Criar as assinaturas no Google Play

O app já foi enviado com a biblioteca de compras do Google, condição para a Play Console liberar esta parte.

1. Play Console → **Bowie** → **Monetizar com o Google Play → Produtos → Assinaturas** → **Criar assinatura**.
2. **Assinatura mensal:**
   - **ID do produto:** `bowie.premium.monthly`. Não pode ser mudado depois.
   - **Nome:** Bowie Premium (mensal)
   - **Benefícios** (aparecem na tela de compra do Google): "Até 10 pets", "Leitura da carteirinha por IA", "Fotos e PDFs no diário sem limite".
   - Em **Planos básicos e ofertas**, clique em **Adicionar plano básico**:
     - **ID do plano básico:** `monthly`
     - **Tipo:** Renovação automática
     - **Período de faturamento:** 1 mês
     - **Período de carência** e **suspensão da conta**: pode deixar o padrão.
     - **Preços:** em **Definir preços**, coloque **R$ 9,90** no Brasil. Para vender só no Brasil por enquanto, deixe só o Brasil disponível.
     - Salve e clique em **Ativar** no plano básico.
3. **Assinatura anual:** repita com:
   - **ID do produto:** `bowie.premium.yearly`
   - **Nome:** Bowie Premium (anual)
   - **ID do plano básico:** `yearly`, renovação automática, **1 ano**, **R$ 99,90**. Ative.
4. Os dois planos básicos devem aparecer como **Ativos**.

## 3. Dar ao RevenueCat acesso ao Google Play

O RevenueCat confere cada compra direto com a Google. Para isso, ele usa uma "conta de serviço" do Google Cloud, uma espécie de usuário técnico.

**3.1 No Google Cloud**

1. Abra https://console.cloud.google.com com a mesma conta Google da Play Console e crie um projeto, por exemplo "Bowie Play".
2. Em **APIs e serviços → Biblioteca**, ative estas duas APIs:
   - **Google Play Android Developer API**
   - **Google Play Developer Reporting API**
3. Em **IAM e administrador → Contas de serviço → Criar conta de serviço**:
   - Nome: `revenuecat`
   - Papéis: **Editor do Pub/Sub** (Pub/Sub Editor) e **Leitor do Monitoring** (Monitoring Viewer).
   - Concluir.
4. Clique na conta criada → aba **Chaves** → **Adicionar chave → Criar nova chave → JSON**. O arquivo `.json` é baixado.

**Esse arquivo é uma credencial.** Guarde num lugar seguro. Não coloque no repositório, no app nem mande em conversas, inclusive aqui. Ele vai só para o RevenueCat.

**3.2 Na Play Console**

1. Copie o **email da conta de serviço** (algo como `revenuecat@bowie-play.iam.gserviceaccount.com`).
2. Play Console → **Usuários e permissões → Convidar novos usuários**.
3. Cole o email e, em **Permissões do app**, adicione o **Bowie** com:
   - Ver informações do app e fazer o download de relatórios em massa (somente leitura)
   - Ver dados financeiros, pedidos e respostas da pesquisa de cancelamento
   - Gerenciar pedidos e assinaturas
4. **Convidar usuário** → **Enviar convite**.

## 4. RevenueCat

1. Em https://app.revenuecat.com, abra o projeto **Bowie** (o mesmo do iPhone) → **Apps** (ou **Project settings → Apps**) → **+ New** → **Google Play Store**:
   - **App name:** Bowie (Android)
   - **Google Play package:** `app.bowie`
   - **Service Account credentials JSON:** envie o arquivo `.json` do passo 3.1.
   - Salve.
2. A Google pode levar **até 36 horas** para liberar a conta de serviço. Se o RevenueCat mostrar "credentials need attention", espere e confira depois.
3. **Avisos em tempo real (recomendado):** na tela do app Android no RevenueCat, procure **Google developer notifications** e conecte ao Google. O RevenueCat cria um tópico do Pub/Sub e mostra o nome dele (algo como `projects/bowie-play/topics/...`). Copie esse nome e cole na Play Console, em **Monetizar com o Google Play → Configuração da monetização → Notificações do desenvolvedor em tempo real → Nome do tópico**. Salve e clique em **Enviar notificação de teste**: o RevenueCat deve mostrar que recebeu.
4. **Products:** importe as duas assinaturas do Google Play. Elas aparecem como `bowie.premium.monthly:monthly` e `bowie.premium.yearly:yearly`.
5. **Entitlements:** abra o `premium` e anexe os dois produtos do Android. Os da Apple continuam lá.
6. **Offerings:** na `default`, edite os pacotes:
   - **Monthly** (`$rc_monthly`): acrescente `bowie.premium.monthly:monthly` ao lado do produto da Apple;
   - **Annual** (`$rc_annual`): acrescente `bowie.premium.yearly:yearly`.
7. **Chave pública:** em **API keys**, copie a chave do app Android (começa com `goog_`). Ela é pública e pode ir no app, como a `appl_` do iPhone.
8. **Webhook:** em **Integrations → Webhooks**, abra o webhook do Supabase que já existe e confira que ele vale para **todos os apps** do projeto (sem filtro só para o iPhone) e para o ambiente **Both**. Não precisa criar outro.

## 5. App

1. No `dart_defines.json` (no Mac, fora do Git), preencha a chave do Android:
   ```json
   "REVENUECAT_ANDROID_KEY": "goog_..."
   ```
   Confira o arquivo com `python3 -m json.tool dart_defines.json`: se aparecer o conteúdo, está válido.
2. Gere o pacote:
   ```bash
   cd /Users/brunocoutinho/Documents/bowie-app
   ./scripts/gerar-aab.sh
   ```

Sem a chave, o app continua funcionando e a tela do Premium mostra "Assinatura em breve".

## 6. Testar sem pagar

O Google não cobra de quem está na lista de **teste de licença**.

1. Play Console → **Configuração → Teste de licença** (na página inicial da conta, fora do app): adicione os emails (contas Google) de quem vai testar compras, comece pelo seu, e deixe a resposta como **RESPOND_NORMALLY**. Salve.
2. Envie o pacote do passo 5 para o **teste fechado**: **Testar e lançar → Testes → Teste fechado → Criar nova versão**, arraste o `.aab`, **Avançar → Salvar e publicar**.
3. No celular Android, com a conta do teste de licença, atualize o Bowie pela Play Store.
4. Entre numa conta do Bowie que esteja no plano grátis, toque em **Mudar para Premium** e assine. A tela de pagamento do Google mostra um **cartão de teste** ("Cartão de teste, sempre aprova"). Escolha esse.
5. Confira:
   - "Premium ativo. Obrigado por apoiar o Bowie." e, em Minha conta, "Conta: Premium" e "Gerenciar assinatura";
   - no Supabase, em `account_plans`, a linha da conta ganha `store_premium_until` e `store_product`;
   - no RevenueCat, em **Customers**, a compra aparece com o id da conta.
6. Nos testes, a assinatura mensal renova a cada 5 minutos e para sozinha depois de algumas renovações. Quando acaba, a conta volta para o plano grátis.
7. Teste também **Restaurar compras**: desinstale e instale o app, entre na mesma conta e toque em "Restaurar compras".
8. Teste o **cancelamento**: Minha conta → **Gerenciar assinatura** abre as assinaturas do Google Play. Cancele e confira que o Premium vale até o fim do período.

Se a tela mostrar "A assinatura ainda não está disponível":

- os planos básicos estão ativos (passo 2)?
- os produtos estão na offering `default` (passo 4.6)?
- a chave `goog_` está no `dart_defines.json` antes de gerar o pacote?
- o app foi instalado pela Play Store (teste fechado ou interno)? Compras não funcionam em app instalado por cabo.

## 7. Produção

Com tudo testado:

1. **Página da loja e conteúdo do app:** confira em **Painel** se todas as tarefas estão concluídas. Em **Segurança dos dados**, as compras são feitas pelo Google Play: o Bowie não coleta dados de pagamento.
2. **Versão de produção:** **Testar e lançar → Produção → Criar nova versão → Adicionar da biblioteca**, escolha o mesmo pacote testado (o de código mais alto), escreva as notas da versão, **Avançar → Salvar e publicar**. Dá para usar também **Promover versão** a partir do teste fechado.
3. **Países:** em **Produção → Países/regiões**, deixe o **Brasil**.
4. **Revisão:** a Google revisa o app e as assinaturas. Na primeira vez, pode levar alguns dias. O resultado chega por email.
5. Depois de aprovado, o app aparece na Play Store para todos, com o Premium vendendo.

A partir daí, cada versão nova segue o mesmo caminho: gerar o pacote, enviar para o teste fechado, testar e promover para produção.

## Resumo do que é segredo e do que não é

| Item | Onde fica |
| --- | --- |
| Chave pública `goog_...` | `dart_defines.json` no Mac (pode ir no app) |
| Arquivo `.json` da conta de serviço | Só no RevenueCat. Guarde uma cópia em lugar seguro. |
| Chave secreta `sk_...` do RevenueCat | Só nos segredos do Supabase, como já está |
