# Produto

Esta seção descreve o que o Bowie **deve** fazer: visão, regras de negócio e prioridades. É a referência para decidir o que construir. O que o código faz **hoje** fica em [`../funcionamento/`](../funcionamento/).

Quem decide o conteúdo desta seção é o Bruno Coutinho, fundador do produto. A primeira versão foi escrita a partir das respostas dele, em 1º de outubro de 2026.

## Documentos

1. [Visão](visao.md): por que o app existe, para quem, plataformas e modelo de negócio.
2. [Contas e tutores](contas-e-tutores.md): cadastro do usuário, tutor principal, convites, remoção e transferência.
3. [Pets](pets.md): cadastro do pet e lista de raças sugeridas.
4. [Saúde](saude.md): vacinas, vermífugos, medicamentos e incidentes.
5. [Lista de compras](compras.md): a lista compartilhada, no estilo do app Bring.
6. [Dados, sincronização e privacidade](dados-e-privacidade.md): uso sem internet, sincronização entre tutores e LGPD.
7. [Questões em aberto](questoes-em-aberto.md): o que ainda precisa de decisão.

## Prioridade do MVP

| # | Área | Situação no código |
| --- | --- | --- |
| 0 | Base: Android, tema e marca, textos em português | Parcial: projeto Android criado, com ícone e splash da marca nas duas plataformas. Falta o tema a partir dos tokens, a fonte Figtree e traduzir os textos. |
| 1 | Cadastro do usuário (nome, email, celular) | Parcial: só email e senha. |
| 2 | Cadastro do pet (nome, nascimento, tipo, raça, peso, foto) | Parcial: só nome. |
| 2a | Tutores (convite, remoção, transferência) | Parcial: só convite e aceite. |
| 3 | Vacinas e vermífugos | Não iniciado. |
| 4 | Medicamentos | Não iniciado. |
| 5 | Histórico de incidentes | Não iniciado. |
| 6 | Lista de compras | Não iniciado. A ordem ainda precisa ser confirmada (veja [questões em aberto](questoes-em-aberto.md)). |

Atualize a coluna "Situação no código" sempre que uma área avançar.

## Vocabulário

| Termo | Significado |
| --- | --- |
| Tutor principal | Quem cadastrou o pet, ou quem o recebeu por transferência. No código atual aparece como `owner`. |
| Tutor | Pessoa convidada pelo tutor principal que aceitou o convite. |
| Convite | Pedido do tutor principal para alguém, identificado pelo email, cuidar do pet. |
| Pet | Cão ou gato cadastrado no app. |
