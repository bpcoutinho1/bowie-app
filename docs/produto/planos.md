# Planos e preço

Decidido com o fundador em 17 de outubro de 2026. **Nada é cobrado nesta etapa**: o app é lançado de graça para os testes, e a cobrança entra depois de medir a ativação e o uso.

## Planos

| | Grátis | Premium |
| --- | --- | --- |
| Preço | R$ 0 | R$ 9,90 por mês ou R$ 99,90 por ano |
| Pets | 1 | Até 5 |
| Saúde, remédios, diário, compras, contatos | Tudo | Tudo |
| Comprovante de vacina | Incluído | Incluído |
| Ficha compartilhada | Incluída | Incluída |
| Leitura da carteirinha por IA | Até 3 fotos lidas | Sem limite |
| Fotos e PDFs no diário | Até 10, somando fotos e PDFs | Sem limite |

O comprovante de vacina fica no plano grátis de propósito: é o que hotéis e creches pedem, e a ficha compartilhada é o principal meio de o Bowie ficar conhecido.

## Regras

- **O plano é do tutor principal**: quem cria a conta e cadastra os pets. Os tutores convidados usam os pets dele sem pagar e sem contar no limite.
- **A mesma conta pode ter os dois papéis** (decisão de 18 de outubro de 2026): ser tutor principal dos próprios pets e tutor convidado nos pets de outra casa. Só os pets em que a pessoa é tutor principal contam no plano dela.
- **Os limites do plano grátis valem para sempre** (decisão de 18 de outubro de 2026): não se renovam a cada mês. Usadas as 3 fotos lidas por IA ou os 10 arquivos do diário, mais só no Premium. É o convite para assinar.
- **O limite de leitura conta fotos, não leituras.** Uma leitura com 2 páginas gasta 2 das 3 fotos do plano grátis.
- **O limite de 10 arquivos conta envios, não arquivos guardados** (decisão de 18 de outubro de 2026): são 10 envios na vida da conta. Apagar uma foto ou um PDF não devolve o envio.
- **O limite de 10 arquivos vale para o diário.** Os comprovantes de vacina não contam: ficam sempre no plano grátis.
- **30 dias de Premium grátis** para toda conta nova, **sem cartão**. Ao fim, a conta volta para o grátis; quem quiser continuar com o Premium (por exemplo, por ter mais de um pet) assina.
- **Nada fica refém.** Quem volta para o grátis continua vendo e baixando tudo o que registrou e enviou. O que muda é só o que dá para adicionar: um segundo pet, novas leituras por IA além do limite, novos arquivos além do limite.
- **Pagamento pelas lojas** (decisão de 20 de outubro de 2026): só pela App Store e pelo Google Play, por meio do RevenueCat. Sem cobrança por fora da loja. Com o Small Business Program, a Apple fica com 15%.

## Antes de cobrar

Já existe: o plano de cada conta no banco (`account_plans`), o teste de 30 dias, os contadores e os limites no app, com a tela "Bowie Premium". O plano é mudado à mão no Supabase para testes ([guia](../guias/planos.md)). Falta:

- Conferir os limites também no servidor (na função `read-vaccine-card` e no envio de arquivos), e não só no app.
- Ligar a assinatura pela App Store: o código está pronto e falta a configuração ([guia](../guias/assinaturas.md)). O Google Play vem com o app de Android.
