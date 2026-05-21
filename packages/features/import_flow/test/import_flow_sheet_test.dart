import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText;
  var clipboardReadCount = 0;

  setUp(() {
    clipboardText = null;
    clipboardReadCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.getData':
              clipboardReadCount += 1;
              return {'text': clipboardText};
            case 'Clipboard.setData':
              clipboardText = (call.arguments as Map?)?['text'] as String?;
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

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
    expect(find.byIcon(AppIcons.global), findsOneWidget);
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

  testWidgets('menu steps use slide transition', (tester) async {
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
    await tester.tap(find.text('Save Article'));
    await tester.pump();

    expect(find.byType(FractionalTranslation), findsWidgets);
    expect(find.text('Add to Library'), findsOneWidget);
    expect(find.text('Save Article'), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.text('Add to Library'), findsNothing);
    expect(find.text('Save Article'), findsOneWidget);
  });

  testWidgets('article url entry shows import hints', (tester) async {
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
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    expect(
      find.text('Saves a clean offline reading version.'),
      findsOneWidget,
    );
    expect(find.text('Keeps article images when available.'), findsOneWidget);
    expect(
      find.text('Works with public pages you can open in a browser.'),
      findsOneWidget,
    );
    expect(
      find.text('Paste a copied article URL when available.'),
      findsOneWidget,
    );
  });

  testWidgets('article url entry pastes a valid clipboard url', (
    tester,
  ) async {
    clipboardText = 'example.com/article';

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
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    final pasteButtonFinder = find.widgetWithIcon(IconButton, AppIcons.paste);
    final pasteButton = tester.widget<IconButton>(pasteButtonFinder);
    expect(pasteButton.onPressed, isNotNull);
    expect(
      pasteButton.color,
      Theme.of(tester.element(find.byType(TextField))).colorScheme.primary,
    );

    await tester.tap(pasteButtonFinder);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'https://example.com/article');
  });

  testWidgets('article url entry ignores non-url clipboard text', (
    tester,
  ) async {
    clipboardText = 'just words';

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
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    final pasteButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, AppIcons.paste),
    );

    expect(pasteButton.onPressed, isNotNull);
    expect(
      pasteButton.color,
      Theme.of(tester.element(find.byType(TextField))).colorScheme.primary,
    );

    await tester.tap(find.widgetWithIcon(IconButton, AppIcons.paste));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(clipboardReadCount, 1);
    expect(field.controller!.text, isEmpty);
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
