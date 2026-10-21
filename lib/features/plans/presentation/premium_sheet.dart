import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/plans/data/store_billing.dart';
import 'package:bowie/features/plans/domain/account_plan.dart';
import 'package:bowie/features/plans/presentation/plan_providers.dart';

/// Linked from the subscription sheet, as the stores require.
const privacyPolicyUrl =
    'https://github.com/bpcoutinho1/bowie-app/blob/main/docs/legal/politica-de-privacidade.md';
const appleTermsUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

/// Where the person cancels or changes the subscription.
String manageSubscriptionsUrl(TargetPlatform platform) =>
    platform == TargetPlatform.iOS
    ? 'https://apps.apple.com/account/subscriptions'
    : 'https://play.google.com/store/account/subscriptions';

/// "Bowie Premium": what it adds, the price and the subscription through the
/// App Store or Google Play.
Future<void> showPremiumSheet(BuildContext context, {String? reason}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) => _PremiumSheet(reason: reason),
  );
}

class _PremiumSheet extends ConsumerStatefulWidget {
  const _PremiumSheet({this.reason});

  final String? reason;

  @override
  ConsumerState<_PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends ConsumerState<_PremiumSheet> {
  late final StoreBilling _store = ref.read(storeBillingProvider);
  List<StoreOffer>? _offers;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider);
    if (!_store.available || user == null) {
      setState(() => _offers = const []);
      return;
    }
    try {
      final offers = await _store.offers(user.id);
      if (mounted) setState(() => _offers = offers);
    } on AppFailure catch (error) {
      if (mounted) {
        setState(() {
          _offers = const [];
          _error = error.message;
        });
      }
    }
  }

  Future<void> _run(
    Future<StorePremium?> Function(String userId) action, {
    required String nothing,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final premium = await action(user.id);
      if (!mounted) return;
      if (premium == null) {
        setState(() {
          _busy = false;
          _error = nothing.isEmpty ? null : nothing;
        });
        return;
      }
      ref.invalidate(planUsageProvider);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Premium ativo. Obrigado por apoiar o Bowie.'),
        ),
      );
    } on AppFailure catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final platform = Theme.of(context).platform;
    final offers = _offers;

    Widget benefit(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: BowieSpacing.s2),
      child: Row(
        children: [
          Icon(icon, color: colors.text),
          const SizedBox(width: BowieSpacing.s3),
          Expanded(
            child: Text(
              text,
              style: BowieType.body.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );

    String label(StoreOffer offer) => switch (offer.period) {
      StorePeriod.annual => 'Assinar por ${offer.price} por ano',
      StorePeriod.monthly => 'Assinar por ${offer.price} por mês',
    };

    final store = platform == TargetPlatform.iOS
        ? 'nos Ajustes do iPhone, em Assinaturas'
        : 'no Google Play, em Assinaturas';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BowieSpacing.s4,
        0,
        BowieSpacing.s4,
        BowieSpacing.s6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bowie Premium',
            style: BowieType.title2.copyWith(color: colors.text),
          ),
          if (widget.reason case final reason?) ...[
            const SizedBox(height: BowieSpacing.s2),
            Text(
              reason,
              style: BowieType.body.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: BowieSpacing.s4),
          benefit(LucideIcons.pawPrint, 'Até $premiumPetLimit pets'),
          benefit(
            LucideIcons.scanLine,
            'Leitura da carteirinha por IA sem limite',
          ),
          benefit(LucideIcons.fileText, 'Fotos e PDFs no diário sem limite'),
          const SizedBox(height: BowieSpacing.s2),
          Text(
            'Tudo o que você já registrou continua seu, em qualquer plano.',
            style: BowieType.callout.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: BowieSpacing.s6),
          if (offers == null)
            const Center(child: CircularProgressIndicator())
          else if (offers.isEmpty) ...[
            Text(
              'R\$ 9,90 por mês ou R\$ 99,90 por ano',
              style: BowieType.title3.copyWith(color: colors.text),
            ),
            const SizedBox(height: BowieSpacing.s4),
            const FilledButton(
              onPressed: null,
              child: Text('Assinatura em breve'),
            ),
          ] else ...[
            for (final (index, offer) in offers.indexed) ...[
              if (index > 0) const SizedBox(height: BowieSpacing.s3),
              // The first (annual) stands out; the others are outlined.
              (index == 0 ? FilledButton.new : OutlinedButton.new)(
                onPressed: _busy
                    ? null
                    : () =>
                          _run((user) => _store.buy(user, offer), nothing: ''),
                child: Text(label(offer)),
              ),
            ],
            const SizedBox(height: BowieSpacing.s3),
            Text(
              'A assinatura renova automaticamente pelo mesmo valor até você '
              'cancelar. Cancele quando quiser $store, até 24 horas antes da '
              'renovação.',
              style: BowieType.caption.copyWith(color: colors.textMuted),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: BowieSpacing.s3),
            const LinearProgressIndicator(),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: BowieSpacing.s3),
            Text(
              error,
              style: BowieType.callout.copyWith(color: colors.danger),
            ),
          ],
          const SizedBox(height: BowieSpacing.s2),
          if (offers != null && offers.isNotEmpty)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      _store.restore,
                      nothing:
                          'Nenhuma assinatura encontrada nesta conta '
                          'da loja.',
                    ),
              child: const Text('Restaurar compras'),
            ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Agora não'),
          ),
          const SizedBox(height: BowieSpacing.s2),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: BowieSpacing.s4,
            children: [
              _Link('Termos de uso', appleTermsUrl),
              _Link('Política de privacidade', privacyPolicyUrl),
            ],
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.text, this.url);

  final String text;
  final String url;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => openExternal(context, url),
      style: TextButton.styleFrom(
        textStyle: BowieType.caption,
        foregroundColor: context.colors.link,
      ),
      child: Text(text),
    );
  }
}

/// Opens [url] in the browser or the store, and says so when it cannot.
Future<void> openExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } on Exception {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o link.')),
    );
  }
}

/// A limit that the Premium does not lift.
Future<void> showLimitNotice(BuildContext context, String text) {
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Limite do plano'),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}
