# Publicar a leitura da carteirinha

Passo a passo para colocar no ar a função que lê a carteirinha de vacinação (`supabase/functions/read-vaccine-card/index.ts`). Tudo pelo painel do Supabase, sem instalar nada. O que a função faz está em [backend no Supabase](../funcionamento/backend-supabase.md#edge-function-read-vaccine-card).

## 1. Guardar a chave da Anthropic no Supabase (uma vez só)

A chave fica só no servidor. Nunca coloque a chave no app, no repositório ou numa conversa.

1. No [console da Anthropic](https://console.anthropic.com), em **API Keys**, crie uma chave (por exemplo, `bowie-supabase`) e copie.
2. No painel do Supabase, abra o projeto e vá em **Edge Functions → Secrets**.
3. Em **Add new secret**: nome `ANTHROPIC_API_KEY`, valor a chave copiada. Salve.

Sugestão: no console da Anthropic, em **Limits**, defina um limite de gasto mensal. Assim um erro ou abuso nunca passa do valor que você escolheu.

## 2. Publicar a função

1. No painel do Supabase, vá em **Edge Functions → Deploy a new function → Via Editor**.
2. Nome da função: `read-vaccine-card` (exatamente assim; o app chama por esse nome).
3. Apague o código de exemplo e cole todo o conteúdo de `supabase/functions/read-vaccine-card/index.ts`.
4. Clique em **Deploy function**.
5. Nos detalhes da função, confira que **Verify JWT** (ou "Enforce JWT verification") está ligado. Assim só quem está logado no app consegue chamar.

`SUPABASE_URL` e `SUPABASE_ANON_KEY` já existem em toda Edge Function; não precisa criar.

## 3. Testar no app

1. Rode o app no iPhone (veja [rodar no iPhone](rodar-no-iphone.md)).
2. Na aba **Saúde**, toque no ícone de leitura no topo, fotografe uma página da carteirinha e toque em **Ler a foto**.
3. Na primeira vez, o app pede consentimento para enviar a foto.

Se algo der errado, a mensagem na tela diz o motivo:

| Mensagem | O que fazer |
| --- | --- |
| "A leitura da carteirinha ainda não foi configurada no servidor." | Falta o segredo `ANTHROPIC_API_KEY` (passo 1) ou a função não foi publicada com o nome certo (passo 2). |
| "Entre na sua conta de novo…" | A sessão expirou. Saia e entre de novo. |
| "Muitas leituras agora…" | Limite de uso da Anthropic. Espere alguns minutos ou confira o limite e o saldo no console. |
| "O serviço de leitura falhou…" | Veja os logs em **Edge Functions → read-vaccine-card → Logs**. O log mostra só contagens e o código de status, nunca as fotos. |

## Atualizar a função

Quando `index.ts` mudar no repositório, abra a função no painel, cole o código novo no editor e clique em **Deploy** de novo. O segredo continua lá.
