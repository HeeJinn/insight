/// Web placeholder: backups need a file system.
typedef BackupFile = ({String path, DateTime modified});

Future<String> saveBackup(String text, DateTime at, {bool share = false}) =>
    throw UnsupportedError('Backups need the desktop or mobile app.');

Future<List<BackupFile>> listBackups() async => const [];

Future<String> readBackup(String path) =>
    throw UnsupportedError('Backups need the desktop or mobile app.');
