import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/health/domain/card_reading.dart';

/// Up to four photos per reading, as the Edge Function accepts.
const maxCardPhotos = 4;

/// The media type of a photo from its first bytes, or null when the format is
/// not one the reading accepts (JPEG, PNG or WebP).
String? photoMediaType(Uint8List bytes) {
  bool starts(List<int> prefix, [int offset = 0]) {
    if (bytes.length < offset + prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[offset + i] != prefix[i]) return false;
    }
    return true;
  }

  if (starts(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (starts(ascii.encode('RIFF')) && starts(ascii.encode('WEBP'), 8)) {
    return 'image/webp';
  }
  return null;
}

/// Sends photos of a vaccine card to be read in the cloud.
abstract interface class CardReader {
  Future<CardReading> read(List<Uint8List> photos);
}

/// Calls the `read-vaccine-card` Edge Function (supabase/functions), which
/// keeps the Anthropic key on the server.
class SupabaseCardReader implements CardReader {
  SupabaseCardReader(this._client);

  final SupabaseClient _client;

  @override
  Future<CardReading> read(List<Uint8List> photos) async {
    final images = [
      for (final photo in photos)
        {
          'media_type':
              photoMediaType(photo) ??
              (throw const AppFailure(
                'Formato de foto não aceito. Use a câmera ou uma foto em JPEG ou PNG.',
              )),
          'data': base64Encode(photo),
        },
    ];
    try {
      final response = await _client.functions
          .invoke('read-vaccine-card', body: {'images': images})
          .timeout(const Duration(seconds: 160));
      final data = response.data;
      if (data is! Map) {
        throw const AppFailure(
          'A leitura voltou incompleta. Tente de novo.',
          retryable: true,
        );
      }
      return CardReading.fromJson(Map<String, dynamic>.from(data));
    } on FunctionsFetchException {
      throw const AppFailure(
        'Sem conexão com a internet. A leitura precisa de internet; '
        'você pode registrar à mão.',
        retryable: true,
      );
    } on FunctionException catch (error) {
      throw readingFailure(error.status, error.details);
    } on TimeoutException {
      throw const AppFailure(
        'A leitura demorou demais. Tente de novo com menos fotos.',
        retryable: true,
      );
    }
  }
}

/// The function answers errors as `{error, message}` with a Portuguese
/// message; anything else becomes a generic one.
AppFailure readingFailure(int status, Object? details) {
  if (kDebugMode) {
    final code = details is Map ? details['error'] : null;
    debugPrint('read-vaccine-card failed: status=$status code=$code');
  }
  final message = details is Map ? details['message'] : null;
  if (message is String && message.isNotEmpty) {
    return AppFailure(message, retryable: status >= 500);
  }
  return switch (status) {
    401 => const AppFailure(
      'Entre na sua conta de novo para ler a carteirinha.',
    ),
    404 => const AppFailure(
      'A leitura da carteirinha ainda não foi configurada no servidor.',
    ),
    _ => const AppFailure(
      'O serviço de leitura falhou. Tente de novo.',
      retryable: true,
    ),
  };
}
