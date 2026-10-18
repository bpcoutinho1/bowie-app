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
| Leitura da carteirinha por IA | Até 3 | Sem limite |
| Fotos e PDFs no diário | Com limite (ex.: 20 arquivos) | Sem limite |

O comprovante de vacina fica no plano grátis de propósito: é o que hotéis e creches pedem, e a ficha compartilhada é o principal meio de o Bowie ficar conhecido.

## Regras

- **O plano é do tutor principal**: quem cria a conta e cadastra os pets. Os tutores convidados usam os pets dele sem pagar e sem contar no limite.
- **Tutores convidados não cadastram pets.** Para ter pets próprios, a pessoa cria uma conta como tutor principal.
- **30 dias de Premium grátis** para toda conta nova, **sem cartão**. Ao fim, a conta volta para o grátis; quem quiser continuar com o Premium (por exemplo, por ter mais de um pet) assina.
- **Nada fica refém.** Quem volta para o grátis continua vendo e baixando tudo o que registrou e enviou. O que muda é só o que dá para adicionar: um segundo pet, novas leituras por IA além do limite, novos arquivos além do limite.
- **Pagamento pelas lojas.** Assinatura de funcionalidade digital vendida dentro do app precisa usar a compra da App Store e do Google Play, que ficam com 15% a 30%. Sugestão: RevenueCat, que cuida das duas lojas.

## Antes de cobrar

- Guardar no banco o plano de cada tutor principal (grátis, teste ou Premium, e até quando), para não precisar migrar dados depois.
- Contar as leituras por IA de cada conta no servidor (a Edge Function `read-vaccine-card`).
- Veja as questões em aberto sobre planos em [questões em aberto](questoes-em-aberto.md#planos).
