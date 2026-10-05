import 'package:flutter/material.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';

/// A surface card with the brand shadow, as the design rules ask.
class BowieCard extends StatelessWidget {
  const BowieCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(BowieRadius.lg));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: radius,
        boxShadow: BowieShadow.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: radius, child: child),
      ),
    );
  }
}
