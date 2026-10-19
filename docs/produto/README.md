# Produto

Esta seção descreve o que o Bowie **deve** fazer: visão, regras de negócio e prioridades. É a referência para decidir o que construir. O que o código faz **hoje** fica em [`../funcionamento/`](../funcionamento/).

Quem decide o conteúdo desta seção é o Bruno Coutinho, fundador do produto. A primeira versão foi escrita a partir das respostas dele, em 1º de outubro de 2026.

## Documentos

1. [Visão](visao.md): por que o app existe, para quem, plataformas e modelo de negócio.
2. [Navegação](navegacao.md): as abas e a tela inicial.
3. [Lançamento](lancamento.md): contas nas lojas, Supabase, domínio e o que falta para os testes.
4. [Contas e tutores](contas-e-tutores.md): cadastro do usuário, tutor principal, convites, remoção e transferência.
5. [Pets](pets.md): cadastro do pet e lista de raças sugeridas.
6. [Saúde](saude.md): vacinas, vermífugos e medicamentos.
6a. [Diário](diario.md): sintomas, consultas e exames, com calendário e agendamentos.
6b. [Contatos](contatos.md): a agenda de profissionais e lugares da casa.
7. [Lista de compras](compras.md): a lista compartilhada, no estilo do app Bring.
8. [Leitura da carteirinha](carteirinha-de-vacinacao.md): como o app lê a foto da carteirinha, com o exemplo do Bowie.
9. [Notificações](notificacoes.md): a central de notificações (sino), convites e avisos entre tutores.
8a. [Primeiro uso](primeiro-uso.md): o caminho guiado para cadastrar o pet e as vacinas, e a ficha no Início.
8b. [Planos e preço](planos.md): grátis e Premium, teste de 30 dias, quem paga.
9a. [Ficha compartilhada](ficha-compartilhada.md): link e QR code com a ficha do pet para hotéis, creches e veterinários.
9b. [Bowie Biz](bowie-biz.md): a parte para os prestadores, começando por um painel web.
10. [Dados, sincronização e privacidade](dados-e-privacidade.md): uso sem internet, sincronização entre tutores e LGPD.
11. [Questões em aberto](questoes-em-aberto.md): o que ainda precisa de decisão.

## Prioridade do MVP

| # | Área | Situação no código |
| --- | --- | --- |
| 0 | Base: Android, tema e marca, textos em português | Concluído: Android, ícone e splash, tema claro e escuro a partir dos tokens, Figtree, textos em português e as quatro abas com o sino. Falta testar num aparelho Android. |
| 1 | Cadastro do usuário (nome, email, celular) | Concluído: nome, celular (validado como celular com DDD), email e senha, e "Minha conta" para editar. Contas antigas veem "Complete o seu cadastro" no Início. Confirmação da conta e senha nova por código no email. Exclusão da conta pelo app. Login com Google e Apple adiado. |
| 2 | Cadastro do pet (nome, nascimento, tipo, sexo, raça, peso, foto) | Parcial: nome, tipo, sexo, raça com sugestões, nascimento (ou idade aproximada), peso atual, foto (câmera ou galeria, translúcida nos cards de escolha do pet) e exclusão pelo tutor principal. Falta o histórico de peso. |
| 2a | Tutores (convite, remoção, transferência) | Parcial: convite, aceite e transferência ("Transformar em tutor principal"). Falta remoção e saída. |
| 3 | Vacinas e vermífugos | Parcial: registro manual, histórico, status, edição/exclusão e leitura da carteirinha por foto (IA na nuvem, com revisão antes de salvar). Inclui o comprovante (até 2 fotos, recomendado, com selo "Com comprovante"/"Sem comprovante"; a leitura da carteirinha guarda a página como comprovante) e "Importante sobre o pet" (cuidados especiais, alergias e alimentação). Lembrete no celular 7 dias antes do vencimento. Falta o histórico de peso. |
| 4 | Medicamentos | Parcial: cadastro (quantidade e unidade, concentração, frequência, períodos com horário, início, fim ou uso contínuo), "Remédios de hoje" com marcação de dose dada (quem e quando) e resumo no Início. Falta o lembrete por push e a repetição em 30 minutos. |
| 5 | Diário (antes "histórico de incidentes") | Parcial: sintomas, consultas, exames e outros, com calendário, agendamentos, contato ligado ao registro e o próximo agendamento no Início. Inclui fotos nos registros (até 4, com miniatura e tela cheia) e PDFs (até 5, abrem no celular). Falta lembrete por push e aviso na central. |
| 5b | Contatos | Concluído: agenda por casa, por tipo, com ligar, WhatsApp, email e mapa. |
| 5a | Central de notificações | Parcial: lembretes no celular (vacina e aniversário, 7 dias antes). Falta a central (sino) e os avisos entre tutores, necessários para os convites de quem já tem conta. |
| 5d | Primeiro uso | Concluído: caminho guiado (pet, vacinas, avisos e extras) e "Ficha do Bowie: 2 de 4" no Início. |
| 5c | Ficha compartilhada | Concluído: link e QR code por pet, para hotel ou creche e para veterinário (com o diário e os PDFs), válido por 60 dias, cancelável, com os dados sempre atuais. Página no GitHub Pages enquanto não há domínio. |
| 6 | Lista de compras | Parcial: lista por casa com "A comprar" e "Itens frequentes", catálogo com ícones, seletor de casa e sincronização. Feita antes de medicamentos e incidentes, por decisão do fundador (9 de outubro de 2026). Falta o aviso na central de notificações e a atualização em tempo real. |

Atualize a coluna "Situação no código" sempre que uma área avançar.

## Vocabulário

| Termo | Significado |
| --- | --- |
| Tutor principal | Quem cadastrou o pet, ou quem o recebeu por transferência. No código atual aparece como `owner`. |
| Tutor | Pessoa convidada pelo tutor principal que aceitou o convite. |
| Convite | Pedido do tutor principal para alguém, identificado pelo email, cuidar do pet. |
| Pet | Cão ou gato cadastrado no app. |
