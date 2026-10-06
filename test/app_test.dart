import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/auth/presentation/login_page.dart';

/// Pumps the login screen on a phone-sized view.
Future<void> pumpLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const LoginPage(),
      ),
    ),
  );
}

void main() {
  testWidgets('login explains how to connect Supabase', (tester) async {
    await pumpLogin(tester);

    expect(find.bySemanticsLabel('Bowie'), findsOneWidget);
    expect(find.text('Quem ama, lembra.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
    expect(
      find.textContaining('não está conectada ao servidor'),
      findsOneWidget,
    );
  });

  testWidgets('login switches to account creation', (tester) async {
    await pumpLogin(tester);

    final toggle = find.text('Ainda não tem conta? Criar conta');
    await tester.scrollUntilVisible(
      toggle,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Criar conta'), findsOneWidget);
    expect(find.text('Já tem conta? Entrar'), findsOneWidget);
  });

  test('both themes expose the brand tokens', () {
    final light = buildTheme(Brightness.light);
    final dark = buildTheme(Brightness.dark);

    expect(light.extension<BowieColors>(), BowieColors.light);
    expect(dark.extension<BowieColors>(), BowieColors.dark);
    expect(light.colorScheme.primary, BowieColors.light.primary);
    expect(dark.colorScheme.primary, BowieColors.dark.primary);
    expect(light.scaffoldBackgroundColor, BrandColors.mist);
  });
}
