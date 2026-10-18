import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/router.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/pets/data/pet_sync_controller.dart';
import 'package:bowie/features/reminders/presentation/reminder_providers.dart';

class BowieApp extends ConsumerWidget {
  const BowieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(syncControllerProvider);
    ref.watch(reminderControllerProvider);
    ref.listen(authGateProvider, (previous, next) {
      if (next == AuthGate.ready && previous != AuthGate.ready) {
        ref.read(syncControllerProvider.notifier).sync();
        unawaited(
          openLaunchReminder(ref.read(notificationGatewayProvider), router),
        );
      }
    });

    return MaterialApp.router(
      title: 'Bowie',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
