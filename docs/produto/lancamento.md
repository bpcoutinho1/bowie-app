# Lançamento

O que precisa existir para os primeiros testes com outras pessoas e, depois, para a publicação.

| Item | Situação | Observação |
| --- | --- | --- |
| Conta Apple Developer | Ativa (Individual), em conversão | US$ 99 por ano. Hoje a loja mostra o nome do Bruno como desenvolvedor. A conversão para Organização, em nome da Arca Lab (CNPJ e D-U-N-S), foi pedida à Apple em 22 de outubro de 2026. **O app só é publicado na App Store depois da conversão**; até lá, só TestFlight. Depois dela: aceitar de novo o Paid Apps Agreement, cadastrar banco e dados fiscais da empresa, fazer o cadastro de pessoa jurídica na StoneX, conferir o Small Business Program e trocar o controlador dos dados na política de privacidade e nos termos. |
| Conta Google Play Console | Pendente | US$ 25, pagamento único. Necessária para o teste interno e para o Google Play. |
| Projeto no Supabase | Criado | Conferir a **região do servidor** (veja abaixo). |
| Domínio | Comprado | `bowieapp.pet`, no Hostinger: landing page no domínio principal e a ficha compartilhada em `ficha.bowieapp.pet`. Passo a passo em [domínio](../guias/dominio.md). |
| Página web | Parcial | Política de privacidade em https://bowieapp.pet/privacidade/ e termos de uso em https://bowieapp.pet/termos/ (o app abre os dois na tela do Premium). Falta a página do link de convite, com os botões das lojas. |
| Email de envio | Pronto para configurar | `contato@bowieapp.pet` (Hostinger) como remetente dos emails da conta, pelo SMTP do Supabase. Passo a passo em [emails da conta](../guias/emails.md). |

## Região do Supabase

A região é o lugar onde fica o servidor do banco, e não o fuso horário. O ideal é São Paulo (`sa-east-1`): o app responde mais rápido no Brasil e os dados ficam no país, o que simplifica a LGPD. Para conferir: painel do Supabase → Project Settings → General → Region. A região não muda depois de criado o projeto. Se estiver em outra, o mais simples é criar um projeto novo enquanto ainda não há dados.

O fuso horário não depende do servidor: o app grava datas em UTC e mostra no horário do celular. Os lembretes tocam no horário local de quem recebe.

## Antes dos testes com outras pessoas

- Contas nas lojas criadas.
- Política de privacidade publicada. As lojas exigem o link antes de liberar qualquer teste externo. Passo a passo do TestFlight em [`docs/guias/testflight.md`](../guias/testflight.md).
- Envio de email configurado, para os convites funcionarem.
