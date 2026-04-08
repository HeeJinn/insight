import 'dart:io';

Future<void> deleteCapturedFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Best-effort cleanup only.
  }
}
