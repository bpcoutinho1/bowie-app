# Saúde

Três áreas: vacinas e vermífugos, medicamentos e incidentes. Todos os tutores do pet podem registrar e editar tudo.

O app registra informações e **não faz diagnóstico**. Em incidentes, o texto é neutro e prático. Para sintomas graves, o app orienta procurar um veterinário.

## Vacinas e vermífugos

### Registro

Cada dose registrada tem:

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Tipo | Sim | Vacina ou vermífugo. |
| Nome | Sim | Ex.: V10, antirrábica, nome do vermífugo. |
| Data da aplicação | Sim | |
| Data de vencimento | Sim | Quando a próxima dose deve ser dada. |
| Observações | Não | Lote, clínica, veterinário etc. |

Duas formas de registrar:

1. **Manual:** a pessoa preenche os campos.
2. **Foto da carteirinha de vacinação:** a pessoa fotografa a carteirinha. Se o app vai ler a foto e preencher os campos sozinho, ou só guardar a imagem junto do registro, ainda está em aberto (veja [questões em aberto](questoes-em-aberto.md)).

### Status

| Situação | Status | Cor (token) |
| --- | --- | --- |
| Vencimento a mais de 30 dias | Em dia | `success` |
| Vence em 30 dias ou menos | Vence em breve | `warning` |
| Vencimento já passou | Vencida | `danger` |

O status nunca aparece só pela cor: sempre há texto ("Vence em 12 dias") e ícone. Fale do pet pelo nome: "A vacina V10 do Bowie vence em 12 dias".

### Lembrete

- Notificação no celular (push) **7 dias antes** do vencimento.
- Vai para todos os tutores do pet. Não dá para desligar, como as demais [notificações](notificacoes.md).
- O lembrete precisa funcionar mesmo que ninguém abra o app nesses dias.

## Medicamentos

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Nome do remédio | Sim | |
| Dosagem diária | Sim | Texto livre, ex.: "1 comprimido", "5 gotas". |
| Período | Sim | Manhã, tarde e/ou noite. Pode ser mais de um. |

Em aberto: data de início e fim do tratamento, lembrete em cada período e registro de "dose dada" (veja [questões em aberto](questoes-em-aberto.md)).

## Histórico de incidentes

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Data do incidente | Sim | Padrão: hoje. |
| O que ocorreu | Sim | Ex.: diarreia, vômito, consulta, doença. |
| Observações | Não | Campo aberto. |
| Fotos | Não | Uma ou mais. Ex.: fotografar as fezes para comparar depois. |

O histórico aparece em ordem cronológica, do mais recente para o mais antigo. Fotos de incidentes podem ser sensíveis: elas só ficam visíveis para os tutores do pet (veja [dados e privacidade](dados-e-privacidade.md)).
