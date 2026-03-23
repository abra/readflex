import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';

void main() {
  testWidgets('book import keeps sheet open when callback returns false', (
    tester,
  ) async {
    var bookPickerCalls = 0;

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onImportBook: () async {
            bookPickerCalls += 1;
            return false;
          },
          onImportArticle: (_) async => false,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import book file'));
    await tester.pumpAndSettle();

    expect(bookPickerCalls, 1);
    expect(find.text('Add to Library'), findsOneWidget);
  });

  testWidgets(
    'book import closes sheet with result when callback returns true',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestHost(
          onOpen: (context) => showImportFlowSheet(
            context,
            onImportBook: () async => true,
            onImportArticle: (_) async => false,
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import book file'));
      await tester.pumpAndSettle();

      expect(find.text('Add to Library'), findsNothing);
      expect(
        find.text('Result: ImportFlowResult.bookImported'),
        findsOneWidget,
      );
    },
  );

  testWidgets('article import closes sheet with articleImported result', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onImportBook: () async => false,
          onImportArticle: (_) async => true,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add article by URL'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'https://example.com');
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Library'), findsNothing);
    expect(
      find.text('Result: ImportFlowResult.articleImported'),
      findsOneWidget,
    );
  });

  testWidgets('article import shows validation error on empty URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onImportBook: () async => false,
          onImportArticle: (_) async => true,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add article by URL'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a URL'), findsOneWidget);
    expect(find.text('Add to Library'), findsOneWidget);
  });

  testWidgets('article import keeps sheet open on failed import', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onImportBook: () async => false,
          onImportArticle: (_) async => false,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add article by URL'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'https://example.com');
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to import article'), findsOneWidget);
    expect(find.text('Add to Library'), findsOneWidget);
  });
}

class _TestHost extends StatefulWidget {
  const _TestHost({required this.onOpen});

  final Future<ImportFlowResult?> Function(BuildContext context) onOpen;

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost> {
  ImportFlowResult? _lastResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () async {
                  final result = await widget.onOpen(context);
                  if (!mounted) return;
                  setState(() => _lastResult = result);
                },
                child: const Text('Open'),
              ),
              if (_lastResult != null) Text('Result: $_lastResult'),
            ],
          ),
        ),
      ),
    );
  }
}
