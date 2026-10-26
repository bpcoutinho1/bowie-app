# Diário

O diário guarda o que acontece com o pet e o que está agendado para ele. Decisão do fundador (10 de outubro de 2026): o diário substitui o "histórico de incidentes" que estava na aba Saúde e ganha uma aba própria.

O app registra informações e **não faz diagnóstico**. Para sintomas, o texto é neutro e prático, e o formulário lembra de procurar um veterinário quando o sintoma é forte ou não passa.

## O que se registra

| Tipo | Exemplos |
| --- | --- |
| Sintoma | Diarreia, vômito, tosse, coceira, falta de apetite, machucado |
| Consulta | Consulta de rotina, retorno, emergência, cirurgia |
| Exame | Exame de sangue, ultrassonografia, exame de fezes, exame de urina, raio-X |
| Peso | "Controle o peso do seu pet": a data, o peso em kg e observações ([veja abaixo](#peso)) |
| Outro | Banho e tosa, adestramento, fisioterapia |

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Tipo | Sim | Um dos cinco acima. |
| Título | Sim | Sugestões conforme o tipo; dá para digitar outro. |
| Dia | Sim | Padrão: o dia escolhido no calendário (hoje, se nenhum). |
| Horário | Não | Útil para consultas e exames. |
| Profissional ou local | Não | Um dos [contatos](contatos.md) da casa do pet, como o veterinário ou o laboratório. |
| Observações | Não | Campo aberto. |
| Fotos | Não | Até 4, da câmera ou da galeria. Ex.: fotografar fezes com sangue ou uma diarreia diferente, para comparar depois e mostrar ao veterinário. |
| Arquivos | Não | Até 5 PDFs de até 10 MB cada, em qualquer tipo de registro. Ex.: o resultado do hemograma, uma receita, o laudo de um raio X. Entram automaticamente na ficha compartilhada com o veterinário. |

## Peso

Decisão do fundador (26 de outubro de 2026): o peso é registrado no diário, em "Registrar" → **Peso**, e a página do pet mostra a evolução num gráfico.

- O registro de peso tem só **dia**, **peso (kg)** e **observações** (ex.: "pesado na clínica", "mudou a ração"). Sem horário, contato, fotos nem arquivos.
- O peso é de hoje ou de um dia que já passou: não se agenda pesagem.
- Um peso por dia: registrar de novo no mesmo dia pelo perfil ou pela carteirinha troca o daquele dia.
- O **"Peso atual"** do perfil é sempre a pesagem mais recente. Mudar o "Peso atual" na página do pet também vira a pesagem de hoje no diário. O peso lido na carteirinha entra como pesagem no dia da medição.
- Na página do pet, embaixo de "Peso atual", o gráfico **"Evolução do peso"**: o tempo no eixo horizontal (as datas das pesagens) e o peso no vertical (kg), com um resumo em texto ("+2,5 kg desde 01/06/2026") e o botão "Registrar peso". Sem pesagens, só o botão.

## Passado e futuro

- Um registro num dia que já passou (ou hoje) é algo que **aconteceu**.
- Um registro num dia futuro é um **agendamento**: consulta ou exame marcado.

## Tela

- Um **calendário do mês**, com um ponto nos dias que têm registros: cheio para o que aconteceu, vazado para o que está agendado.
- Tocar num dia mostra os registros dele. O botão principal vira "Registrar" (hoje ou antes) ou "Agendar" (dias futuros).
- Abaixo: **Próximos agendamentos** e **Registros recentes**.
- Quando o registro tem um contato com telefone, um botão liga direto para ele.
- As fotos aparecem pequenas em cada registro. Tocar abre a foto grande, com zoom, e dá para passar para a próxima.
- Cada PDF aparece com o nome no registro. Tocar abre o arquivo no celular.
- As fotos e os arquivos podem ser sensíveis: ficam num armazenamento privado e só os tutores do pet veem. Excluir o registro apaga as fotos dele.
- A aba **Início** mostra, em cada pet, o próximo agendamento (ou um horário marcado para hoje).

## Quem pode

Todos os tutores do pet veem, registram, editam e excluem, como na saúde. O app guarda quem fez a última alteração.

## Depois

- Lembrete por push na véspera de um agendamento, como o das vacinas.
- Aviso na central de notificações quando alguém registra algo. Em sintomas, o texto não repete o detalhe: "Bruno registrou algo no diário do Bowie."
