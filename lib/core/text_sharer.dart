import 'dart:ui';

import 'package:share_plus/share_plus.dart';

/// Opens the phone's share sheet (WhatsApp, Mensagens, email...) with a
/// ready text.
abstract interface class TextSharer {
  /// [origin] is where the sheet points from on iPad; null elsewhere.
  Future<void> share(String text, {Rect? origin});
}

class SharePlusSharer implements TextSharer {
  const SharePlusSharer();

  @override
  Future<void> share(String text, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }
}
