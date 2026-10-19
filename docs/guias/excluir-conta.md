# Publicar a exclusão de conta

Passo a passo para ativar "Excluir minha conta", exigida pela App Store e pelo Google Play. Faça uma vez. Como funciona: [exclusão de conta](../funcionamento/autenticacao-e-navegacao.md#exclusão-de-conta). As regras: [contas e tutores](../produto/contas-e-tutores.md#exclusão-da-conta).

## 1. Banco

No SQL Editor do Supabase, rode `supabase/migrations/20261020120000_account_deletion.sql` (Copy raw file no GitHub, colar, Run). Ela cria a função `delete_account` e ajusta as tabelas para que os registros que a pessoa fez nos pets de outros tutores fiquem no histórico, sem o nome dela. Pode rodar mais de uma vez.

## 2. Função `delete-account`

1. No painel do Supabase, **Edge Functions → Deploy a new function → Via Editor**.
2. Nome: `delete-account` (exatamente assim; o app chama por esse nome).
3. Cole todo o conteúdo de `supabase/functions/delete-account/index.ts` e clique em **Deploy function**.
4. Deixe **"Verify JWT" ligado**: só quem está logado pode excluir a própria conta.

Não precisa criar segredo: `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` já existem em toda Edge Function.

## 3. Testar

Use uma conta de teste, nunca a sua: a exclusão não tem volta.

1. Crie uma conta nova no app, cadastre um pet e, se quiser, convide outra conta de teste e aceite o convite.
2. **Minha conta → Excluir minha conta**. A tela mostra o que será apagado e, para pets com outros tutores, quem fica com cada um.
3. Marque a confirmação e toque em **Excluir minha conta**. O app volta para a tela de entrada com "Sua conta foi excluída."
4. No Supabase, **Authentication → Users**: a conta não aparece mais. Em **Table Editor → pets**, o pet que era só dela também sumiu; o pet transferido continua, com o novo tutor principal.

Se aparecer "A exclusão da conta ainda não foi configurada no servidor", a função não foi publicada com o nome `delete-account`.
