import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/contacts/data/phone_contact_picker.dart';
import 'package:bowie/features/contacts/presentation/contact_form_page.dart';
import 'package:bowie/features/contacts/presentation/contacts_providers.dart';

class FakeContactPicker implements PhoneContactPicker {
  FakeContactPicker(this.result, {this.fails = false});

  final PickedContact? result;
  final bool fails;

  @override
  Future<PickedContact?> pick() async {
    if (fails) throw const ContactPickerException();
    return result;
  }
}

void main() {
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');

  Future<void> pump(WidgetTester tester, PhoneContactPicker picker) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(bruno),
          phoneContactPickerProvider.overrideWithValue(picker),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const ContactFormPage(houseId: 'bruno-1'),
        ),
      ),
    );
    await tester.tap(find.text('Importar da agenda do celular'));
    await tester.pumpAndSettle();
  }

  String field(WidgetTester tester, String label) => tester
      .widget<TextField>(
        find.ancestor(of: find.text(label), matching: find.byType(TextField)),
      )
      .controller!
      .text;

  testWidgets('the agenda fills the name and the phone, in the app format', (
    tester,
  ) async {
    await pump(
      tester,
      FakeContactPicker(
        const PickedContact(
          name: 'Clínica Vet Amigo',
          phone: '+55 11 98765-4321',
        ),
      ),
    );
    expect(field(tester, 'Nome'), 'Clínica Vet Amigo');
    expect(field(tester, 'Telefone (opcional)'), '(11) 98765-4321');
    expect(find.textContaining('Nome e telefone preenchidos'), findsOneWidget);
  });

  testWidgets('closing the agenda changes nothing', (tester) async {
    await pump(tester, FakeContactPicker(null));
    expect(field(tester, 'Nome'), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a number from abroad is kept for the person to check', (
    tester,
  ) async {
    await pump(
      tester,
      FakeContactPicker(
        const PickedContact(name: 'Dog Hotel', phone: '+1 415 555 0100'),
      ),
    );
    expect(field(tester, 'Telefone (opcional)'), '+1 415 555 0100');
    expect(find.textContaining('Confira o telefone'), findsOneWidget);
  });

  testWidgets('when the agenda cannot open, the form says so', (tester) async {
    await pump(tester, FakeContactPicker(null, fails: true));
    expect(
      find.textContaining('Não foi possível abrir a agenda'),
      findsOneWidget,
    );
  });
}
