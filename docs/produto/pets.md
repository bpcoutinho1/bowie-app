# Pets

## Cadastro

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Nome | Sim | De 1 a 80 caracteres. |
| Tipo | Sim | Cão ou gato. |
| Sexo | Sim | Macho ou fêmea. |
| Data de nascimento | Sim | O app mostra a idade calculada ("5 anos", "8 meses"). Quem não sabe a data marca "Não sei a data exata" e informa a idade aproximada ("uns 3 anos"); o app calcula uma data estimada e mostra a idade como aproximada ("cerca de 3 anos"). |
| Raça | Não | Sugestões conforme o tipo (lista abaixo), com opção de digitar outra. "Sem raça definida (SRD)" é a primeira opção. |
| Peso atual | Não | Em kg, com uma casa decimal. |
| Porte | Não | Só para cães. Calculado pelo peso, com opção de escolher à mão ([veja abaixo](#porte)). |
| Foto | Não | Uma foto de perfil, da câmera ou da galeria. |

A foto aparece translúcida no fundo dos cards em que se escolhe o pet (abas Início e Pets), atrás do nome e do resumo ("Cão · Macho · Border Collie · 5 anos"). Assim, quem tem mais de um pet reconhece cada um pela foto. No seletor de pets da aba Saúde, ela aparece pequena e redonda ao lado do nome.

Guardar a data de nascimento, e não a idade, mantém a idade sempre certa e permite lembrar o aniversário do pet.

### Aniversário

Decisão do fundador (12 de outubro de 2026): o app avisa o aniversário do pet **30 dias** e **7 dias** antes, e no próprio dia.

- Texto: "Faltam 30 dias para o aniversário do Bowie", "Faltam 7 dias para o aniversário da Mia", "Amanhã é o aniversário do Bowie", "Hoje é o aniversário do Bowie: 6 anos".
- O artigo segue o sexo do pet: "do" para macho, "da" para fêmea. Sem sexo informado, "de".
- Pets com idade aproximada (sem a data exata) não têm aviso, porque a data é uma estimativa.
- 29 de fevereiro vira 28 de fevereiro nos anos sem esse dia.
- O aniversário usa a cor Sorriso (`smile`), a de uso raro para afeto.
- Além do aviso no Início, uma notificação no celular 7 dias antes, às 9h: "Bowie faz aniversário em 7 dias! Faça algo incrível para celebrar este dia!" (decisão de 17 de outubro de 2026).

### Peso

O cadastro guarda o peso atual, e o histórico fica no [diário](diario.md#peso): cada pesagem tem data, peso e observações. Embaixo de "Peso atual", a página do pet mostra o gráfico **"Evolução do peso"**, com as datas no eixo horizontal e o peso em kg no vertical (decisão de 26 de outubro de 2026).

Ainda vai entrar um lembrete mensal para registrar o peso: "Que tal registrar o peso do Bowie este mês?". Ele aparece só na [central de notificações](notificacoes.md), sem push.

A [leitura da carteirinha](carteirinha-de-vacinacao.md) também importa as medições de peso que estiverem nela, como pesagens no diário. O peso atual é sempre a pesagem mais recente, venha ela do cadastro, do diário ou da carteirinha.

### Porte

Decisão do fundador (29 de outubro de 2026), a partir de feedback dos testes: para cães, o app mostra o **porte** logo abaixo do "Peso atual" ("Porte: Médio, pelo peso"). Gatos não têm porte.

| Porte | Peso adulto | Exemplos |
| --- | --- | --- |
| Mini | Até 5 kg | Chihuahua, Pinscher, Yorkshire, Lulu da Pomerânia |
| Pequeno | Acima de 5 até 10 kg | Shih Tzu, Pug, Dachshund, Bulldog Francês |
| Médio | Acima de 10 até 25 kg | Beagle, Border Collie, Cocker Spaniel, Chow Chow, Pitbull |
| Grande | Acima de 25 até 45 kg | Labrador, Golden Retriever, Pastor Alemão, Rottweiler |
| Gigante | Acima de 45 kg | Dogue Alemão, São Bernardo, Terra-nova |

- Os limites não deixam buracos entre as faixas: 10,5 kg é Médio, 25,4 kg é Grande.
- O porte sai só do peso. O app não pergunta a altura.
- **Filhotes:** antes de 1 ano, o peso ainda não diz o porte adulto. O app mostra "Definido quando adulto".
- **À mão:** o padrão é "pelo peso", que muda sozinho quando o peso muda. O tutor pode escolher outro porte (um cão acima do peso, um filhote de raça grande); a escolha fica até ele voltar para "pelo peso".
- O porte aparece também na **ficha compartilhada** ("Porte médio"), porque hotéis e creches separam os cães por porte. Não aparece no resumo do pet nos cards, que já tem informação demais.

## Raças sugeridas

Base: [PetCenso 2025 da Petlove](https://www.infomoney.com.br/?p=2941590), com mais de 1,8 milhão de pets cadastrados ([cobertura da Band](https://www.band.com.br/noticias/vira-latas-lideram-ranking-de-pets-mais-populares-do-brasil-veja-top-10-202507071138)). As raças do ranking vêm primeiro, na ordem da pesquisa. Depois vêm outras raças comuns no Brasil, em ordem alfabética, para completar a lista.

### Cães

Do ranking:

1. Sem raça definida (SRD), cerca de 26%
2. Shih Tzu, 17%
3. Yorkshire Terrier, 6%
4. Spitz Alemão (Lulu da Pomerânia), 5%
5. Lhasa Apso, 3%
6. Golden Retriever, 3%
7. Pinscher, 3%
8. Dachshund (Salsicha), 2%
9. Pug, 2%
10. Maltês, 2%

Complemento: Beagle, Border Collie, Boxer, Buldogue Francês, Buldogue Inglês, Chihuahua, Cocker Spaniel, Dálmata, Doberman, Fila Brasileiro, Husky Siberiano, Labrador Retriever, Pastor Alemão, Pastor Belga, Pit Bull, Poodle, Rottweiler, Schnauzer, Shiba Inu, Weimaraner.

### Gatos

Do ranking:

1. Sem raça definida (SRD), cerca de 86%
2. Siamês, 5%
3. Persa, 2%
4. Maine Coon, 0,7%
5. Angorá Turco, 0,5%
6. Ragdoll, 0,4%

Complemento: Azul Russo, Bengal, British Shorthair, Exótico de Pelo Curto, Himalaio, Sagrado da Birmânia, Sphynx.

A lista deve virar um arquivo de dados no código, fácil de revisar, e não ficar espalhada nas telas.

## Falecimento

Quando um pet falece, o tutor principal pode marcá-lo como **falecido**:

- O pet sai das listas e telas do dia a dia.
- Todos os lembretes e notificações dele param.
- O histórico (vacinas, remédios, incidentes, fotos, peso) fica guardado como memória e pode ser consultado pelos tutores.
- Nenhuma notificação é enviada sobre o falecimento.

Mais adiante, essa tela pode ter uma mensagem de conforto para os tutores. O texto precisa ser escrito com cuidado e aprovado pelo fundador.

## Exclusão

Só o tutor principal pode excluir o pet (veja [contas e tutores](contas-e-tutores.md)). A exclusão remove o pet e todos os registros dele para todos os tutores. Por envolver dados de saúde, a tela deve pedir confirmação com o nome do pet.
