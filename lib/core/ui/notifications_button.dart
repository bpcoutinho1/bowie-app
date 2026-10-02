import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The bell in the top bar. The unread badge arrives with the notification center.
class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notificações',
      icon: const Icon(LucideIcons.bell),
      onPressed: () => context.push('/notificacoes'),
    );
  }
}
