import 'dart:math' as math;

import 'package:flutter/services.dart';

/// The school's student ID format: eleven digits grouped 2-4-5.
const studentIdFormat = '00-0000-00000';

final _validId = RegExp(r'^\d{2}-\d{4}-\d{5}$');
final _nonDigits = RegExp(r'\D');

bool isValidStudentId(String id) => _validId.hasMatch(id);

/// Whether [id] matches a search for [query] (already trimmed and
/// lowercased). Digits typed without the dashes still find the ID.
bool matchesStudentId(String id, String query) {
  if (id.toLowerCase().contains(query)) return true;
  final digits = query.replaceAll(RegExp(r'[\s-]'), '');
  return digits.isNotEmpty &&
      !digits.contains(_nonDigits) &&
      id.replaceAll('-', '').contains(digits);
}

/// Lays out typed or pasted digits as a student ID: the dashes appear on
/// their own and input stops at eleven digits. The cursor stays after the
/// same digit it followed, so editing mid-ID works.
class StudentIdFormatter extends TextInputFormatter {
  const StudentIdFormatter();

  static const _maxDigits = 11;

  /// "21012345678" → "21-0123-45678"; shorter input gets the dashes it has
  /// reached.
  static String format(String digits) {
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 6) out.write('-');
      out.write(digits[i]);
    }
    return out.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(_nonDigits, '');
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);
    final end = newValue.selection.end;
    final before = end < 0
        ? digits.length
        : math.min(
            newValue.text.substring(0, end).replaceAll(_nonDigits, '').length,
            digits.length,
          );
    final offset = before + (before > 2 ? 1 : 0) + (before > 6 ? 1 : 0);
    return TextEditingValue(
      text: format(digits),
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
