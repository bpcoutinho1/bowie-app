import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/router.dart';
import 'package:bowie/features/reminders/data/reminder_service.dart';

final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => LocalNotificationsGateway(),
);

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    ref.watch(petLocalStoreProvider),
    ref.watch(notificationGatewayProvider),
  );
});

/// Whether the phone shows Bowie's notifications. Refreshed by invalidating.
final notificationsEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(notificationGatewayProvider).isEnabled();
});

/// Watched by the app: reschedules the reminders when the account or the
/// data changes, clears them on sign out, and opens the screen of a tapped
/// reminder.
final reminderControllerProvider = Provider<void>((ref) {
  final service = ref.watch(reminderServiceProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    unawaited(service.clear());
    return;
  }

  Timer? pending;
  void schedule() {
    // Saving a reading writes several doses at once: wait for the burst.
    pending?.cancel();
    pending = Timer(const Duration(seconds: 2), () => service.reschedule(user));
  }

  schedule();
  final changes = ref.watch(petLocalStoreProvider).changes.listen((_) {
    schedule();
  });
  final taps = service.gateway.taps.listen((route) {
    ref.read(routerProvider).go(route);
  });
  ref.onDispose(() {
    pending?.cancel();
    changes.cancel();
    taps.cancel();
  });
});

/// Opens the screen of the reminder that opened the app, once the app is
/// ready (after the device unlock).
Future<void> openLaunchReminder(
  NotificationGateway gateway,
  GoRouter router,
) async {
  final route = await gateway.takeLaunchRoute();
  if (route != null) router.go(route);
}
