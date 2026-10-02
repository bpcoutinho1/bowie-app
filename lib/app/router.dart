import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/shell.dart';
import 'package:bowie/features/auth/presentation/login_page.dart';
import 'package:bowie/features/auth/presentation/unlock_page.dart';
import 'package:bowie/features/health/presentation/health_page.dart';
import 'package:bowie/features/home/presentation/home_page.dart';
import 'package:bowie/features/notifications/presentation/notifications_page.dart';
import 'package:bowie/features/pets/presentation/pet_page.dart';
import 'package:bowie/features/pets/presentation/pets_page.dart';
import 'package:bowie/features/shopping/presentation/shopping_page.dart';

/// Where a ready session lands.
const homeLocation = '/inicio';

String? redirectFor(AuthGate gate, String location) {
  return switch (gate) {
    AuthGate.loading => location == '/loading' ? null : '/loading',
    AuthGate.signedOut => location == '/login' ? null : '/login',
    AuthGate.locked => location == '/unlock' ? null : '/unlock',
    AuthGate.ready =>
      location == '/login' || location == '/unlock' || location == '/loading'
          ? homeLocation
          : null,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authGateProvider, (_, _) {
    refresh.value++;
  });

  final router = GoRouter(
    initialLocation: '/loading',
    refreshListenable: refresh,
    redirect: (context, state) {
      return redirectFor(ref.read(authGateProvider), state.matchedLocation);
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/unlock', builder: (context, state) => const UnlockPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: homeLocation,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/saude',
                builder: (context, state) => const HealthPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/compras',
                builder: (context, state) => const ShoppingPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pets',
                builder: (context, state) => const PetsPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const PetPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      return PetPage(petId: state.pathParameters['id']);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/notificacoes',
        builder: (context, state) => const NotificationsPage(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
