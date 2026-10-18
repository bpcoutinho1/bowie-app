# Entrar com Google e com a Apple

O app já tem os botões "Continuar com a Apple" e "Continuar com o Google" na tela de login. Cada um só aparece depois de configurado, então o app funciona normalmente antes disso. Como funciona: [autenticação](../funcionamento/autenticacao-e-navegacao.md#entrar-com-google-ou-apple).

Nada aqui é segredo do app: os IDs de cliente do Google vão dentro do app. A única chave secreta é o "Client secret" do Google, que vai só no Supabase.

## Google

### 1. Projeto no Google Cloud

1. Em [console.cloud.google.com](https://console.cloud.google.com), crie um projeto chamado `Bowie`.
2. Em **APIs e serviços → Tela de consentimento OAuth** (ou **Google Auth Platform → Branding**):
   - nome do app: `Bowie`; email de suporte: `contato@bowieapp.pet`;
   - domínio autorizado: `bowieapp.pet` e `supabase.co`;
   - link da política de privacidade (quando estiver publicada no site);
   - público: **Externo**. Enquanto estiver em "Teste", só as contas adicionadas como testadoras conseguem entrar; publique o app para liberar a todos.
3. Em **Credenciais → Criar credenciais → ID do cliente OAuth**, crie três clientes:

   | Tipo | Nome | Preencha |
   | --- | --- | --- |
   | Aplicativo da Web | `Bowie Supabase` | Em "URIs de redirecionamento autorizados": `https://SEU-PROJETO.supabase.co/auth/v1/callback` |
   | iOS | `Bowie iOS` | ID do pacote: `app.bowie` |
   | Android | `Bowie Android` | Pacote: `app.bowie` e a impressão SHA-1 da chave de assinatura (veja abaixo) |

   Do cliente **Web**, guarde o **ID do cliente** e a **Chave secreta do cliente**. Do cliente **iOS**, guarde o **ID do cliente** e o **esquema de URL do iOS** (o ID ao contrário, começando com `com.googleusercontent.apps.`).

   SHA-1 da chave do Android: no Mac, na pasta do projeto, rode `cd android && ./gradlew signingReport` e copie o SHA1 da variante `release` (e o da `debug`, num segundo cliente Android, para testar).

### 2. Supabase

Em **Authentication → Sign In / Providers → Google**:

- ligue **Enable Sign in with Google**;
- **Client IDs**: o ID do cliente Web e o do iOS, separados por vírgula (o Web primeiro);
- **Client Secret**: a chave secreta do cliente Web;
- ligue **Skip nonce checks** (o login nativo do Google no iPhone não permite conferir o nonce);
- salve.

### 3. App

1. No `dart_defines.json` (que não vai para o git), preencha:

   ```json
   "GOOGLE_IOS_CLIENT_ID": "o ID do cliente iOS",
   "GOOGLE_WEB_CLIENT_ID": "o ID do cliente Web",
   ```

2. Em `ios/Flutter/Google.xcconfig`, troque `com.googleusercontent.apps.CONFIGURE_ME` pelo esquema de URL do iOS. Esse arquivo vai para o git; os IDs não são secretos. Se preferir, mande os dois IDs (nunca a chave secreta) e o arquivo é atualizado num PR.
3. Rode de novo `flutter build ios --config-only --dart-define-from-file=dart_defines.json` e ▶︎ no Xcode. O botão "Continuar com o Google" aparece no login.

## Apple

Só depois que o pagamento do Apple Developer Program for aprovado: com a conta gratuita, o Xcode não aceita o recurso "Sign in with Apple" e o app para de compilar.

1. No Xcode, abra `ios/Runner.xcworkspace`, clique em **Runner → TARGETS → Runner → Signing & Capabilities → + Capability** e adicione **Sign in with Apple**. Com o Team pago selecionado, o Xcode registra o recurso no identificador `app.bowie` sozinho. Faça commit do `Runner.entitlements` que o Xcode criar (ou peça para incluir num PR).
2. No Supabase, **Authentication → Sign In / Providers → Apple**: ligue **Enable Sign in with Apple** e, em **Client IDs**, coloque `app.bowie`. Para o login dentro do app não é preciso a chave secreta (Secret Key); ela só serve para o login pela web.
3. No `dart_defines.json`, mude `"SIGN_IN_WITH_APPLE": "true"`, rode o `--config-only` de novo e ▶︎ no Xcode.

A Apple exige o botão dela quando o app oferece login com Google no iPhone. Por isso os dois devem ir juntos para a App Store.

## Testar

1. No login, toque em "Continuar com o Google" (ou com a Apple) e escolha a conta.
2. O app entra direto, sem senha. No Início, aparece "Complete o seu cadastro", para o celular (o Google e a Apple não informam o celular).
3. Quem já tinha conta com o mesmo email cai na mesma conta, com os mesmos pets.
