import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_external_link_destination.dart';
import 'package:reader/src/reader_external_link_sheet.dart';

import 'golden_support.dart';

/// The sheet a page link opens before it leaves the reader, in every visual
/// profile: the real destination, Copy link and Open within reach.
void main() {
  setUpAll(loadUiFonts);
  // A link whose words point at Wikipedia but whose host does not.
  const url =
      'https://login.secure-account-verify.example.net/session/redirect'
      '?continue=https%3A%2F%2Fen.wikipedia.org%2Fwiki%2FLewis_and_Clark'
      '&utm_source=ebook&utm_medium=footnote';
  for (final profile in VisualProfile.values) {
    testWidgets('external link sheet ${profile.name}', (tester) async {
      late BuildContext host;
      await pumpGoldenSurface(tester, profile, (context) {
        host = context;
        return const Scaffold();
      });
      showReaderExternalLinkSheet(
        host,
        destination: ReaderExternalLinkDestination.tryParse(url)!,
      );
      await tester.pumpAndSettle();
      final target = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('reader-external-link-target')),
      );
      expect(target.didExceedMaxLines, isFalse);
      expect(
        target.text.toPlainText(),
        'login.secure-account-verify.example.net',
      );
      await expectUiGolden(tester, profile, 'reader-external-link');
      expect(tester.takeException(), isNull);
    }, tags: ['golden']);
  }
}
