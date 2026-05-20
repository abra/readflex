import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';

void main() {
  testWidgets('menu state shows the Upload Book option', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Library'), findsOneWidget);
    expect(find.text('Upload Book'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('cancel button dismisses the sheet', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Library'), findsNothing);
  });

  testWidgets('cancelled book picker keeps menu open', (tester) async {
    var pickerCalls = 0;
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async {
            pickerCalls += 1;
            return null;
          },
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
    expect(find.text('Add to Library'), findsOneWidget);
  });

  testWidgets('successful book import shows Done success card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Test.epub'),
          onImportBook: (file, {onProgress}) async {
            onProgress?.call(0.5);
            onProgress?.call(1.0);
            return _fakeBook();
          },
          onImportArticle: (_) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();

    expect(find.text('Book added!'), findsOneWidget);
    expect(find.text('Test.epub'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('successful comic import shows Comic added!', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Strip.cbz'),
          onImportBook: (file, {onProgress}) async => _fakeBook(
            format: BookFormat.cbz,
          ),
          onImportArticle: (_) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();

    expect(find.text('Comic added!'), findsOneWidget);
    expect(find.text('Book added!'), findsNothing);
    expect(find.text('Strip.cbz'), findsOneWidget);
  });

  testWidgets('book import failure shows Try again button', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Bad.epub'),
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to import the book'), findsOneWidget);
    expect(find.text('Bad.epub'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

Book _fakeBook({BookFormat format = BookFormat.epub}) => Book(
  id: 'book-1',
  title: 'Test',
  filePath: 'book.epub',
  format: format,
  addedAt: DateTime(2026),
);

class _TestHost extends StatefulWidget {
  const _TestHost({required this.onOpen});

  final Future<void> Function(BuildContext context) onOpen;

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => widget.onOpen(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }
}
