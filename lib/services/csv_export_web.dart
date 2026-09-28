import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Hands [csv] to the browser to share or download. Returns the file name.
Future<String> exportCsv(String csv, String fileName) async {
  final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
      fileNameOverrides: [fileName],
      subject: 'Insight check-ins',
    ),
  );
  return fileName;
}
