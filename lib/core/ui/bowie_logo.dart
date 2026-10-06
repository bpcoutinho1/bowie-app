import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';

/// The brand's tagline (docs/design/brand-guidelines.md).
const brandTagline = 'Quem ama, lembra.';

/// The vertical lockup, in the negative version on dark backgrounds, with the
/// tagline below when [tagline] is true.
class BowieLogo extends StatelessWidget {
  const BowieLogo({super.key, this.height = 160, this.tagline = false});

  final double height;
  final bool tagline;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final logo = SvgPicture.asset(
      dark
          ? 'design/brand/logo/bowie-lockup-vertical-negative.svg'
          : 'design/brand/logo/bowie-lockup-vertical.svg',
      height: height,
      semanticsLabel: 'Bowie',
    );
    if (!tagline) return logo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(height: BowieSpacing.s3),
        Text(
          brandTagline,
          textAlign: TextAlign.center,
          style: BowieType.title3.copyWith(
            color: context.colors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
