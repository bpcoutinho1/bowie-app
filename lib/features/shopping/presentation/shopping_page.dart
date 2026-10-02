import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/core/ui/notifications_button.dart';

class ShoppingPage extends StatelessWidget {
  const ShoppingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras'),
        actions: const [NotificationsButton()],
      ),
      body: const EmptyState(
        icon: LucideIcons.shoppingCart,
        title: 'Em construção',
        message: 'A lista de compras da casa vai aparecer aqui.',
      ),
    );
  }
}
