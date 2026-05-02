import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  group('BookMetadataExtractor.parseMetadata', () {
    test('parses title and string author', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'War and Peace',
        'author': 'Leo Tolstoy',
      });

      expect(metadata.title, 'War and Peace');
      expect(metadata.author, 'Leo Tolstoy');
    });

    test('joins list author with commas', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'Good Omens',
        'author': ['Terry Pratchett', 'Neil Gaiman'],
      });

      expect(metadata.author, 'Terry Pratchett, Neil Gaiman');
    });

    test('handles null author', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'Anonymous Work',
      });

      expect(metadata.author, isNull);
    });

    test('extracts name from map author element', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'Advanced JS',
        'author': [
          {'name': 'Turner, Matt H.', 'sortAs': null},
        ],
      });

      expect(metadata.author, 'Turner, Matt H.');
    });

    test('joins multiple map author elements', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'Collab Book',
        'author': [
          {'name': 'Author One'},
          {'name': 'Author Two', 'sortAs': 'Two, Author'},
        ],
      });

      expect(metadata.author, 'Author One, Author Two');
    });

    test('handles mixed string and map author elements', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'Mixed',
        'author': [
          'Plain Author',
          {'name': 'Map Author'},
        ],
      });

      expect(metadata.author, 'Plain Author, Map Author');
    });

    test('handles non-string non-list author as null', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'Weird Author',
        'author': 42,
      });

      expect(metadata.author, isNull);
    });

    test('falls back to Unknown when title is null', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'author': 'Someone',
      });

      expect(metadata.title, 'Unknown');
    });

    test('parses description', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'A Book',
        'description': 'A great book about things.',
      });

      expect(metadata.description, 'A great book about things.');
    });

    test('handles null description', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'No Desc',
      });

      expect(metadata.description, isNull);
    });

    test('decodes jpeg cover from data URL', () {
      final imageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      final base64Data = base64Encode(imageBytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Data';

      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'With Cover',
        'cover': dataUrl,
      });

      expect(metadata.coverData, imageBytes);
      expect(metadata.coverMimeType, 'image/jpeg');
    });

    test('decodes png cover from data URL', () {
      final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      final base64Data = base64Encode(imageBytes);
      final dataUrl = 'data:image/png;base64,$base64Data';

      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'PNG Cover',
        'cover': dataUrl,
      });

      expect(metadata.coverData, imageBytes);
      expect(metadata.coverMimeType, 'image/png');
    });

    test('handles null cover', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'No Cover',
        'cover': null,
      });

      expect(metadata.coverData, isNull);
      expect(metadata.coverMimeType, isNull);
    });

    test('handles empty cover string', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'Empty Cover',
        'cover': '',
      });

      expect(metadata.coverData, isNull);
      expect(metadata.coverMimeType, isNull);
    });

    test('handles malformed data URL without comma', () {
      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'Bad URL',
        'cover': 'data:image/jpeg;base64',
      });

      expect(metadata.coverData, isNull);
      expect(metadata.coverMimeType, isNull);
    });

    test('parses complete metadata map', () {
      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final base64Data = base64Encode(imageBytes);

      final metadata = BookMetadataExtractor.parseMetadata({
        'title': 'Full Book',
        'author': ['Author One', 'Author Two'],
        'description': 'Description here.',
        'cover': 'data:image/webp;base64,$base64Data',
      });

      expect(metadata.title, 'Full Book');
      expect(metadata.author, 'Author One, Author Two');
      expect(metadata.description, 'Description here.');
      expect(metadata.coverData, imageBytes);
      expect(metadata.coverMimeType, 'image/webp');
    });

    test('handles completely empty map', () {
      final metadata = BookMetadataExtractor.parseMetadata({});

      expect(metadata.title, 'Unknown');
      expect(metadata.author, isNull);
      expect(metadata.description, isNull);
      expect(metadata.coverData, isNull);
      expect(metadata.coverMimeType, isNull);
    });
  });

  group('BookImportException', () {
    test('exposes the JS-side message', () {
      const exception = BookImportException('File type not supported');

      expect(exception.message, 'File type not supported');
    });

    test('toString includes the message', () {
      const exception = BookImportException('boom');

      expect(exception.toString(), contains('boom'));
    });
  });
}
