import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:bowie/core/error/app_failure.dart';

/// A document the person chose, read into memory.
class PickedDocument {
  const PickedDocument({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Chooses PDFs from the phone (Files on iOS, the file manager on Android).
abstract interface class DocumentPicker {
  /// Empty when the person cancels. Files over [maxBytes] are refused with
  /// an [AppFailure] before being read.
  Future<List<PickedDocument>> pickPdfs({
    required int max,
    required int maxBytes,
  });
}

class FilePickerDocuments implements DocumentPicker {
  const FilePickerDocuments();

  @override
  Future<List<PickedDocument>> pickPdfs({
    required int max,
    required int maxBytes,
  }) async {
    if (max < 1) return const [];
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final picked = <PickedDocument>[];
    for (final file in files.take(max)) {
      final size = file.lengthSync() ?? await file.length();
      if (size != null && size > maxBytes) {
        throw AppFailure(
          '${file.name} passa de ${maxBytes ~/ (1024 * 1024)} MB. '
          'Escolha um arquivo menor.',
        );
      }
      picked.add(
        PickedDocument(name: file.name, bytes: await file.readAsBytes()),
      );
    }
    return picked;
  }
}

/// Opens a document in the phone's viewer.
abstract interface class DocumentOpener {
  /// False when no app on the phone opens it.
  Future<bool> open(File file, {required String name});
}

class OpenFilexOpener implements DocumentOpener {
  const OpenFilexOpener();

  @override
  Future<bool> open(File file, {required String name}) async {
    // The viewer shows the file's name, so open a copy named as the person
    // knows it ("Hemograma.pdf"), not by its id.
    final folder = Directory(
      p.join((await getTemporaryDirectory()).path, 'abrir'),
    );
    await folder.create(recursive: true);
    final copy = await file.copy(p.join(folder.path, p.basename(name)));
    final result = await OpenFilex.open(copy.path, type: 'application/pdf');
    return result.type == ResultType.done;
  }
}
