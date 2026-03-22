import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

Article _article({
  String id = '1',
  String title = 'Test Article',
  String? siteName,
  String url = 'https://example.com/article',
  String cleanedHtml = '<p>Hello</p>',
}) => Article(
  id: id,
  title: title,
  siteName: siteName,
  url: url,
  cleanedHtml: cleanedHtml,
  addedAt: DateTime(2026),
);

void main() {
  group('Article', () {
    group('copyWith()', () {
      test('preserves id and addedAt', () {
        final article = _article();
        final copy = article.copyWith(title: 'New');

        expect(copy.id, article.id);
        expect(copy.addedAt, article.addedAt);
      });

      test('updates title', () {
        final article = _article();
        final copy = article.copyWith(title: 'Updated');

        expect(copy.title, 'Updated');
      });

      test('updates siteName', () {
        final article = _article();
        final copy = article.copyWith(siteName: 'Example');

        expect(copy.siteName, 'Example');
      });

      test('clears siteName when null is passed explicitly', () {
        final article = _article(siteName: 'Site');
        final copy = article.copyWith(siteName: null);

        expect(copy.siteName, isNull);
      });

      test('preserves siteName when not passed', () {
        final article = _article(siteName: 'Site');
        final copy = article.copyWith(title: 'New');

        expect(copy.siteName, 'Site');
      });

      test('updates currentScrollOffset', () {
        final article = _article();
        final copy = article.copyWith(currentScrollOffset: 150.0);

        expect(copy.currentScrollOffset, 150.0);
      });

      test('updates isFinished', () {
        final article = _article();
        final copy = article.copyWith(isFinished: true);

        expect(copy.isFinished, isTrue);
      });

      test('clears lastOpenedAt when null is passed explicitly', () {
        final article = _article();
        final withDate = article.copyWith(lastOpenedAt: DateTime(2026));
        final cleared = withDate.copyWith(lastOpenedAt: null);

        expect(cleared.lastOpenedAt, isNull);
      });
    });

    group('equality', () {
      test('two articles with same fields are equal', () {
        expect(_article(), equals(_article()));
      });

      test('articles with different id are not equal', () {
        expect(_article(id: '1'), isNot(equals(_article(id: '2'))));
      });

      test('articles with different url are not equal', () {
        expect(
          _article(url: 'https://a.com'),
          isNot(equals(_article(url: 'https://b.com'))),
        );
      });
    });
  });
}
