# Pets

## Cadastro

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| Nome | Sim | De 1 a 80 caracteres. |
| Tipo | Sim | Cão ou gato. |
| Data de nascimento | Sim | Pode ser aproximada. O app mostra a idade calculada ("5 anos", "8 meses"). |
| Raça | Não | Sugestões conforme o tipo (lista abaixo), com opção de digitar outra. "Sem raça definida (SRD)" é a primeira opção. |
| Peso atual | Não | Em kg, com uma casa decimal. |
| Foto | Não | Uma foto de perfil, da câmera ou da galeria. |

Guardar a data de nascimento, e não a idade, mantém a idade sempre certa e permite lembrar o aniversário do pet no futuro.

### Peso

No MVP o cadastro guarda só o peso atual. A evolução do peso (histórico com datas e gráfico) está prevista para depois. Por isso, convém gravar cada alteração de peso com data desde o início, mesmo mostrando só o valor mais recente.

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

## Exclusão

Só o tutor principal pode excluir o pet (veja [contas e tutores](contas-e-tutores.md)). A exclusão remove o pet e todos os registros dele para todos os tutores. Por envolver dados de saúde, a tela deve pedir confirmação com o nome do pet.
