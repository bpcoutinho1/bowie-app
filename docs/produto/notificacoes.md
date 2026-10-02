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
- O sino mostra quantas notificações ainda não foram lidas.
- Os textos falam do pet pelo nome e não usam palavras com gênero para quem recebe. Por exemplo, "convidou você para cuidar do Bowie" em vez de "convidou você para ser tutora", porque o app não pergunta o gênero das pessoas.
- Em incidentes de saúde, o texto é neutro e não repete detalhes sensíveis: "Bruno registrou um incidente do Bowie.", sem descrever o sintoma.

## Convite para quem já tem conta

Quem já usa o app recebe o convite na central de notificações, com o botão "Aceitar". O vínculo só fica ativo depois desse toque.

O convite pendente **expira em 30 dias**. Depois disso, o tutor principal pode reenviá-lo. Isso vale também para quem ainda não tem conta (veja [contas e tutores](contas-e-tutores.md#convite)).

## Notificação no app e push

- O lembrete de vacina e vermífugo é push, 7 dias antes do vencimento (veja [saúde](saude.md#lembrete)). Ele também aparece na central.
- Os outros eventos aparecem na central. Ainda está em aberto se também viram push (veja [questões em aberto](questoes-em-aberto.md)).
