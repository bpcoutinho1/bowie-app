# Ligar o email de convite

Passo a passo para o convite de tutor chegar por email, saindo de `no-reply@bowieapp.pet`. Quem responder o email cai em `contato@bowieapp.pet`, que fica para conversar com as pessoas. Faça uma vez. Como funciona: [pets e tutores](../funcionamento/pets-e-tutores.md#convite-por-email). As regras: [contas e tutores](../produto/contas-e-tutores.md#convite).

## 1. Banco

No SQL Editor do Supabase, rode `supabase/migrations/20261023120000_tutor_invites.sql` (Copy raw file no GitHub, colar, Run). Ela acrescenta a coluna `invited_at`, que evita reenvios seguidos. Pode rodar mais de uma vez.

## 2. Caixa de envio no Hostinger

No hPanel do Hostinger, em **Emails → bowieapp.pet → Contas de email**, crie a caixa `no-reply@bowieapp.pet` com uma senha forte. O Hostinger só envia em nome da própria caixa: por isso o envio precisa de uma caixa de verdade, e não de um apelido.

## 3. Segredos do email

Em **Edge Functions → Secrets**, adicione:

| Nome | Valor |
| --- | --- |
| `SMTP_HOST` | `smtp.hostinger.com` |
| `SMTP_PORT` | `465` |
| `SMTP_USER` | `no-reply@bowieapp.pet` |
| `SMTP_PASS` | a senha da caixa `no-reply@bowieapp.pet` |
| `REPLY_TO` | opcional: para onde vão as respostas. Sem ele, `contato@bowieapp.pet`. |
| `INVITE_URL` | opcional: onde baixar o app. Durante os testes, o link público do TestFlight; depois, a página com os botões das lojas. Sem ele, o email leva a `https://bowieapp.pet`. |

A senha fica só nos segredos do Supabase: não coloque no app, no repositório nem em conversas.

## 4. Função `send-invite`

1. Em **Edge Functions → Deploy a new function → Via Editor**, com o nome `send-invite`.
2. Cole todo o conteúdo de `supabase/functions/send-invite/index.ts` e clique em **Deploy**.
3. Deixe **"Verify JWT" ligado**: só quem está logado no app pode enviar convites.

## 5. Testar

1. No app, abra um pet, digite um email seu (diferente do da conta) em "Convidar por email" e toque em **Convidar**.
2. Deve aparecer "Convite enviado para …", e o email chega em até alguns minutos. Confira também o spam.
3. No ⋮ ao lado do convite, teste **Reenviar convite** (depois de 2 minutos) e **Cancelar convite**.

| Mensagem no app | O que fazer |
| --- | --- |
| "O envio de convites ainda não foi configurado no servidor." | Falta algum segredo SMTP (passo 3) ou a função não se chama `send-invite`. |
| "Não foi possível enviar o email agora." | Veja **Edge Functions → send-invite → Logs**. Um erro de autenticação (`EAUTH`) quer dizer senha errada no `SMTP_PASS`. |
| "O convite acabou de ser enviado…" | Espere 2 minutos para reenviar. |
