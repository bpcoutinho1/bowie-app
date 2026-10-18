# Domínio bowieapp.pet

O domínio `bowieapp.pet` foi comprado no Hostinger, com o email `contato@bowieapp.pet` (18 de outubro de 2026).

## Divisão

| Endereço | O que fica lá | Onde é hospedado |
| --- | --- | --- |
| `bowieapp.pet` | Landing page | Projeto separado do fundador |
| `ficha.bowieapp.pet` | Ficha compartilhada (`web-share/`) | GitHub Pages, deste repositório |
| `contato@bowieapp.pet` | Contato e remetente dos emails da conta | Email do Hostinger |

O subdomínio deixa os dois projetos independentes: publicar a landing não quebra as fichas, e vice-versa.

## Ficha em ficha.bowieapp.pet

Faça na ordem. O app novo já gera links com `ficha.bowieapp.pet`, então configure isto antes de instalar a versão nova no iPhone.

1. **DNS no Hostinger:** no hPanel, abra **Domínios → bowieapp.pet → DNS / Nameservers** e adicione um registro:

   | Tipo | Nome | Aponta para | TTL |
   | --- | --- | --- | --- |
   | CNAME | `ficha` | `bpcoutinho1.github.io` | o padrão |

   Não mexa nos registros de `@` e `www` (são da landing) nem nos de email (MX, SPF, DKIM, DMARC).
2. **GitHub Pages:** no repositório, **Settings → Pages → Custom domain**, digite `ficha.bowieapp.pet` e clique em **Save**. O GitHub confere o DNS; pode levar de alguns minutos a algumas horas.
3. **HTTPS:** quando o GitHub liberar, marque **Enforce HTTPS** na mesma tela.
4. **Verificar o domínio (recomendado):** na sua conta do GitHub (não no repositório), **Settings → Pages → Add a domain**, digite `bowieapp.pet` e crie no Hostinger o registro TXT que o GitHub mostrar. Isso impede que outra conta use um subdomínio seu no GitHub Pages.
5. **Testar:** abra `https://ficha.bowieapp.pet`. Deve aparecer o logo do Bowie. Depois, crie um link novo no app e abra pelo QR code.

Os links antigos (`bpcoutinho1.github.io/bowie-app/ficha/...`) continuam abrindo: o GitHub os redireciona para o domínio novo.

## Emails

Veja [emails da conta](emails.md): SMTP do Hostinger no Supabase e os modelos em português.

## App

- O endereço da ficha (`shareBaseUrl`, em `lib/features/share/domain/pet_share.dart`) é `https://ficha.bowieapp.pet/`. Dá para trocar sem mudar o código com `--dart-define=SHARE_BASE_URL=...`.
- O identificador do app nas lojas continua `app.bowie`: ele não precisa ser igual ao domínio.
