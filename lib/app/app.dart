import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/router.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/pets/data/pet_sync_controller.dart';

class BowieApp extends ConsumerWidget {
  const BowieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(syncControllerProvider);
    ref.listen(authGateProvider, (previous, next) {
      if (next == AuthGate.ready && previous != AuthGate.ready) {
        ref.read(syncControllerProvider.notifier).sync();
      }
    });

    return MaterialApp.router(
      title: 'Bowie',
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
