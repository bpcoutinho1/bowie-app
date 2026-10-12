# Ativar a recuperação de senha

O app recupera a senha com um **código de 6 números enviado por email**: a pessoa digita o código e a senha nova no próprio app. Não depende de domínio nem de link que abra o app. Como funciona: [autenticação](../funcionamento/autenticacao-e-navegacao.md#recuperar-a-senha).

O email padrão do Supabase manda só um link, que não serve para o app. Por isso, troque o modelo uma vez.

## 1. Modelo do email

1. No painel do Supabase, vá em **Authentication → Emails → Templates** (em versões antigas, **Authentication → Email Templates**).
2. Abra **Reset Password**.
3. Em **Subject**, coloque:

   ```
   Seu código para criar uma senha nova no Bowie
   ```

4. Em **Body** (ou **Message body**), apague o conteúdo e cole:

   ```html
   <h2>Crie uma senha nova</h2>
   <p>Use este código no app Bowie:</p>
   <p style="font-size: 32px; font-weight: 800; letter-spacing: 6px;">{{ .Token }}</p>
   <p>O código vale por 1 hora. Se não foi você quem pediu, ignore este email: a sua senha continua a mesma.</p>
   ```

5. Clique em **Save**.

O `{{ .Token }}` é trocado pelo código. Não mude esse trecho.

## 2. Conferir o código

Em **Authentication → Sign In / Providers → Email** (ou **Providers → Email**), confira:

- **Email OTP Length:** 6. O app aceita de 6 a 10 números, mas o texto da tela fala em 6.
- **Email OTP Expiration:** 3600 segundos (1 hora), como diz o email.

## 3. Testar

1. No app, saia da conta e toque em **Esqueci minha senha**.
2. Digite o email e toque em **Enviar código**.
3. Digite o código que chegou e a senha nova, e toque em **Salvar a senha nova**. O app entra na conta (depois do Face ID).

## Limite de envios

Sem SMTP próprio, o Supabase envia poucos emails por hora para todo o projeto (confirmação de conta e recuperação de senha somados). Se aparecer "Muitas tentativas seguidas", espere alguns minutos. Com o domínio, configure um SMTP próprio (veja [domínio](dominio.md), passo 5).
