import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/theme.dart';
import 'package:bowie/features/notifications/presentation/notices_providers.dart';

/// The bell in the top bar, with the number of notices waiting.
class NotificationsButton extends ConsumerWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(vaccineNoticesProvider).asData?.value.length ?? 0;
    final colors = context.colors;
    return IconButton(
      tooltip: switch (count) {
        0 => 'Notificações',
        1 => 'Notificações: 1 aviso',
        _ => 'Notificações: $count avisos',
      },
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: colors.danger,
        textColor: colors.textOnPrimary,
        child: const Icon(LucideIcons.bell),
      ),
      onPressed: () => context.push('/notificacoes'),
    );
  }
}
