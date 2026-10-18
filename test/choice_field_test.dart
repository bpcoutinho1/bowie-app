import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bowie/app/theme.dart';
import 'package:bowie/features/health/domain/health_note.dart';
import 'package:bowie/features/health/presentation/health_note_form_page.dart';

void main() {
  testWidgets('the kind is one field that opens the list of options', (
    tester,
  ) async {
    // iPhone width, with the system text a size larger.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const HealthNoteFormPage(
            petId: 'p1',
            kind: HealthNoteKind.diet,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // "Alimentação" in one line: no word broken in two.
    final chosen = find.descendant(
      of: find.byType(InputDecorator).first,
      matching: find.text('Alimentação'),
    );
    expect(chosen, findsOneWidget);
    final line = tester.renderObject<RenderParagraph>(chosen);
    // The whole word fits in the width it got.
    expect(
      line.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(line.size.width),
    );
    expect(find.text('O que come?'), findsOneWidget);

    await tester.tap(chosen);
    await tester.pumpAndSettle();
    expect(find.text('Condição de saúde ou comportamento'), findsOneWidget);
    expect(find.text('Alimento, remédio ou outra substância'), findsOneWidget);
    await tester.tap(find.text('Alergia').last);
    await tester.pumpAndSettle();

    expect(find.text('Alergia a quê?'), findsOneWidget);
    expect(find.text('Alimentação'), findsNothing);
  });
}
