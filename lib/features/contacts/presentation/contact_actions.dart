import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/contacts/domain/contact.dart';

IconData categoryIcon(ContactCategory category) => switch (category) {
  ContactCategory.vet => LucideIcons.stethoscope,
  ContactCategory.nutritionist => LucideIcons.apple,
  ContactCategory.physio => LucideIcons.activity,
  ContactCategory.trainer => LucideIcons.graduationCap,
  ContactCategory.daycare => LucideIcons.school,
  ContactCategory.hotel => LucideIcons.hotel,
  ContactCategory.groomer => LucideIcons.scissors,
  ContactCategory.walker => LucideIcons.footprints,
  ContactCategory.lab => LucideIcons.flaskConical,
  ContactCategory.petShop => LucideIcons.store,
  ContactCategory.other => LucideIcons.userRound,
};

/// Opens the phone, WhatsApp, mail or maps app. Tells the person when the
/// phone cannot (a simulator without a phone app, for example).
Future<void> openContactLink(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir neste celular.')),
    );
  }
}

Uri callUri(String phone) => Uri(scheme: 'tel', path: phone);

Uri whatsAppUri(String phone) => Uri.parse('https://wa.me/55$phone');

Uri mailUri(String email) => Uri(scheme: 'mailto', path: email);

Uri mapUri(String address) => Uri.https('www.google.com', '/maps/search/', {
  'api': '1',
  'query': address,
});

/// The ways to reach a contact, as a sheet: call, WhatsApp, e-mail, map.
Future<void> showContactActions(
  BuildContext context,
  Contact contact, {
  VoidCallback? onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final colors = sheetContext.colors;
      final phone = contact.phone;
      final email = contact.email;
      final address = contact.address;
      void open(Uri uri) {
        Navigator.of(sheetContext).pop();
        openContactLink(context, uri);
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BowieSpacing.s4,
                0,
                BowieSpacing.s4,
                BowieSpacing.s2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: BowieType.title3.copyWith(color: colors.text),
                  ),
                  Text(
                    contact.category.label,
                    style: BowieType.callout.copyWith(color: colors.textMuted),
                  ),
                  if (contact.notes != null) ...[
                    const SizedBox(height: BowieSpacing.s2),
                    Text(
                      contact.notes!,
                      style: BowieType.callout.copyWith(color: colors.text),
                    ),
                  ],
                ],
              ),
            ),
            if (phone != null) ...[
              ListTile(
                leading: const Icon(LucideIcons.phone),
                title: Text('Ligar para ${formatPhone(phone)}'),
                onTap: () => open(callUri(phone)),
              ),
              if (isMobile(phone))
                ListTile(
                  leading: const Icon(LucideIcons.messageCircle),
                  title: const Text('Mandar mensagem no WhatsApp'),
                  onTap: () => open(whatsAppUri(phone)),
                ),
            ],
            if (email != null)
              ListTile(
                leading: const Icon(LucideIcons.mail),
                title: Text('Escrever para $email'),
                onTap: () => open(mailUri(email)),
              ),
            if (address != null)
              ListTile(
                leading: const Icon(LucideIcons.mapPin),
                title: Text(address),
                subtitle: const Text('Abrir no mapa'),
                onTap: () => open(mapUri(address)),
              ),
            if (onEdit != null)
              ListTile(
                leading: const Icon(LucideIcons.pencil),
                title: const Text('Editar contato'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onEdit();
                },
              ),
          ],
        ),
      );
    },
  );
}
