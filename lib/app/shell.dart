import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The five tabs at the bottom of the app.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.house), label: 'Início'),
          NavigationDestination(
            icon: Icon(LucideIcons.heartPulse),
            label: 'Saúde',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.notebookPen),
            label: 'Diário',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.shoppingCart),
            label: 'Compras',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.pawPrint),
            label: 'Pets',
          ),
        ],
      ),
    );
  }
}
