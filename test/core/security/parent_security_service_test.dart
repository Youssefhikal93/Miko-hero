import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/security/parent_security_service.dart';

/// Verifies that local parent access stores a verifier rather than the PIN.
void main() {
  test('saved verifier accepts only the original parent PIN', () async {
    final service = ParentSecurityService();

    final record = await service.createRecord('4729');

    expect(record.toJson().toString(), isNot(contains('4729')));
    expect(await service.verify('4729', record), isTrue);
    expect(await service.verify('4728', record), isFalse);
    expect(await service.verify('invalid', record), isFalse);
  });
}
