# Notificações

O app tem uma **central de notificações**, aberta por um ícone de sino no topo das telas principais. Ela mostra o que aconteceu nos pets e nas casas de que a pessoa participa.

## Exemplos

| Evento | Exemplo de texto |
| --- | --- |
| Convite recebido (quem já tem conta) | "Bruno convidou você para cuidar do Bowie." com o botão **Aceitar** |
| Item adicionado à lista de compras | "Bruno adicionou \"Ração do Bowie 10 kg\" à lista de compras." |
| Medicamento registrado | "Bruno adicionou um medicamento para o Bowie." |
| Vacina ou vermífugo perto do vencimento | "A vacina V10 do Bowie vence em 7 dias." |

Os demais registros (vacinas, vermífugos, incidentes, alterações no cadastro do pet, entrada e saída de tutores) seguem o mesmo padrão: quem fez, o que fez, de qual pet.

## Regras

- Quem fez a ação **não** recebe notificação dela. As outras pessoas do pet ou da casa recebem.
- Tocar numa notificação leva à tela do registro (o item da lista, o medicamento, o convite).
- Quando há notificações não lidas, o sino ganha um marcador vermelho (token `danger`) com o número de não lidas. O número e o rótulo de acessibilidade ("3 notificações não lidas") garantem que a informação não dependa só da cor.
- A pessoa só vê o conteúdo das notificações ao tocar no sino.
- Não há configuração: todos recebem as mesmas notificações. Não dá para escolher tipos nem pets.
- As notificações ficam guardadas por **90 dias** e depois são apagadas.
- Os textos falam do pet pelo nome e não usam palavras com gênero para quem recebe. Por exemplo, "convidou você para cuidar do Bowie" em vez de "convidou você para ser tutora", porque o app não pergunta o gênero das pessoas.
- Em incidentes de saúde, o texto é neutro e não repete detalhes sensíveis: "Bruno registrou um incidente do Bowie.", sem descrever o sintoma.

## Convite para quem já tem conta

Quem já usa o app recebe o convite **apenas no app**, na central de notificações, com o botão "Aceitar". Não há email nesse caso. O vínculo só fica ativo depois desse toque.

O convite pendente **expira em 30 dias**. Depois disso, o tutor principal pode reenviá-lo. Isso vale também para quem ainda não tem conta (veja [contas e tutores](contas-e-tutores.md#convite)).

## Notificação no app e push

Só dois eventos viram push no celular, além de aparecer na central:

- O lembrete de vacina e vermífugo, 7 dias antes do vencimento (veja [saúde](saude.md#lembrete)).
- O convite recebido por quem já tem conta.

Todo o resto (compras, medicamentos, incidentes, alterações no pet, tutores) fica **só na central**, sem push, para não incomodar.
