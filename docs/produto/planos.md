# Planos e preço

Decidido com o fundador em 17 de outubro de 2026. **Nada é cobrado nesta etapa**: o app é lançado de graça para os testes, e a cobrança entra depois de medir a ativação e o uso.

## Planos

| | Grátis | Premium |
| --- | --- | --- |
| Preço | R$ 0 | R$ 9,90 por mês ou R$ 99,90 por ano |
| Pets | Até 2 | Até 10 |
| Saúde, remédios, diário, compras, contatos | Tudo | Tudo |
| Comprovante de vacina | Incluído | Incluído |
| Ficha compartilhada | Incluída | Incluída |
| Leitura da carteirinha por IA | Não | Incluída |
| Fotos e PDFs no diário | Até 5, somando fotos e PDFs | Sem limite |

O comprovante de vacina fica no plano grátis de propósito: é o que hotéis e creches pedem, e a ficha compartilhada é o principal meio de o Bowie ficar conhecido.

## Regras

- **O plano é do tutor principal**: quem cria a conta e cadastra os pets. Os tutores convidados usam os pets dele sem pagar e sem contar no limite.
- **A mesma conta pode ter os dois papéis** (decisão de 18 de outubro de 2026): ser tutor principal dos próprios pets e tutor convidado nos pets de outra casa. Só os pets em que a pessoa é tutor principal contam no plano dela.
- **Os limites do plano grátis valem para sempre** (decisão de 18 de outubro de 2026): não se renovam a cada mês. Usados os 5 arquivos do diário, mais só no Premium. É o convite para assinar.
- **Até 2 pets no plano grátis** (decisão de 26 de outubro de 2026, antes era 1): mais tutores começam a usar o app de verdade, com os pets da casa. O terceiro pet pede o Premium.
- **Leitura da carteirinha por IA só no Premium** (decisão de 26 de outubro de 2026; antes, o plano grátis lia até 3 fotos): cada leitura tem custo na API da Anthropic, então ele só existe para quem paga. No plano grátis, as vacinas são registradas à mão, e a leitura aparece como recurso do Premium. A função `read-vaccine-card` confere o plano no servidor.
- **O limite de 5 arquivos conta envios, não arquivos guardados** (decisão de 18 de outubro de 2026; o limite passou de 10 para 5 em 21 de outubro de 2026): são 5 envios na vida da conta. Apagar uma foto ou um PDF não devolve o envio.
- **O limite de 5 arquivos vale para o diário.** Os comprovantes de vacina não contam: ficam sempre no plano grátis.
- **Sem teste do Premium** (decisão de 22 de outubro de 2026; antes, toda conta nova tinha 30 dias de Premium grátis): a conta nova começa no plano grátis, com os limites dele. Quem quiser mais pets, leitura por IA ou arquivos sem limite assina. Um teste ainda pode ser dado à mão, como cortesia ([guia](../guias/planos.md)).
- **Nada fica refém.** Quem volta para o grátis continua vendo e baixando tudo o que registrou e enviou. O que muda é só o que dá para adicionar: um terceiro pet, novas leituras por IA, novos arquivos além do limite.
- **Premium com até 10 pets** (decisão de 21 de outubro de 2026, antes eram 5).
- **Pagamento pelas lojas** (decisão de 20 de outubro de 2026): só pela App Store e pelo Google Play, por meio do RevenueCat. Sem cobrança por fora da loja. Com o Small Business Program, a Apple fica com 15%.

## Antes de cobrar

Já existe: o plano de cada conta no banco (`account_plans`), os contadores e os limites no app, com a tela "Bowie Premium". O plano é mudado à mão no Supabase para testes ([guia](../guias/planos.md)). Falta:

- Conferir o limite de arquivos também no servidor, no envio, e não só no app. A leitura por IA já é conferida no servidor.
- Ligar a assinatura pela App Store: o código está pronto e falta a configuração ([guia](../guias/assinaturas.md)). O Google Play vem com o app de Android.
