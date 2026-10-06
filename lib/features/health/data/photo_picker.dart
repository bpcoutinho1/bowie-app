import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// Takes or chooses photos, already resized for the reading.
abstract interface class PhotoPicker {
  /// Empty when the person cancels.
  Future<List<Uint8List>> pick(PhotoSource source, {required int max});
}

class ImagePickerPhotos implements PhotoPicker {
  ImagePickerPhotos([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  // Enough to read handwriting; keeps each photo well under 1 MB as JPEG.
  static const _maxSide = 2000.0;
  static const _quality = 85;

  @override
  Future<List<Uint8List>> pick(PhotoSource source, {required int max}) async {
    if (max < 1) return const [];
    final files = switch (source) {
      PhotoSource.camera => [
        ?await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: _maxSide,
          maxHeight: _maxSide,
          imageQuality: _quality,
          requestFullMetadata: false,
        ),
      ],
      PhotoSource.gallery when max == 1 => [
        ?await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: _maxSide,
          maxHeight: _maxSide,
          imageQuality: _quality,
          requestFullMetadata: false,
        ),
      ],
      PhotoSource.gallery => await _picker.pickMultiImage(
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
        limit: max,
        requestFullMetadata: false,
      ),
    };
    return [for (final file in files.take(max)) await file.readAsBytes()];
  }
}
