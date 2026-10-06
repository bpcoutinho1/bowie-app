# Distribuir pelo TestFlight

Passo a passo para mandar o Bowie para outras pessoas testarem no iPhone. Identificador do app: **`app.bowie`**.

## 1. Conta de desenvolvedor (uma vez só)

1. Em https://developer.apple.com/programs/enroll, entre com o Apple ID (com verificação em duas etapas) e escolha **Individual / Sole Proprietor**. Custa US$ 99 por ano.
2. Espere o email "Welcome to the Apple Developer Program".

## 2. Criar o app no App Store Connect (uma vez só)

1. Em https://developer.apple.com/account/resources/identifiers, toque em **+** → **App IDs** → **App** → Bundle ID **Explicit**: `app.bowie`. Descrição: "Bowie". Em Capabilities, nada a marcar.
2. Em https://appstoreconnect.apple.com → **Apps** → **+** → **New App**:
   - Platform: iOS
   - Name: "Bowie: diário do pet" (o nome precisa ser único na loja; dá para mudar depois)
   - Primary Language: Portuguese (Brazil)
   - Bundle ID: `app.bowie`
   - SKU: `bowie-ios`
   - User Access: Full Access

## 3. Assinatura no Xcode (uma vez só)

1. `open ios/Runner.xcworkspace`
2. Runner (ícone azul) → target **Runner** → **Signing & Capabilities**.
3. **Team**: o time pago (com o seu nome, sem "Personal Team"). Deixe **Automatically manage signing** marcado.
4. Confira o **Bundle Identifier**: `app.bowie`.

## 4. Gerar e enviar um build (a cada versão)

1. No Terminal, na pasta do projeto:
   ```bash
   ./scripts/gerar-ipa.sh
   ```
   O script confere o `dart_defines.json`, usa a data e a hora como número do build (cada envio precisa de um número novo) e abre a pasta com o `.ipa`.
2. Abra o app **Transporter** (Mac App Store), entre com o Apple ID, arraste o `.ipa` e clique em **Deliver**.
3. Em 10 a 30 minutos o build aparece em **App Store Connect → Bowie → TestFlight**.

A versão que aparece para os testadores (ex.: 0.1.0) vem de `version:` no `pubspec.yaml`. Mude quando quiser marcar uma etapa.

## 5. Testadores

**Internos** (até 100, sem revisão da Apple): pessoas da sua equipe no App Store Connect. Em **Users and Access** → **+**, convide por email; depois, em **TestFlight → Internal Testing**, crie um grupo e adicione.

**Externos** (até 10 mil, por email ou link): o primeiro build passa por uma revisão rápida da Apple (cerca de 24 h).

1. **TestFlight → Test Information**:
   - Beta App Description: o que testar. Ex.: "Cadastre seu pet, registre as vacinas lendo a carteirinha, use o diário, a lista de compras e os contatos."
   - Feedback Email: o seu email.
   - Privacy Policy URL: https://github.com/bpcoutinho1/bowie-app/blob/main/docs/legal/politica-de-privacidade.md
   - Sign-In Information: email e senha de uma **conta de teste** criada no app, com um pet de exemplo. Sem isso, a Apple recusa o build.
2. **External Testing** → **+** → crie um grupo (ex.: "Amigos do Bowie"), adicione o build e envie para revisão.
3. Aprovado, convide por email ou ative o **Public Link** e mande por WhatsApp.

Quem testa instala o app **TestFlight** da App Store e abre o convite. Para dar feedback, basta tirar um print dentro do app: o TestFlight oferece enviar com um comentário, e chega em **TestFlight → Feedback**.

Cada build vale 90 dias.

## Antes de chamar outras pessoas

- Preencha o email de contato na [política de privacidade](../legal/politica-de-privacidade.md).
- Defina um limite mensal de gasto no console da Anthropic (leitura da carteirinha).
- Crie uma conta nova no app e confira se a confirmação de email do Supabase funciona.

## Ter o app no iPhone sem o Mac conectado

O app instalado pelo `flutter run` normal é de **depuração**: desde o iOS 14, ele só abre com o Mac conectado. Para mostrar para amigos sem o Mac:

- **Sem a conta paga:** instale a versão de produção pelo cabo uma vez:
  ```bash
  flutter run --release --dart-define-from-file=dart_defines.json
  ```
  Depois pode desconectar: o app abre sozinho. Com o "Personal Team" gratuito, a Apple faz o app parar de abrir **depois de 7 dias**; aí é só conectar e rodar o comando de novo (os dados não se perdem).
- **Com a conta paga:** entre como testador interno do seu próprio app no TestFlight. O app dura 90 dias por build e atualiza pelo TestFlight, sem cabo.
