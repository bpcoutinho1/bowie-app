# Publicar a ficha compartilhada

Passo a passo para colocar no ar a ficha que os tutores compartilham com hotéis, creches e veterinários. Faça uma vez; depois, o GitHub publica sozinho. Como funciona: [ficha compartilhada](../funcionamento/ficha-compartilhada.md).

## 1. Banco

No SQL Editor do Supabase, rode `supabase/migrations/20261014120000_notes_proofs_files_shares.sql` (New query → colar → Run). Ela cria a tabela `pet_shares` e as outras mudanças desta versão. Pode rodar mais de uma vez.

## 2. Função `pet-share`

1. No painel do Supabase, **Edge Functions → Deploy a new function → Via Editor**.
2. Nome: `pet-share` (exatamente assim; a página chama por esse nome).
3. Cole todo o conteúdo de `supabase/functions/pet-share/index.ts` e clique em **Deploy function**.
4. Nos detalhes da função, **desligue "Verify JWT"** ("Enforce JWT verification"). A página é aberta por quem não tem conta no Bowie; quem protege a ficha é o código longo do link.

Não precisa criar segredo: `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` já existem em toda Edge Function.

## 3. GitHub Pages

1. No GitHub, abra o repositório **bowie-app → Settings → Pages**. Em **Source**, escolha **GitHub Actions**.
2. Em **Settings → Secrets and variables → Actions → aba Variables → New repository variable**: nome `SUPABASE_URL`, valor a URL do projeto (a mesma do `dart_defines.json`, como `https://xxxx.supabase.co`). É uma variável, não um segredo: ela aparece na página publicada.
3. Em **Actions → Ficha compartilhada (GitHub Pages) → Run workflow**, rode uma vez. Depois disso, cada mudança em `web-share/` na `main` publica sozinha.
4. Confira `https://bpcoutinho1.github.io/bowie-app/`: deve aparecer o logo do Bowie.
5. Configure o domínio `ficha.bowieapp.pet`: veja [domínio](dominio.md#ficha-em-fichabowieapppet).

## 4. Testar

1. No app, abra um pet → **Compartilhar ficha do Bowie** → escolha **Veterinário** → **Criar link**.
2. Aponte a câmera de outro celular para o QR code. A ficha deve abrir com vacinas, remédios, cuidados e o diário.
3. De volta ao app, cancele o link (o **x** em "Links ativos") e recarregue a página no outro celular: deve aparecer "Este link expirou ou foi cancelado".

| O que aparece na página | O que fazer |
| --- | --- |
| "Esta página ainda não foi configurada." | Falta a variável `SUPABASE_URL` (passo 3.2). Rode o workflow de novo depois de criar. |
| "Não foi possível abrir a ficha. Confira a internet…" com internet | A função `pet-share` não foi publicada com esse nome, ou "Verify JWT" está ligado (passo 2). |
| "Este link expirou ou foi cancelado." num link novo | Confira se a migração rodou (passo 1) e veja os logs em **Edge Functions → pet-share → Logs**. |

## Atualizar

- Página: mudanças em `web-share/` publicam sozinhas.
- Função: quando `supabase/functions/pet-share/index.ts` mudar, cole o código novo no editor da função e clique em **Deploy**.
