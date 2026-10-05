# Fluxo de telas e autenticação

O acesso ao app tem duas etapas:

1. **Conta no Supabase**: email e senha, feito uma vez. A sessão fica salva no armazenamento seguro do aparelho.
2. **Desbloqueio do aparelho**: Face ID, Touch ID, impressão digital, reconhecimento facial ou código do aparelho, a cada vez que o app é aberto.

## O portão de autenticação (`AuthGate`)

O provider `authGateProvider` (`lib/app/providers.dart`) junta três sinais e decide em que estado o app está:

| Sinal | Origem |
| --- | --- |
| Sessão | `authSessionProvider`: sessão atual do Supabase e o stream `onAuthStateChange`. |
| Suporte a desbloqueio | `deviceSupportedProvider`: `LocalAuthentication.isDeviceSupported()`. |
| Desbloqueado | `unlockedProvider`: um booleano em memória, começa `false`. |

```mermaid
stateDiagram-v2
    [*] --> loading
    loading --> signedOut: sem sessão
    loading --> locked: com sessão e aparelho suporta desbloqueio
    loading --> ready: com sessão e aparelho sem suporte
    signedOut --> locked: login / cadastro com sessão
    locked --> ready: desbloqueio ok
    ready --> signedOut: sign out
    locked --> signedOut: sign out
```

Regras:

- Enquanto a sessão ou o suporte do aparelho estão carregando: `loading`.
- Sem usuário (ou usuário sem email): `signedOut`.
- Com usuário, aparelho com suporte e ainda não desbloqueado: `locked`.
- Caso contrário: `ready`.

Se o aparelho não tem nenhuma forma de desbloqueio, o app vai direto para `ready`.

## Rotas

Definidas em `lib/app/router.dart`. A função `redirectFor` leva o usuário para a tela certa conforme o `AuthGate`. O router é reavaliado sempre que o `AuthGate` muda.

| Rota | Tela | Quando |
| --- | --- | --- |
| `/loading` | `LoadingPage` (spinner) | `AuthGate.loading` |
| `/login` | `LoginPage` | `AuthGate.signedOut` |
| `/unlock` | `UnlockPage` | `AuthGate.locked` |
| `/inicio` | `HomePage` (aba Início) | `AuthGate.ready` |
| `/saude` | `HealthPage` (aba Saúde, em construção) | `AuthGate.ready` |
| `/compras` | `ShoppingPage` (aba Compras, em construção) | `AuthGate.ready` |
| `/pets` | `PetsPage` (aba Pets) | `AuthGate.ready` |
| `/pets/new` | `PetPage` sem id (novo pet) | `AuthGate.ready` |
| `/pets/:id` | `PetPage` com id (detalhes) | `AuthGate.ready` |
| `/notificacoes` | `NotificationsPage` (aberta pelo sino, ainda vazia) | `AuthGate.ready` |

Em `ready`, quem estiver em `/login`, `/unlock` ou `/loading` é levado para `/inicio` (`homeLocation`). Nos outros estados, qualquer rota leva para a tela do estado.

## Abas

Depois do desbloqueio, o app mostra quatro abas na parte de baixo (`AppShell`, em `lib/app/shell.dart`), cada uma com a própria pilha de navegação (`StatefulShellRoute`):

- **Início**: os pets da pessoa e convites pendentes. Sem pets, convida a cadastrar o primeiro.
- **Saúde** e **Compras**: telas de "Em construção".
- **Pets**: lista de pets, convites, sincronização e "Sair".

O sino no topo das abas abre `/notificacoes`, ainda vazia.

## Login e cadastro (`LoginPage`)

- A tela mostra o logo e alterna entre "Entrar" e "Criar conta".
- `AuthRepository` valida antes de chamar o Supabase: email com formato válido e senha com pelo menos 6 caracteres. O email é normalizado (sem espaços, minúsculo).
- No cadastro, se o Supabase não devolver sessão (confirmação de email ligada), a tela volta para o modo de login e pede para confirmar o email.
- Erros do Supabase viram `AppFailure` e aparecem em vermelho na tela. As mensagens mais comuns são traduzidas pelo código do erro (`authMessage` em `auth_repository.dart`), como "Email ou senha incorretos."; as demais viram "Algo deu errado. Tente de novo." Uma falha de rede (o pedido nem chegou ao servidor) pede para conferir a internet; um erro do servidor (status 500 ou acima) mostra o código do erro, como "O servidor teve um problema (erro 500)". No modo de desenvolvimento, o status e o código do erro aparecem no Terminal.
- Sem configuração do Supabase, os campos ficam desabilitados e a tela explica como criar o `dart_defines.json`.

Quando o login dá certo, o stream de autenticação emite o usuário, o `AuthGate` muda e o router redireciona. A tela de login não navega sozinha.

## Desbloqueio (`UnlockPage`)

- Ao abrir, a tela já pede o desbloqueio (`DeviceLock.unlock`).
- Aceita biometria ou código do aparelho (`biometricOnly: false`). No Android, o código pode ser PIN, padrão ou senha.
- O pedido do sistema aparece em português ("Desbloquear o Bowie", "Cancelar").
- Se o usuário cancelar, aparece "O desbloqueio foi cancelado." e o botão "Desbloquear" permite tentar de novo.
- Se o aparelho não tem código configurado, a mensagem pede para configurar um.
- Também há um botão "Sair da conta".

O estado "desbloqueado" fica só em memória. Ele volta a `false` quando o app é encerrado e reaberto, ou no sign out. Mandar o app para segundo plano e voltar **não** bloqueia de novo.

## Sessão no armazenamento seguro

`SecureSessionStorage` (`lib/core/supabase/secure_session_storage.dart`) substitui o armazenamento padrão do Supabase. A sessão é gravada com a chave `sb-<project-ref>-auth-token`: no Keychain do iOS, ou, no Android, em armazenamento cifrado com uma chave do Android Keystore. O Supabase cuida da renovação do token.

## Sign out

`signOut` (`lib/features/auth/presentation/sign_out.dart`) encerra a sessão no Supabase e volta `unlockedProvider` para `false`. O `AuthGate` vai para `signedOut` e o router leva ao login. O banco local **não** é apagado (veja [Limitações](sincronizacao.md#limitações-conhecidas)).
