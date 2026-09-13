import 'package:flutter_test/flutter_test.dart';
import 'package:mediary/text_formatting.dart';

void main() {
  test('titleCaseDisplay normalizes catalog and dose text', () {
    expect(titleCaseDisplay('ADVIL'), 'Advil');
    expect(
      titleCaseDisplay('ibuprofen 200 MG oral tablet'),
      'Ibuprofen 200 MG Oral Tablet',
    );
    expect(
      titleCaseDisplay('metformin 500 mg oral tablet'),
      'Metformin 500 MG Oral Tablet',
    );
    expect(titleCaseDisplay('1 tablet · 11:38'), '1 Tablet · 11:38');
    expect(titleCaseDisplay(''), isEmpty);
  });
}
