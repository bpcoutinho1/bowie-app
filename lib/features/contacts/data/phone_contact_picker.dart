import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

/// A person or place chosen in the phone's agenda.
class PickedContact {
  const PickedContact({required this.name, this.phone});

  final String name;

  /// As written in the agenda: "+55 11 98765-4321".
  final String? phone;
}

/// The phone's own contact picker. The app gets only the contact the person
/// chooses: no permission to read the agenda is asked
/// (docs/produto/contatos.md#importar-da-agenda).
abstract interface class PhoneContactPicker {
  /// Null when the person closes the picker.
  Future<PickedContact?> pick();
}

class NativePhoneContactPicker implements PhoneContactPicker {
  NativePhoneContactPicker([FlutterNativeContactPicker? picker])
    : _picker = picker ?? FlutterNativeContactPicker();

  final FlutterNativeContactPicker _picker;

  @override
  Future<PickedContact?> pick() async {
    try {
      // The person chooses a number when the contact has more than one.
      final contact = await _picker.selectPhoneNumber();
      if (contact == null) return null;
      final phone =
          contact.selectedPhoneNumber ?? contact.phoneNumbers?.firstOrNull;
      return PickedContact(
        name: contact.fullName?.trim() ?? '',
        phone: phone?.trim(),
      );
    } on PlatformException {
      throw const ContactPickerException();
    }
  }
}

class ContactPickerException implements Exception {
  const ContactPickerException();
}
