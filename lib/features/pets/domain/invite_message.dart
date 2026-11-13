import 'package:bowie/features/pets/domain/pet.dart';

/// The Bowie site: it sends each phone to its store.
const appSiteUrl = 'https://bowieapp.pet';

/// The invitation to care for [pet], ready to send by WhatsApp or another
/// app (docs/produto/contas-e-tutores.md#convite). The email is the one the
/// invitation was made for: only an account with it can accept.
String inviteMessage({
  required Pet pet,
  required String email,
  String? inviterName,
}) {
  final name = inviterName?.trim();
  final of = ofPet(pet);
  final opening = name == null || name.isEmpty
      ? 'Você recebeu um convite para cuidar $of no app Bowie 🐾'
      : '$name convidou você para cuidar $of no app Bowie 🐾';
  return [
    opening,
    '',
    '1. Baixe o app: $appSiteUrl',
    '2. Entre ou crie sua conta com o email $email',
    '3. Na aba Pets, toque em "Aceitar" no convite $of',
    '',
    'Assim a gente acompanha junto as vacinas, os remédios e o dia a dia '
        '$of 💙',
  ].join('\n');
}
