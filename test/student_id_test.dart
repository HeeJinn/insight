import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insight/services/student_id.dart';

void main() {
  const formatter = StudentIdFormatter();

  /// Applies an edit that leaves [text] with the cursor at [cursor] (end
  /// when omitted).
  TextEditingValue edit(String text, [int? cursor]) =>
      formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor ?? text.length),
        ),
      );

  test('dashes appear as digits are typed, and input stops at 11', () {
    expect(edit('21').text, '21');
    expect(edit('210').text, '21-0');
    expect(edit('21-0123').text, '21-0123');
    expect(edit('21-01234').text, '21-0123-4');
    expect(edit('210123456789999').text, '21-0123-45678');
    expect(edit('210').selection.baseOffset, 4, reason: 'after the 0');
  });

  test('pasted IDs are cleaned up; letters and spaces are dropped', () {
    expect(edit('21 0123 45678').text, '21-0123-45678');
    expect(edit('ID: 21-0123-45678').text, '21-0123-45678');
    expect(edit('s03').text, '03');
  });

  test('the cursor stays with its digit when editing mid-ID', () {
    // Typing "9" after the "1" of "21-0123-45678": the digits shift
    // right and the last one falls off.
    final typed = edit('219-0123-45678', 3);
    expect(typed.text, '21-9012-34567');
    expect(typed.selection.baseOffset, 4, reason: 'right after the 9');
  });

  test('only the complete format is valid', () {
    expect(isValidStudentId('21-0123-45678'), isTrue);
    expect(isValidStudentId('21-0123-4567'), isFalse);
    expect(isValidStudentId('2101234567 8'), isFalse);
    expect(isValidStudentId('s03'), isFalse);
  });

  test('search finds an ID with or without its dashes', () {
    expect(matchesStudentId('21-0123-45678', '0123-45'), isTrue);
    expect(matchesStudentId('21-0123-45678', '01234'), isTrue);
    expect(matchesStudentId('21-0123-45678', '21 0123'), isTrue);
    expect(matchesStudentId('21-0123-45678', '999'), isFalse);
    expect(matchesStudentId('21-0123-45678', 'maria 2'), isFalse);
    expect(matchesStudentId('s03', 's0'), isTrue, reason: 'older IDs too');
  });
}
