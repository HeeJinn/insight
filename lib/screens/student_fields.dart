import 'package:flutter/cupertino.dart';

import '../models/student.dart';

/// Shared by enrollment and the student card: choose a program or year
/// level from an action sheet. Null when dismissed.
Future<String?> pickProgram(BuildContext context, String? current) => _pick(
  context,
  'Program',
  [for (final p in programs) (label: p, value: p, on: p == current)],
);

Future<int?> pickYearLevel(BuildContext context, int? current) =>
    _pick(context, 'Year Level', [
      for (var y = 1; y <= maxYearLevel; y++)
        (label: yearLevelLabel(y), value: y, on: y == current),
    ]);

Future<T?> _pick<T>(
  BuildContext context,
  String title,
  List<({String label, T value, bool on})> options,
) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        for (final o in options)
          CupertinoActionSheetAction(
            isDefaultAction: o.on,
            onPressed: () => Navigator.of(context).pop(o.value),
            child: Text(o.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );
}

/// Trimmed and upper-cased, or null when blank.
String? cleanSection(String text) {
  final s = text.trim().toUpperCase();
  return s.isEmpty ? null : s;
}
