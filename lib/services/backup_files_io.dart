import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A backup file found in [backupFolder].
typedef BackupFile = ({String path, DateTime modified});

/// Documents/Insight Backups: where backups are saved, and where restore
/// looks for them. A backup from another computer is copied in here.
Future<Directory> backupFolder() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}${Platform.pathSeparator}Insight Backups');
  await dir.create(recursive: true);
  return dir;
}

/// Writes [text] as a new backup file and returns its path. With [share],
/// also offers it through the share sheet, best effort.
Future<String> saveBackup(
  String text,
  DateTime at, {
  bool share = false,
}) async {
  String two(int n) => n.toString().padLeft(2, '0');
  final name =
      'insight-backup-${at.year}${two(at.month)}${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}.json';
  final file = File(
    '${(await backupFolder()).path}${Platform.pathSeparator}$name',
  );
  await file.writeAsString(text, flush: true);
  if (share) {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Insight backup',
        ),
      );
    } catch (_) {
      // Saved either way; the caller shows where.
    }
  }
  return file.path;
}

/// Backup files in [backupFolder], newest first.
Future<List<BackupFile>> listBackups() async {
  final dir = await backupFolder();
  final files = [
    for (final f in dir.listSync().whereType<File>())
      if (f.path.toLowerCase().endsWith('.json'))
        (path: f.path, modified: f.statSync().modified),
  ]..sort((a, b) => b.modified.compareTo(a.modified));
  return files;
}

Future<String> readBackup(String path) => File(path).readAsString();
