# Emails da conta

Os emails que o Bowie manda são os do Supabase: o código para confirmar a conta e o código para criar uma senha nova. Este guia faz os dois saírem de `contato@bowieapp.pet`, em português e com código (sem link). Faça uma vez, na ordem.

Por que código e não link: o link do Supabase abre uma página na web, e o app ainda não abre a partir de links. Com o código, a pessoa confirma tudo dentro do app. Como funciona: [autenticação](../funcionamento/autenticacao-e-navegacao.md#confirmar-o-email).

## 1. Conferir o email no Hostinger

1. No hPanel do Hostinger, abra **Emails** e escolha `bowieapp.pet`.
2. Procure a parte de **DNS** do email (costuma aparecer como "Status do DNS" ou "Registros DNS") e confira que **MX, SPF, DKIM e DMARC** estão marcados como configurados. Se algum não estiver, use o botão de configurar automaticamente. Sem SPF e DKIM, os emails do Bowie caem no spam.
3. Tenha à mão a senha da caixa `contato@bowieapp.pet`. Ela vai no Supabase, no passo 2, e em nenhum outro lugar: não coloque no app, no repositório nem em conversas.

## 2. SMTP no Supabase

No painel do Supabase, abra **Authentication → Emails → SMTP Settings** (em versões antigas, **Project Settings → Authentication → SMTP Settings**), ligue **Enable custom SMTP** e preencha:

| Campo | Valor |
| --- | --- |
| Sender email | `contato@bowieapp.pet` |
| Sender name | `Bowie` |
| Host | `smtp.hostinger.com` |
| Port | `465` |
| Username | `contato@bowieapp.pet` |
| Password | a senha da caixa de email |

Salve. O remetente precisa ser a mesma caixa do usuário: o Hostinger recusa enviar em nome de outro endereço. As respostas das pessoas chegam em `contato@bowieapp.pet`.

Depois, em **Authentication → Rate Limits**, confira o limite de emails por hora. Com SMTP próprio, o Supabase libera mais que o padrão; 30 por hora é um bom começo para os testes. O plano de email do Hostinger também tem um limite diário de envios: confira no hPanel.

## 3. Modelos dos emails

Em **Authentication → Emails → Templates**:

### Confirm signup

Assunto:

```
Seu código para confirmar a conta no Bowie
```

Corpo:

```html
<h2>Boas-vindas ao Bowie</h2>
<p>Use este código no app para confirmar a sua conta:</p>
<p style="font-size: 32px; font-weight: 800; letter-spacing: 6px;">{{ .Token }}</p>
<p>O código vale por 1 hora. Se não foi você quem criou a conta, ignore este email.</p>
<p>Bowie · Quem ama, lembra.</p>
```

### Reset Password

Assunto:

```
Seu código para criar uma senha nova no Bowie
```

Corpo:

```html
<h2>Crie uma senha nova</h2>
<p>Use este código no app Bowie:</p>
<p style="font-size: 32px; font-weight: 800; letter-spacing: 6px;">{{ .Token }}</p>
<p>O código vale por 1 hora. Se não foi você quem pediu, ignore este email: a sua senha continua a mesma.</p>
<p>Bowie · Quem ama, lembra.</p>
```

O `{{ .Token }}` é trocado pelo código. Não mude esse trecho. Os outros modelos (Magic Link, Change Email Address, Invite User) o app não usa.

## 4. Código e endereço do site

1. Em **Authentication → Sign In / Providers → Email**, confira:
   - **Confirm email** ligado (quem cria a conta confirma o email);
   - **Email OTP Length**: 6;
   - **Email OTP Expiration**: 3600 segundos (1 hora), como dizem os emails.
2. Em **Authentication → URL Configuration**, coloque **Site URL** `https://bowieapp.pet`. Ele só aparece em links, que os emails acima não usam, mas evita que algum email antigo aponte para `localhost`.

## 5. Testar

1. Crie uma conta nova no app com um email seu. Deve chegar "Seu código para confirmar a conta no Bowie", de `Bowie <contato@bowieapp.pet>`. Digite o código no app.
2. Saia, toque em **Esqueci minha senha** e confira o email do código de senha nova.
3. Se o email não chegar, olhe o spam e os logs em **Authentication → Logs** do Supabase. Para medir a entrega, mande um email de teste para o endereço que o [mail-tester.com](https://www.mail-tester.com) mostra: a nota deve ser 8 ou mais.
