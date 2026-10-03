# Lançamento

O que precisa existir para os primeiros testes com outras pessoas e, depois, para a publicação.

| Item | Situação | Observação |
| --- | --- | --- |
| Conta Apple Developer | Pendente | US$ 99 por ano. Necessária para o TestFlight (testes no iPhone) e para a App Store. A aprovação pode levar alguns dias. |
| Conta Google Play Console | Pendente | US$ 25, pagamento único. Necessária para o teste interno e para o Google Play. |
| Projeto no Supabase | Criado | Conferir a **região do servidor** (veja abaixo). |
| Domínio | Pendente | Sugestão: `bowie.app`. |
| Página web | Pendente | Política de privacidade, termos de uso e a página do link de convite, com os botões das lojas. |
| Email de envio | Pendente | Depende do domínio. Sem domínio próprio, os emails de convite tendem a cair no spam. |

## Região do Supabase

A região é o lugar onde fica o servidor do banco, e não o fuso horário. O ideal é São Paulo (`sa-east-1`): o app responde mais rápido no Brasil e os dados ficam no país, o que simplifica a LGPD. Para conferir: painel do Supabase → Project Settings → General → Region. A região não muda depois de criado o projeto. Se estiver em outra, o mais simples é criar um projeto novo enquanto ainda não há dados.

O fuso horário não depende do servidor: o app grava datas em UTC e mostra no horário do celular. Os lembretes tocam no horário local de quem recebe.

## Antes dos testes com outras pessoas

- Contas nas lojas criadas.
- Política de privacidade publicada. As lojas exigem o link antes de liberar qualquer teste externo.
- Envio de email configurado, para os convites funcionarem.
