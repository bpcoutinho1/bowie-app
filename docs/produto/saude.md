# Saúde

Três áreas: vacinas e vermífugos, medicamentos e incidentes. Todos os tutores do pet podem registrar e editar tudo.

O app registra informações e **não faz diagnóstico**. Em incidentes, o texto é neutro e prático. Para sintomas graves, o app orienta procurar um veterinário.

## Vacinas e vermífugos

Vacinas e vermífugos seguem **as mesmas regras** de registro, status e lembrete.

### Registro

Cada dose registrada tem:

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Tipo | Sim | Vacina ou vermífugo. |
| Nome | Sim | Ex.: V10, antirrábica, nome do vermífugo. |
| Data da aplicação | Sim | |
| Data de vencimento | Sim | Quando a próxima dose deve ser dada ("Revacinar em" na carteirinha). |
| Produto e fabricante | Não | Ex.: Vanguard Plus, Zoetis. |
| Lote | Não | "Part." na etiqueta do frasco. |
| Veterinário | Não | Nome e CRMV. |
| Observações | Não | Clínica e outras anotações. |

Duas formas de registrar:

1. **Manual:** a pessoa preenche os campos.
2. **Foto da carteirinha de vacinação:** a pessoa fotografa a carteirinha e o app **lê a imagem e preenche os campos sozinho**. Uma página pode ter várias doses, então a leitura pode gerar vários registros de uma vez.
   - Antes de salvar, o app mostra o que leu para a pessoa conferir e corrigir. Nada é gravado sem essa revisão, porque um vencimento lido errado gera um lembrete errado.
   - Campos que o app não conseguiu ler ficam vazios e marcados para a pessoa preencher.
   - A foto fica guardada junto dos registros, como comprovante.
   - Como ler cada parte da carteirinha, as armadilhas e o resultado esperado com a carteirinha do Bowie estão em [leitura da carteirinha](carteirinha-de-vacinacao.md).

### Status

| Situação | Status | Cor (token) |
| --- | --- | --- |
| Vencimento a mais de 30 dias | Em dia | `success` |
| Vence em 30 dias ou menos | Vence em breve | `warning` |
| Vencimento já passou | Vencida | `danger` |

O status é **por vacina**, e vale a dose mais recente. Doses anteriores da mesma vacina ficam no histórico como "substituídas" e não geram lembrete.

O status nunca aparece só pela cor: sempre há texto ("Vence em 12 dias") e ícone. Fale do pet pelo nome: "A vacina V10 do Bowie vence em 12 dias".

### Lembrete

- Notificação no celular (push) **7 dias antes** do vencimento.
- Vai para todos os tutores do pet. Não dá para desligar, como as demais [notificações](notificacoes.md).
- O lembrete precisa funcionar mesmo que ninguém abra o app nesses dias.

## Medicamentos

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Nome do remédio | Sim | |
| Dosagem | Sim | Texto livre, ex.: "1 comprimido", "5 gotas". |
| Períodos e horários | Sim | Manhã, tarde e/ou noite, cada um com um horário. Ex.: manhã às 07h e noite às 19h. |
| Início | Sim | Padrão: hoje. |
| Fim | Não | Data em que o tratamento termina. |
| Recorrente | Não | Marcado quando o remédio é para sempre, sem data de fim. Ex.: o Omega 3 do Bowie. |

Um medicamento tem data de fim **ou** é recorrente. Depois da data de fim, ele sai da lista de medicamentos ativos e fica no histórico do pet.

### Lembrete de dose

- Notificação no celular (push) **no horário de cada período**. Ex.: "Hora do Omega 3 do Bowie (manhã)." às 07h.
- Os lembretes valem do início até o fim do tratamento, ou para sempre se for recorrente.
- O lembrete precisa funcionar mesmo sem internet e sem abrir o app.
- Vai para **todos os tutores** do pet. Quando alguém marca a dose como dada, o lembrete daquela dose some para os outros.
- Se ninguém marca a dose como dada em **30 minutos**, o app lembra mais uma vez. Só uma vez.

### Registro de dose dada

- A pessoa marca a dose como dada, pelo app ou pela própria notificação.
- O app registra **quem deu** e quando: "Dada por Bruno às 07h05".
- A dose aparece como dada para todos os tutores do pet, para ninguém dar o remédio duas vezes.

## Histórico de incidentes

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Data do incidente | Sim | Padrão: hoje. |
| O que ocorreu | Sim | Ex.: diarreia, vômito, consulta, doença. |
| Observações | Não | Campo aberto. |
| Fotos | Não | Uma ou mais. Ex.: fotografar as fezes para comparar depois. |

O histórico aparece em ordem cronológica, do mais recente para o mais antigo. Fotos de incidentes podem ser sensíveis: elas só ficam visíveis para os tutores do pet (veja [dados e privacidade](dados-e-privacidade.md)).
