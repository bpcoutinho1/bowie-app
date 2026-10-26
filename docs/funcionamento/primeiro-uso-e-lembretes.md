# Primeiro uso e lembretes

A regra de produto está em [primeiro uso](../produto/primeiro-uso.md) e em [notificações](../produto/notificacoes.md#lembretes-no-celular).

## Caminho guiado

`lib/features/onboarding/presentation/onboarding_pages.dart`:

| Rota | Tela |
| --- | --- |
| `/inicio` sem pet nem convite | `WelcomeView`: "Boas-vindas ao Bowie", os três passos e "Cadastrar meu pet". Logo depois de entrar, enquanto a primeira sincronização da conta não termina (`SyncStatus.checkedFor`), mostra "Buscando os seus pets": o celular vazio pode só ainda não ter recebido os pets do servidor |
| `/boas-vindas/pet` | `PetPage(onboarding: true)`: o formulário de sempre, com "Passo 1 de 3". Ao salvar, vai para o passo 2 em vez de abrir o pet |
| `/boas-vindas/vacinas?pet=` | `OnboardingVaccinesPage`: no Premium, "Fotografar a carteirinha" (`CardReadingPage`), "Registrar à mão" (`DoseFormPage`) ou "Fazer depois"; no grátis, "Registrar uma vacina" primeiro e "Ler a carteirinha com IA (Premium)". Com vacinas, lista cada uma com o status e mostra "Continuar" |
| `/boas-vindas/pronto?pet=` | `OnboardingDonePage`: `NotificationsPrompt` e os extras (remédios, alergias e cuidados, exames e consultas) |

As rotas ficam fora das abas. A leitura da carteirinha e os formulários abrem por cima do caminho (`Navigator.push` no navegador raiz) e fecham sozinhos ao salvar, voltando para ele.

No Início, cada pet mostra, nesta ordem: o aniversário perto, os remédios de hoje ("Remédios de hoje: 2 de 5 dados"), a vacina mais urgente (só quando há vacina registrada) e o próximo agendamento (`HomePage`, decisão de 26 de outubro de 2026: os remédios do dia vêm antes da vacina). Cada pet com algo essencial faltando mostra "Ficha do Bowie: 2 de 4" (`petChecklist`, em `lib/features/onboarding/domain/pet_checklist.dart`): vacinas, foto, nascimento e peso, cada item faltando como um botão para a tela onde se preenche (vacinas: a leitura no Premium, o formulário no grátis). Se os avisos estão desligados, o Início mostra `NotificationsPrompt` com "Agora não"; a escolha fica no celular (`Flags`, chave `reminders_tip_dismissed_v1`).

## Lembretes

`lib/features/reminders/`:

- `planReminders` (domínio, sem efeitos): para cada pet, a dose mais recente de cada vacina, vermífugo ou antipulgas gera um lembrete `remindDays` dias antes do vencimento (7, 14 ou 30, escolhido no registro), às 9h; e o aniversário (só com data exata) gera um 7 dias antes, às 9h, no ano que vem se o deste ano já passou. Lembretes no passado ficam de fora. Ordena pelo horário e fica com os 60 primeiros (o iOS guarda até 64 por app).
- `LocalNotificationsGateway` (`flutter_local_notifications`): agenda no fuso do celular (`flutter_timezone`, com São Paulo como reserva), sem alarme exato no Android (`inexactAllowWhileIdle`, que dispensa permissão especial). O pedido de permissão do iOS não acontece ao abrir o app; só quando a pessoa toca em "Ativar avisos".
- `ReminderService.reschedule` lê os pets e as doses do SQLite e troca todos os lembretes agendados. `clear` apaga todos, ao sair da conta.
- `reminderControllerProvider`, observado pelo `BowieApp`: reagenda ao entrar e 2 segundos depois de qualquer mudança no banco local (salvar uma leitura grava várias doses de uma vez), e apaga ao sair. Tocar num lembrete abre a rota dele (`/saude` ou `/pets/:id`); o que abriu o app é aberto depois do desbloqueio.

Nada é enviado a servidor: os lembretes existem só no celular de cada tutor.

## Configuração nativa

- Android: desugaring (`coreLibraryDesugaring` em `android/app/build.gradle.kts`), a permissão `RECEIVE_BOOT_COMPLETED` e os receivers do plugin no `AndroidManifest.xml`, para os lembretes voltarem depois de reiniciar o celular. O ícone da notificação é o do app (`@mipmap/ic_launcher`).
- iOS: `AppDelegate.swift` define o `UNUserNotificationCenter` delegate, para o lembrete aparecer também com o app aberto.

## Vacinas que faltam, no sino

Regra de produto: [notificações](../produto/notificacoes.md#vacinas-que-faltam).

- `vaccineNotice` (`lib/features/notifications/domain/vaccine_notice.dart`, sem efeitos): a partir do 7º dia depois do cadastro do pet (`Pet.createdAt`, contado em dias do calendário), lista as vacinas essenciais sem nenhuma dose registrada, em ordem de importância. Cão: Raiva, V8 ou V10, Tosse dos canis, Giárdia. Gato: Raiva, V3, V4 ou V5. O nome da dose conta sem acento nem maiúscula e por partes (`EssentialVaccine.patterns`): "Antirrábica", "V10 (déctupla)" e "Giardíase" valem. Só doses do tipo vacina contam. Sem espécie ou sem data de cadastro, não há aviso.
- `vaccineNoticesProvider` (`notices_providers.dart`): os avisos dos pets da conta, refeitos quando a saúde muda. "Não lembrar mais" guarda a escolha no celular (`Flags`, chave `vaccine_notice_off_<id do pet>`).
- `NotificationsButton` (`lib/core/ui/notifications_button.dart`): o sino do topo ganha um marcador `danger` com o número de avisos, e o rótulo "Notificações: 1 aviso".
- `/notificacoes` (`NotificationsPage`): um card por pet, com o título ("O Bowie ainda não tem todas as vacinas cadastradas."), o que falta ("Faltam: Raiva, V8 ou V10, Tosse dos canis e Giárdia."), "Registrar vacina: Raiva" (abre o formulário com o nome preenchido), "Ler a carteirinha" no Premium e "Não lembrar mais". Sem avisos, o estado vazio de sempre.
- `Pet.createdAt` vem da coluna `pets.created_at` (servidor, migração `20261026120000_weight_and_pet_dates.sql`) e da versão 13 do banco do celular. O servidor marca a data na criação e não deixa mudar; o celular usa a sua até a primeira sincronização.
