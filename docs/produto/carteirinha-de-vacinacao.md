# Leitura da carteirinha de vacinação

O app lê a foto da carteirinha e preenche os registros de vacina e vermífugo (veja [saúde](saude.md#vacinas-e-vermífugos)). Este documento descreve como uma carteirinha é organizada, o que deve ser extraído e as armadilhas. A carteirinha do Bowie é o exemplo de referência.

## Como a carteirinha é organizada

Cada página é dedicada a **uma vacina** (o título da página: "Vacina V10", "Vacina contra Raiva"). Cada página tem várias linhas, uma por dose:

| Parte da linha | Conteúdo | Como aparece |
| --- | --- | --- |
| Data | Dia da aplicação | Escrita à mão, `dd/mm/aa` |
| Revacinar em | Data da próxima dose | Escrita à mão, `dd/mm/aa` |
| Etiqueta do frasco | Produto, fabricante, partida (lote), fabricação e validade do frasco | Adesivo impresso, às vezes dois sobrepostos (vacina e diluente) |
| Carimbo do veterinário | Nome, CRMV e assinatura | Carimbo com assinatura por cima |

Algumas carteirinhas também têm páginas de **vermífugo** (data, produto, peso) e de **peso** (data, peso). As medições de peso também são importadas, para o histórico de peso do pet (veja [pets](pets.md#peso)).

## O que extrair de cada dose

| Campo do app | Origem na carteirinha |
| --- | --- |
| Tipo | Vacina ou vermífugo, conforme a página |
| Nome | Título da página (ex.: "V10", "Raiva") |
| Data da aplicação | "Data" |
| Data de vencimento | **"Revacinar em"** |
| Produto e fabricante | Etiqueta (ex.: "Vanguard Plus", Zoetis) |
| Lote | "Part." da etiqueta |
| Veterinário | Nome e CRMV do carimbo |
| Foto | A foto da página, guardada como comprovante |

## Armadilhas

1. **"Venc." da etiqueta não é o vencimento da dose.** A etiqueta traz a validade do frasco da vacina. O vencimento que gera o lembrete é sempre o "Revacinar em", escrito à mão. Confundir os dois geraria lembretes errados. Ex.: na V10 de 04/05/26 do Bowie, a etiqueta diz "Venc. SET/26", mas a revacinação é em 04/05/27.
2. **Ano com dois dígitos.** "26" é 2026.
3. **Linhas vazias** (com "Anual" impresso de fundo, ou só os traços) não são doses e devem ser ignoradas.
4. **Várias doses da mesma vacina na mesma página.** Todas entram no histórico, mas só a **mais recente** define o status e o lembrete. As doses antigas aparecem como "substituídas", nunca como "vencidas".
5. **Assinaturas sobre o texto.** A assinatura costuma passar por cima do carimbo e das datas. Campos com leitura incerta ficam marcados para a pessoa conferir.
6. **Etiquetas sobrepostas.** Vacina e diluente podem ter etiquetas parecidas. Vale a etiqueta da vacina.
7. **Cabeçalhos e logos da clínica** (ex.: "Vetprado") não são dados de dose.

## Exemplo: carteirinha do Bowie

Resultado esperado da leitura das fotos enviadas em 2 de outubro de 2026. Serve de teste para a função de leitura.

### Vacinas

| Vacina | Aplicação | Revacinar em | Produto (fabricante) | Lote | Status em 02/10/2026 |
| --- | --- | --- | --- | --- | --- |
| V10 | 05/05/2024 | 05/05/2025 | Vanguard Plus (Zoetis) | 004/23 | Substituída |
| V10 | 08/05/2025 | 08/05/2026 | Vanguard Plus (Zoetis) | 002/24 | Substituída |
| V10 | 04/05/2026 | 04/05/2027 | Vanguard Plus (Zoetis) | 003/25 | Em dia |
| Giardíase | 06/08/2026 | 06/08/2027 | GiardiaVax (Zoetis) | 014/25 | Em dia |
| Tosse dos canis | 06/08/2026 | 06/08/2027 | Vanguard B Oral (Zoetis) | 002/25 | Em dia |
| Raiva | 06/08/2026 | 06/08/2027 | Canigen R (Virbac) | 001/25 | Em dia |

Todas as doses têm carimbo de veterinário com nome e CRMV legíveis.

Lembretes gerados (7 dias antes): V10 em 27/04/2027; Giardíase, Tosse dos canis e Raiva em 30/07/2027.

### Vermífugo

A página de vermífugo está em branco: nenhum registro.

### Peso

Uma medição, importada para o histórico de peso: 23 kg em 17/05/2026.
