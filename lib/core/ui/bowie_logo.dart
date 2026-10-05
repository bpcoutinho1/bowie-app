import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The vertical lockup, in the negative version on dark backgrounds.
class BowieLogo extends StatelessWidget {
  const BowieLogo({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      dark
          ? 'design/brand/logo/bowie-lockup-vertical-negative.svg'
          : 'design/brand/logo/bowie-lockup-vertical.svg',
      height: height,
      semanticsLabel: 'Bowie',
    );
  }
}
