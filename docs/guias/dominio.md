# Domínio bowie.app

Plano combinado com o fundador em 12 de outubro de 2026. O domínio não é pré-requisito para testar o app: até ele existir, a ficha compartilhada fica em `bpcoutinho1.github.io/bowie-app/ficha/` (veja [publicar a ficha](ficha-compartilhada.md)).

## Divisão

| Endereço | O que fica lá | Onde é hospedado |
| --- | --- | --- |
| `bowie.app` | Landing page | Projeto separado do fundador |
| `ficha.bowie.app` | Ficha compartilhada (`web-share/`) | GitHub Pages, deste repositório |

O subdomínio deixa os dois projetos independentes: publicar a landing não quebra as fichas, e vice-versa.

## Passo a passo, quando o domínio estiver registrado

1. **DNS da ficha:** no painel de quem vendeu o domínio, crie um registro `CNAME` com nome `ficha` e valor `bpcoutinho1.github.io`.
2. **GitHub Pages:** em Settings → Pages → Custom domain, coloque `ficha.bowie.app`, salve e marque **Enforce HTTPS** quando o GitHub liberar.
3. **Esperar o certificado:** todo domínio `.app` só abre com HTTPS. O GitHub gera o certificado sozinho; leva de alguns minutos a uma hora depois do DNS.
4. **App:** o endereço da ficha (`shareBaseUrl`, em `lib/features/share/domain/pet_share.dart`, ou `--dart-define=SHARE_BASE_URL=...`) passa a ser `https://ficha.bowie.app/`. Os QR codes novos já saem com o domínio. Os links antigos do GitHub Pages param de funcionar quando o domínio próprio é configurado no Pages; quem precisar gera um link novo.
5. **Emails:** configure um SMTP próprio no Supabase (Authentication → Emails → SMTP Settings), com remetente como `nao-responda@bowie.app`. O remetente padrão do Supabase tem limite baixo de envios por hora e cai no spam com facilidade. Isso afeta a confirmação de conta e a recuperação de senha.
6. **Textos:** atualize a política de privacidade e os documentos que citam o endereço da ficha.

Para os passos 1 e 5, informe onde o domínio foi comprado (Cloudflare, Squarespace, GoDaddy, Registro.br etc.): os nomes dos campos mudam de um painel para outro.
