import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// On Android and iOS, opens the system save dialog so the user picks where
/// [csv] goes. On desktop, saves it to Downloads, then offers it through the
/// share sheet. Returns where the file was saved, or null if the user
/// cancelled; sharing is best effort, since not every platform supports it.
Future<String?> exportCsv(String csv, String fileName) async {
  // A byte-order mark so Excel opens UTF-8 names correctly.
  final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
  if (Platform.isAndroid || Platform.isIOS) {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'text/csv',
    );
    if (uri == null) return null;
    // Android hands back a content:// URI; show just the chosen file name.
    return Uri.decodeComponent(uri.pathSegments.last).split(RegExp('[/:]')).last;
  }
  final dir = await getDownloadsDirectory() ??
      await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes);
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Insight check-ins',
      ),
    );
  } catch (_) {
    // The file is saved either way; the caller shows where.
  }
  return file.path;
}
