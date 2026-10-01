import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';

Future<void> signOut(WidgetRef ref) async {
  await ref.read(authRepositoryProvider).signOut();
  ref.read(unlockedProvider.notifier).lock();
}
