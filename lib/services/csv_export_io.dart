import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves [csv] to the app's Documents folder, then offers it through the
/// system share sheet. Returns where the file was saved; sharing is best
/// effort, since not every platform supports sharing files.
Future<String> exportCsv(String csv, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  // A byte-order mark so Excel opens UTF-8 names correctly.
  await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
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
