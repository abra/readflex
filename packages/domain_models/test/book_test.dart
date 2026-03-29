import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

Book _book({
  String id = '1',
  String title = 'Test Book',
  String? author,
  String filePath = '/books/test.epub',
  BookFormat format = BookFormat.epub,
}) => Book(
  id: id,
  title: title,
  author: author,
  filePath: filePath,
  format: format,
  addedAt: DateTime(2026),
);

void main() {
  group('Book', () {
    group('copyWith()', () {
      test('preserves id and addedAt', () {
        final book = _book();
        final copy = book.copyWith(title: 'New Title');

        expect(copy.id, book.id);
        expect(copy.addedAt, book.addedAt);
      });

      test('updates title', () {
        final book = _book();
        final copy = book.copyWith(title: 'Updated');

        expect(copy.title, 'Updated');
      });

      test('updates author', () {
        final book = _book();
        final copy = book.copyWith(author: 'Author');

        expect(copy.author, 'Author');
      });

      test('clears author when null is passed explicitly', () {
        final book = _book(author: 'Author');
        final copy = book.copyWith(author: null);

        expect(copy.author, isNull);
      });

      test('preserves author when not passed', () {
        final book = _book(author: 'Author');
        final copy = book.copyWith(title: 'New');

        expect(copy.author, 'Author');
      });

      test('updates readingProgress', () {
        final book = _book();
        final copy = book.copyWith(readingProgress: 0.5);

        expect(copy.readingProgress, 0.5);
      });

      test('updates isFinished', () {
        final book = _book();
        final copy = book.copyWith(isFinished: true);

        expect(copy.isFinished, isTrue);
      });

      test('updates lastOpenedAt', () {
        final book = _book();
        final now = DateTime(2026, 3);
        final copy = book.copyWith(lastOpenedAt: now);

        expect(copy.lastOpenedAt, now);
      });

      test('clears lastOpenedAt when null is passed explicitly', () {
        final book = _book();
        final withDate = book.copyWith(lastOpenedAt: DateTime(2026));
        final cleared = withDate.copyWith(lastOpenedAt: null);

        expect(cleared.lastOpenedAt, isNull);
      });
    });

    group('equality', () {
      test('two books with same fields are equal', () {
        expect(_book(), equals(_book()));
      });

      test('books with different id are not equal', () {
        expect(_book(id: '1'), isNot(equals(_book(id: '2'))));
      });

      test('books with different title are not equal', () {
        expect(_book(title: 'A'), isNot(equals(_book(title: 'B'))));
      });

      test('books with different format are not equal', () {
        expect(
          _book(format: BookFormat.epub),
          isNot(equals(_book(format: BookFormat.pdf))),
        );
      });
    });
  });
}
