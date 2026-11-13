# Publicar na Google Play

Passo a passo para gerar o Bowie para Android e enviar à Google Play. Identificador do app: **`app.bowie`**, o mesmo do iPhone. Os passos 1 a 4 são feitos uma vez só; o 5 e o 6, a cada versão.

O app nunca rodou num aparelho Android de verdade. Por isso, a primeira versão vai para o **teste interno**, que só você e quem você convidar recebem, e não direto para a loja.

## 1. Conta na Google Play (uma vez só)

1. Em https://play.google.com/console/signup, entre com uma conta Google e escolha o tipo **Organização**, com os dados da Arca Lab e o mesmo D-U-N-S usado na Apple. A taxa é de US$ 25, uma vez só.
2. Espere a Google verificar a empresa. Pode levar alguns dias.

Por que Organização: as contas pessoais novas precisam de um teste fechado com pelo menos 12 pessoas durante 14 dias antes de publicar, regra que não vale para contas de organização. Confira a regra atual na própria Play Console, porque ela muda de tempos em tempos.

## 2. Preparar o Mac para Android (uma vez só)

1. Instale o Android Studio: https://developer.android.com/studio. Abra uma vez e deixe o assistente instalar o **Android SDK**.
2. No Terminal:

```bash
flutter doctor --android-licenses
flutter doctor
```

Aceite as licenças com `y`. No `flutter doctor`, a linha **Android toolchain** deve ficar com ✓.

## 3. Criar a chave de upload (uma vez só)

A Google Play só aceita pacotes assinados com a sua chave de upload. Ela fica **fora do repositório**, na sua pasta de usuário.

```bash
keytool -genkey -v -keystore ~/bowie-upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

O `keytool` pede uma senha (anote) e nome, empresa e cidade (pode usar Arca Lab e São Paulo). Quando perguntar a senha da chave, aperte Enter para usar a mesma.

Depois, crie o arquivo `android/key.properties` (ele já está no `.gitignore` e nunca vai para o GitHub):

```bash
cd /Users/brunocoutinho/Documents/bowie-app
cat > android/key.properties <<'EOF'
storePassword=A_SENHA_QUE_VOCE_ESCOLHEU
keyPassword=A_SENHA_QUE_VOCE_ESCOLHEU
keyAlias=upload
storeFile=/Users/brunocoutinho/bowie-upload-keystore.jks
EOF
open -e android/key.properties
```

No editor que abrir, troque `A_SENHA_QUE_VOCE_ESCOLHEU` pela senha (nas duas linhas) e salve.

**Guarde uma cópia** do arquivo `bowie-upload-keystore.jks` e da senha num lugar seguro, como um gerenciador de senhas. Não mande por chat, email nem coloque no repositório. Se perder, a Google consegue trocar a chave de upload, mas o processo é demorado.

## 4. Criar o app na Play Console (uma vez só)

1. Em https://play.google.com/console → **Criar app**:
   - Nome do app: "Bowie: diário do pet"
   - Idioma padrão: Português (Brasil)
   - App ou jogo: App
   - Gratuito ou pago: Gratuito (o Premium é assinatura dentro do app)
2. Em **Configuração do app** (Painel), preencha o que a Play Console pede antes da primeira versão:
   - **Política de privacidade:** https://bowieapp.pet/privacidade/
   - **Acesso ao app:** o login é obrigatório. Informe email e senha de uma conta de teste do Bowie, como na Apple.
   - **Anúncios:** não tem.
   - **Classificação do conteúdo:** responda o questionário (app de utilidade, sem conteúdo sensível).
   - **Público-alvo:** maiores de 18 anos.
   - **Segurança dos dados:** os dados que o app guarda estão em `docs/legal/politica-de-privacidade.md` (conta, dados do pet, fotos, arquivos). Todos criptografados em trânsito; a pessoa pode excluir a conta.
   - **Exclusão de conta:** a Play exige também um **link na web** onde a pessoa pede a exclusão. Use uma página no site explicando o caminho no app (Minha conta → Excluir minha conta) e o email contato@bowieapp.pet para quem não tem mais o app.
   - **Assinatura do app pelo Google Play:** aceite. A Google guarda a chave final; a sua é só a de upload.

## 5. Gerar o pacote (a cada versão)

Com tudo atualizado (veja [atualizar para uma versão nova](rodar-no-iphone.md#atualizar-para-uma-versão-nova)):

```bash
cd /Users/brunocoutinho/Documents/bowie-app
./scripts/gerar-aab.sh
```

Leva alguns minutos. No fim aparece "Pronto: build/app/outputs/bundle/release/app-release.aab" e o Finder abre com o arquivo selecionado.

O código da versão vem do relógio, então cada pacote tem um número maior que o anterior, como a Play exige.

## 6. Enviar para o teste interno (a cada versão)

1. Play Console → **Bowie** → **Testar e lançar** → **Testes** → **Teste interno**.
2. Na primeira vez, em **Testadores**, crie uma lista com os emails (contas Google) de quem vai testar.
3. **Criar nova versão** → arraste o `app-release.aab` → em notas da versão, escreva o que mudou → **Avançar** → **Salvar e publicar**.
4. Copie o **link de participação** da aba Testadores e mande para os testadores. Eles abrem no celular Android, aceitam e instalam pela Play Store.

O teste interno costuma ficar disponível em minutos, sem revisão completa.

## 7. Publicar na loja

Depois de testar num Android de verdade, promova a versão do teste interno para **Produção** (ou crie a versão de produção com o mesmo `.aab`), preencha a página da loja (descrição, ícone, capturas de tela) e envie para revisão.

## Assinaturas no Android

Passo a passo completo em [assinaturas no Android](assinaturas-android.md): perfil de pagamentos, assinaturas no Google Play, acesso do RevenueCat, chave `goog_…` no `dart_defines.json`, teste sem pagar e produção. Sem a chave, o app mostra "Assinatura em breve" na tela do Premium, e o resto funciona normalmente.

## Problemas comuns

| Mensagem | O que fazer |
| --- | --- |
| "Falta o arquivo android/key.properties" | Faça o passo 3. |
| `Android toolchain` com ✗ no `flutter doctor` | Abra o Android Studio, instale o SDK e rode `flutter doctor --android-licenses`. |
| "Keystore was tampered with, or password was incorrect" | A senha no `key.properties` está errada. Confira as duas linhas de senha. |
| A Play diz que o pacote foi assinado com a chave errada | O `.aab` foi gerado sem o `key.properties` ou com outra chave. Gere de novo pelo script. |
| "Version code já usado" | Gere o pacote de novo: o script usa um número novo a cada minuto. |
| A Play pede para justificar "Read media images" e "Read media video" | O app não usa essas permissões: um pacote (`open_filex`) as declarava, e o `AndroidManifest.xml` do app as remove. Gere um pacote novo pelo script e envie: o formulário some. Não escreva justificativa, porque a Play recusa acesso amplo a fotos para quem só escolhe uma foto de vez em quando. |
