import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotFoundException', () {
    test('includes id and default entity type in toString', () {
      const e = NotFoundException('abc');
      expect(e.toString(), contains('abc'));
      expect(e.toString(), contains('Entity'));
    });

    test('includes custom entity type in toString', () {
      const e = NotFoundException('123', 'Book');
      expect(e.toString(), contains('Book'));
      expect(e.toString(), contains('123'));
    });

    test('exposes id and entityType', () {
      const e = NotFoundException('x', 'Article');
      expect(e.id, 'x');
      expect(e.entityType, 'Article');
    });
  });

  group('StorageException', () {
    test('includes cause in toString', () {
      const e = StorageException(cause: 'disk full');
      expect(e.toString(), contains('disk full'));
    });

    test('handles null cause', () {
      const e = StorageException();
      expect(e.cause, isNull);
      expect(e.toString(), contains('null'));
    });
  });
}
