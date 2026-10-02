import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/core/ui/notifications_button.dart';

class HealthPage extends StatelessWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saúde'),
        actions: const [NotificationsButton()],
      ),
      body: const EmptyState(
        icon: LucideIcons.heartPulse,
        title: 'Em construção',
        message:
            'Vacinas, vermífugos, remédios e incidentes vão aparecer aqui.',
      ),
    );
  }
}
