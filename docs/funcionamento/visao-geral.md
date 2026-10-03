# Visão geral

O Bowie é um app de iOS e Android para pessoas que dividem o cuidado de um pet. Hoje ele cobre a base: contas, pets e quem foi convidado para cuidar de cada pet. O acompanhamento de rotinas (alimentação, passeios, remédios) ainda não existe.

## O que o usuário consegue fazer

- Criar uma conta ou entrar com email e senha.
- Desbloquear o app com Face ID, Touch ID, impressão digital, reconhecimento facial ou o código do aparelho.
- Cadastrar um pet e renomeá-lo.
- Convidar outra pessoa, pelo email, para cuidar de um pet (só o dono pode convidar).
- Ver e aceitar convites recebidos.
- Usar tudo isso sem internet: as alterações ficam no aparelho e sobem quando houver conexão.

## Pilha

| Peça | Uso |
| --- | --- |
| Flutter / Dart | App para iOS (`ios/`) e Android (`android/`). |
| [Riverpod](https://riverpod.dev/) (`flutter_riverpod`) | Injeção de dependências e estado. |
| [go_router](https://pub.dev/packages/go_router) | Rotas e redirecionamentos conforme o estado de autenticação. |
| [Supabase](https://supabase.com/) (`supabase_flutter`) | Autenticação por email e banco Postgres com RLS. |
| `flutter_secure_storage` | Guarda a sessão do Supabase no Keychain (iOS) ou em armazenamento cifrado com o Android Keystore. |
| `local_auth` | Desbloqueio com biometria ou código do aparelho. |
| `sqflite` | Banco SQLite local com pets, tutores e a fila de envio (outbox). |
| `connectivity_plus` | Detecta se o aparelho está online. |

## Organização do código

```
lib/
  main.dart              inicialização: config, Supabase, SQLite, ProviderScope
  app/                   app.dart, router.dart, theme.dart, providers.dart
  core/
    config/              AppConfig (lê SUPABASE_URL e SUPABASE_ANON_KEY)
    error/               AppFailure, o erro que a interface mostra
    supabase/            SecureSessionStorage (sessão no armazenamento seguro)
    sync/                NetworkStatus (online/offline)
  features/
    auth/                login, cadastro, desbloqueio do aparelho, sign out
    pets/                domínio (Pet, PetTutor), dados (local, remoto, sync) e telas
android/                 projeto Android (Gradle)
ios/                     projeto iOS (Xcode)
supabase/migrations/     esquema do banco, políticas de RLS
test/                    testes de widget e de sincronização
```

Cada feature segue três camadas:

- `domain/`: modelos puros (`Pet`, `PetTutor`, `AppUser`).
- `data/`: repositórios, acesso ao SQLite, à API do Supabase e a sincronização.
- `presentation/`: telas e widgets.

Todos os providers globais ficam em `lib/app/providers.dart`.

## Plataformas

| | iOS | Android |
| --- | --- | --- |
| Identificador | `com.bowie.app.bowie` | `com.bowie.app.bowie` |
| Versão mínima | iOS 13 | Android 7.0 (API 24), exigida por `local_auth` e `flutter_secure_storage` |
| Ícone | `design/brand/app-icon/icon-1024.png` | Adaptativo: `adaptive-foreground-1024.png` sobre `#6FA8DC` |
| Splash | `splash-icon-1024.png` sobre `#F4F6F8` | Igual; no Android 12+ o sistema usa o rosto do ícone adaptativo sobre `#F4F6F8` |

Ícone e splash são gerados por `flutter_launcher_icons` e `flutter_native_splash`, configurados no `pubspec.yaml`.

Ajustes do Android que os plugins exigem:

- `MainActivity` estende `FlutterFragmentActivity`, e os temas são `Theme.AppCompat` (com a dependência `androidx.appcompat`). Sem isso, o `local_auth` não mostra o pedido de biometria.
- Permissões `INTERNET` e `USE_BIOMETRIC` no `AndroidManifest.xml`.
- `android:allowBackup="false"`: o backup automático do Android restauraria a sessão cifrada em outro aparelho sem a chave, e o `flutter_secure_storage` falharia ao ler. Também evita que dados do app vão para o backup do Google.
- Builds de release são assinadas com `android/key.properties`, que não vai para o git (veja o README da raiz).

## Inicialização

`lib/main.dart` faz, em ordem:

1. Lê a configuração de `--dart-define` (`AppConfig.fromEnvironment`).
2. Se a configuração for válida, inicializa o Supabase com `SecureSessionStorage`. Se não for, o cliente fica `null` e o app abre na tela de login com um aviso e os campos desabilitados.
3. Abre o banco SQLite `bowie.db` (`PetLocalStore.open`).
4. Sobe o `ProviderScope` injetando config, cliente e banco, e mostra `BowieApp`.

`BowieApp` (`lib/app/app.dart`) monta o router e mantém o controlador de sincronização vivo. Quando o estado de autenticação passa a `ready`, ele dispara uma sincronização.
