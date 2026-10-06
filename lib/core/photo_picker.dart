import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// Takes or chooses photos, already resized for the reading.
abstract interface class PhotoPicker {
  /// Empty when the person cancels.
  Future<List<Uint8List>> pick(
    PhotoSource source, {
    required int max,
    double maxSide = 2000,
  });
}

/// The media type of a photo from its first bytes, or null when it is not
/// JPEG, PNG or WebP (an iPhone HEIC, for example).
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

class ImagePickerPhotos implements PhotoPicker {
  ImagePickerPhotos([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const _quality = 85;

  /// [maxSide] 2000 is enough to read handwriting; smaller suits a profile
  /// photo. Either way each photo stays well under 1 MB as JPEG.
  @override
  Future<List<Uint8List>> pick(
    PhotoSource source, {
    required int max,
    double maxSide = 2000,
  }) async {
    if (max < 1) return const [];
    final files = switch (source) {
      PhotoSource.camera => [
        ?await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: maxSide,
          maxHeight: maxSide,
          imageQuality: _quality,
          requestFullMetadata: false,
        ),
      ],
      PhotoSource.gallery when max == 1 => [
        ?await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: maxSide,
          maxHeight: maxSide,
          imageQuality: _quality,
          requestFullMetadata: false,
        ),
      ],
      PhotoSource.gallery => await _picker.pickMultiImage(
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: _quality,
        limit: max,
        requestFullMetadata: false,
      ),
    };
    return [for (final file in files.take(max)) await file.readAsBytes()];
  }
}
