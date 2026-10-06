import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/shell.dart';
import 'package:bowie/features/auth/presentation/login_page.dart';
import 'package:bowie/features/auth/presentation/unlock_page.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/ui/bowie_logo.dart';
import 'package:bowie/features/contacts/presentation/contact_form_page.dart';
import 'package:bowie/features/contacts/presentation/contacts_page.dart';
import 'package:bowie/features/diary/presentation/diary_page.dart';
import 'package:bowie/features/diary/presentation/event_form_page.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/presentation/card_reading_page.dart';
import 'package:bowie/features/health/presentation/dose_form_page.dart';
import 'package:bowie/features/health/presentation/dose_history_page.dart';
import 'package:bowie/features/health/presentation/health_page.dart';
import 'package:bowie/features/health/presentation/medication_form_page.dart';
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
                routes: [
                  GoRoute(
                    path: 'carteirinha',
                    builder: (context, state) {
                      final petId = state.uri.queryParameters['pet'];
                      return petId == null
                          ? const HealthPage()
                          : CardReadingPage(petId: petId);
                    },
                  ),
                  GoRoute(
                    path: 'medicacoes/nova',
                    builder: (context, state) => MedicationFormPage(
                      petId: state.uri.queryParameters['pet'],
                    ),
                  ),
                  GoRoute(
                    path: 'medicacoes/:id',
                    builder: (context, state) => MedicationFormPage(
                      medicationId: state.pathParameters['id'],
                    ),
                  ),
                  GoRoute(
                    path: 'doses/nova',
                    builder: (context, state) {
                      final query = state.uri.queryParameters;
                      return DoseFormPage(
                        petId: query['pet'],
                        kind: DoseKind.values
                            .where((kind) => kind.name == query['tipo'])
                            .firstOrNull,
                        name: query['nome'],
                      );
                    },
                  ),
                  GoRoute(
                    path: 'doses/:id',
                    builder: (context, state) =>
                        DoseHistoryPage(doseId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'editar',
                        builder: (context, state) =>
                            DoseFormPage(doseId: state.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/diario',
                builder: (context, state) => const DiaryPage(),
                routes: [
                  GoRoute(
                    path: 'novo',
                    builder: (context, state) {
                      final query = state.uri.queryParameters;
                      final day = DateTime.tryParse(query['dia'] ?? '');
                      return EventFormPage(
                        petId: query['pet'],
                        day: day == null ? null : dayOf(day),
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        EventFormPage(eventId: state.pathParameters['id']),
                  ),
                ],
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
                    path: 'contatos',
                    builder: (context, state) => const ContactsPage(),
                    routes: [
                      GoRoute(
                        path: 'novo',
                        builder: (context, state) => ContactFormPage(
                          houseId: state.uri.queryParameters['casa'],
                        ),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => ContactFormPage(
                          contactId: state.pathParameters['id'],
                        ),
                      ),
                    ],
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
    // Matches the native splash, so opening the app shows one steady screen.
    return const Scaffold(
      body: Center(child: BowieLogo(height: 200, tagline: true)),
    );
  }
}
