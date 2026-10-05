# Rodar o app no Xcode (Mac)

Passo a passo para abrir o Bowie no Xcode e rodar no simulador ou no seu iPhone.

## 1. Preparar o Mac (uma vez só)

1. Instale o **Xcode** pela App Store. Abra uma vez, aceite os termos e, quando ele oferecer, instale o simulador do iOS.
2. No **Terminal**:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   sudo softwareupdate --install-rosetta --agree-to-license
   ```
3. Instale o **Homebrew**, se ainda não tiver, seguindo [brew.sh](https://brew.sh).
4. Instale o **Flutter** e o **CocoaPods**:
   ```bash
   brew install --cask flutter
   brew install cocoapods
   flutter doctor
   ```
   As linhas **Flutter** e **Xcode** do `flutter doctor` precisam aparecer com ✓. Avisos de Android podem ser ignorados.

## 2. Baixar o projeto (uma vez só)

```bash
cd ~
git clone https://github.com/bpcoutinho1/bowie-app.git
cd bowie-app
```

Se você já clonou antes, atualize em vez de clonar de novo:

```bash
cd ~/bowie-app
git checkout main
git pull
```

## 3. Criar o `dart_defines.json` (uma vez só)

Esse arquivo guarda a URL e a chave anon do Supabase. Ele **não vai para o GitHub** (está no `.gitignore`), então precisa ser criado no Mac:

```bash
cd ~/bowie-app
cp dart_defines.example.json dart_defines.json
open -e dart_defines.json
```

Troque os dois valores pelos do Supabase (**Project Settings → API**: Project URL e a chave `anon` `public`) e salve.

No Supabase, antes do primeiro teste:

- **SQL Editor:** rode o conteúdo de `supabase/migrations/20260930120000_pets_and_tutors.sql`. Isso cria as tabelas.
- **Authentication → Sign In / Providers → Email:** desligue "Confirm email", para a conta funcionar sem precisar confirmar por email.

## 4. Abrir no Xcode

```bash
cd ~/bowie-app
./scripts/abrir-no-xcode.sh
```

O script baixa os pacotes, grava a configuração do Supabase para o Xcode e abre o projeto (`ios/Runner.xcworkspace`). Rode de novo sempre que fizer `git pull` ou mudar o `dart_defines.json`.

## 5. Rodar no simulador

1. No topo do Xcode, ao lado de **Runner**, escolha um simulador (por exemplo, iPhone 16).
2. Aperte **Play** (▶) ou `Cmd + R`. A primeira compilação leva alguns minutos.
3. Para testar o desbloqueio: no menu do simulador, **Features → Face ID → Enrolled**. Quando o app pedir o Face ID, use **Features → Face ID → Matching Face**.

## 6. Rodar no seu iPhone

Um Apple ID comum basta; não precisa da conta paga.

1. No Xcode, clique em **Runner** na lateral esquerda, depois no alvo **Runner** e na aba **Signing & Capabilities**.
2. Em **Team**, clique em "Add an Account…", entre com seu Apple ID e escolha "(Personal Team)".
3. Se aparecer erro no **Bundle Identifier**, troque por algo único, como `com.brunocoutinho.bowie`. Essa troca é só para o seu Mac: não faça commit dela.
4. No iPhone: **Ajustes → Privacidade e Segurança → Modo de Desenvolvedor**, ative e reinicie quando pedir.
5. Ligue o iPhone no Mac pelo cabo e toque em "Confiar".
6. No topo do Xcode, escolha o seu iPhone e aperte **Play**.
7. Na primeira vez, o iPhone bloqueia o app. Libere em **Ajustes → Geral → VPN e Gerenciamento de Dispositivos**, no seu Apple ID, e abra o app de novo.

Com o Apple ID gratuito, o app expira em 7 dias: é só apertar Play de novo. Com a conta Apple Developer, isso deixa de acontecer e o TestFlight fica disponível para outras pessoas.

## Pelo Terminal, sem o Xcode

Também funciona, depois do passo 3:

```bash
cd ~/bowie-app
open -a Simulator
flutter run --dart-define-from-file=dart_defines.json
```

## Problemas comuns

| Mensagem | O que fazer |
| --- | --- |
| "Esta versão ainda não está conectada ao servidor" na tela de login | O `dart_defines.json` está faltando ou com valores de exemplo. Corrija e rode `./scripts/abrir-no-xcode.sh` de novo. |
| `CocoaPods not installed` | `brew install cocoapods` e rode o script de novo. |
| "Signing for Runner requires a development team" | Faça o passo 6.1 e 6.2. |
| "No valid code signing certificates were found" no Terminal | O script antigo pedia certificado mesmo para o simulador. Rode `git pull` e o script de novo. Para o iPhone, faça o passo 6. |
| "Untrusted Developer" ou "Developer App Certificate is not trusted" | O app já foi instalado: confie no seu Apple ID no iPhone (passo 6.7) e aperte Play de novo. O iPhone precisa estar com internet. |
| "Your team has no devices from which to generate a provisioning profile" ou "No profiles for 'com.bowie.app.bowie' were found" | O Xcode está tentando instalar num iPhone que não está conectado. Para o simulador, escolha um simulador no topo do Xcode (e, se precisar, Team = None). Para o iPhone, conecte-o pelo cabo, toque em "Confiar" e ative o Modo de Desenvolvedor (passos 6.4 e 6.5). |
| "No pubspec.yaml file found" | O Terminal está fora da pasta do projeto. Rode `cd ~/bowie-app` (ou digite `cd ` e arraste a pasta do Finder para o Terminal) e repita o comando. |
| Email ou senha incorretos logo após criar a conta | Confira se "Confirm email" está desligado no Supabase. |
