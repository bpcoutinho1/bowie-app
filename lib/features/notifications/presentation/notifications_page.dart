import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/core/ui/empty_state.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: const EmptyState(
        icon: LucideIcons.bell,
        title: 'Nenhuma notificação por enquanto',
        message:
            'Convites, lembretes e o que os outros tutores fizerem vão aparecer aqui.',
      ),
    );
  }
}
