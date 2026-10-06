# Produto

Esta seção descreve o que o Bowie **deve** fazer: visão, regras de negócio e prioridades. É a referência para decidir o que construir. O que o código faz **hoje** fica em [`../funcionamento/`](../funcionamento/).

Quem decide o conteúdo desta seção é o Bruno Coutinho, fundador do produto. A primeira versão foi escrita a partir das respostas dele, em 1º de outubro de 2026.

## Documentos

1. [Visão](visao.md): por que o app existe, para quem, plataformas e modelo de negócio.
2. [Navegação](navegacao.md): as abas e a tela inicial.
3. [Lançamento](lancamento.md): contas nas lojas, Supabase, domínio e o que falta para os testes.
4. [Contas e tutores](contas-e-tutores.md): cadastro do usuário, tutor principal, convites, remoção e transferência.
5. [Pets](pets.md): cadastro do pet e lista de raças sugeridas.
6. [Saúde](saude.md): vacinas, vermífugos, medicamentos e incidentes.
7. [Lista de compras](compras.md): a lista compartilhada, no estilo do app Bring.
8. [Leitura da carteirinha](carteirinha-de-vacinacao.md): como o app lê a foto da carteirinha, com o exemplo do Bowie.
9. [Notificações](notificacoes.md): a central de notificações (sino), convites e avisos entre tutores.
10. [Dados, sincronização e privacidade](dados-e-privacidade.md): uso sem internet, sincronização entre tutores e LGPD.
11. [Questões em aberto](questoes-em-aberto.md): o que ainda precisa de decisão.

## Prioridade do MVP

| # | Área | Situação no código |
| --- | --- | --- |
| 0 | Base: Android, tema e marca, textos em português | Concluído: Android, ícone e splash, tema claro e escuro a partir dos tokens, Figtree, textos em português e as quatro abas com o sino. Falta testar num aparelho Android. |
| 1 | Cadastro do usuário (nome, email, celular) | Parcial: só email e senha. |
| 2 | Cadastro do pet (nome, nascimento, tipo, sexo, raça, peso, foto) | Parcial: nome, tipo, sexo, raça com sugestões, nascimento (ou idade aproximada), peso atual, foto (câmera ou galeria, translúcida nos cards de escolha do pet) e exclusão pelo tutor principal. Falta o histórico de peso. |
| 2a | Tutores (convite, remoção, transferência) | Parcial: convite, aceite e transferência ("Transformar em tutor principal"). Falta remoção e saída. |
| 3 | Vacinas e vermífugos | Parcial: registro manual, histórico, status, edição/exclusão e leitura da carteirinha por foto (IA na nuvem, com revisão antes de salvar). Falta o lembrete por push, guardar a foto como comprovante e o histórico de peso. |
| 4 | Medicamentos | Não iniciado. |
| 5 | Histórico de incidentes | Não iniciado. |
| 5a | Central de notificações | Não iniciado. Necessária para os convites de quem já tem conta. |
| 6 | Lista de compras | Parcial: lista por casa com "A comprar" e "Itens frequentes", catálogo com ícones, seletor de casa e sincronização. Feita antes de medicamentos e incidentes, por decisão do fundador (9 de outubro de 2026). Falta o aviso na central de notificações e a atualização em tempo real. |

Atualize a coluna "Situação no código" sempre que uma área avançar.

## Vocabulário

| Termo | Significado |
| --- | --- |
| Tutor principal | Quem cadastrou o pet, ou quem o recebeu por transferência. No código atual aparece como `owner`. |
| Tutor | Pessoa convidada pelo tutor principal que aceitou o convite. |
| Convite | Pedido do tutor principal para alguém, identificado pelo email, cuidar do pet. |
| Pet | Cão ou gato cadastrado no app. |
