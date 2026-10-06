import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Keeps pet profile photos on the phone, so they show offline and upload
/// later. Each photo has a server path `<pet id>/<photo id>.<jpg|png|webp>`; the local
/// file is the same path under the app's documents folder.
class PetPhotoStore {
  PetPhotoStore(this._root, {Uuid? ids}) : _ids = ids ?? const Uuid();

  final Directory _root;
  final Uuid _ids;

  static Future<PetPhotoStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    return PetPhotoStore(Directory(p.join(docs.path, 'pet_photos')));
  }

  /// A new path for a photo of [petId], with the extension of [mediaType].
  /// Each photo gets its own path, so a replaced photo never shows from an
  /// old cache.
  String newPath(String petId, String mediaType) {
    final extension = switch (mediaType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    return '$petId/${_ids.v4()}.$extension';
  }

  File _file(String photoPath) {
    final parts = photoPath.split('/');
    if (parts.length != 2 ||
        parts.any((part) => part.isEmpty || part == '..')) {
      throw ArgumentError.value(photoPath, 'photoPath');
    }
    return File(p.join(_root.path, parts[0], parts[1]));
  }

  Future<void> write(String photoPath, Uint8List bytes) async {
    final file = _file(photoPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  /// The photo saved on the phone, or null when it is not here (yet).
  Future<File?> local(String photoPath) async {
    final file = _file(photoPath);
    return await file.exists() ? file : null;
  }

  Future<Uint8List?> read(String photoPath) async {
    final file = await local(photoPath);
    return file?.readAsBytes();
  }

  Future<void> delete(String photoPath) async {
    final file = _file(photoPath);
    if (await file.exists()) await file.delete();
  }
}
