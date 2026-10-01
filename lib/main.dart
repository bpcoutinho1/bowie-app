import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/app/app.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/core/config/app_config.dart';
import 'package:bowie/core/supabase/secure_session_storage.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final client = await openSupabase(config);
  final store = await PetLocalStore.open();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        supabaseClientProvider.overrideWithValue(client),
        petLocalStoreProvider.overrideWithValue(store),
      ],
      child: const BowieApp(),
    ),
  );
}

Future<SupabaseClient?> openSupabase(AppConfig config) async {
  if (!config.isConfigured) return null;
  final projectRef = Uri.parse(config.supabaseUrl).host.split('.').first;
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(
        persistSessionKey: 'sb-$projectRef-auth-token',
      ),
    ),
  );
  return Supabase.instance.client;
}
