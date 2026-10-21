import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/features/health/domain/vaccine_dose.dart';

IconData doseKindIcon(DoseKind kind) => switch (kind) {
  DoseKind.vaccine => LucideIcons.syringe,
  DoseKind.dewormer => LucideIcons.pill,
  DoseKind.fleaTick => LucideIcons.bug,
};
