import 'dart:async';
import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:reader_webview/reader_webview.dart';

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
          onImportArticle: (_, {onStage}) async => null,
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

  testWidgets('offline menu disables article import action', (tester) async {
    var articleImportCalls = 0;

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          isOffline: true,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async {
            articleImportCalls += 1;
            return null;
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final offlineIcon = tester.widget<Icon>(find.byIcon(AppIcons.offline));
    expect(offlineIcon.color, AppTheme.light().ext.warning);
    expect(find.byIcon(AppIcons.global), findsNothing);

    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Library'), findsOneWidget);
    expect(
      find.text('Creates a clean article for offline reading.'),
      findsNothing,
    );
    expect(articleImportCalls, 0);
  });

  testWidgets('open menu reacts when connectivity comes back online', (
    tester,
  ) async {
    final isOfflineController = StreamController<bool>();
    addTearDown(isOfflineController.close);

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          isOffline: true,
          isOfflineStream: isOfflineController.stream,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.offline), findsOneWidget);
    expect(find.byIcon(AppIcons.global), findsNothing);

    isOfflineController.add(false);
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(AppIcons.global), findsOneWidget);
    expect(find.byIcon(AppIcons.offline), findsNothing);

    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    expect(
      find.text('Creates a clean article for offline reading.'),
      findsOneWidget,
    );
  });

  testWidgets('article url form disables save while offline', (tester) async {
    var articleImportCalls = 0;
    final isOfflineController = StreamController<bool>();
    addTearDown(isOfflineController.close);

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          isOfflineStream: isOfflineController.stream,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async {
            articleImportCalls += 1;
            return null;
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    isOfflineController.add(true);
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'https://example.com/a');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(articleImportCalls, 0);

    isOfflineController.add(false);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(articleImportCalls, 1);
  });

  testWidgets('article url form validates empty and invalid URL input', (
    tester,
  ) async {
    final importedUrls = <String>[];

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (url, {onStage}) async {
            importedUrls.add(url);
            return _fakeArticle(title: 'Saved article');
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    final saveButtonFinder = find.widgetWithText(FilledButton, 'Save');
    expect(
      tester.widget<FilledButton>(saveButtonFinder).onPressed,
      isNull,
      reason: 'empty input should not be submittable from the button',
    );

    await tester.enterText(find.byType(TextField), 'oifwoeifwoeiwoie');
    await tester.pump();

    expect(
      tester.widget<FilledButton>(saveButtonFinder).onPressed,
      isNull,
      reason: 'invalid URL input should not activate the Save button',
    );
    expect(importedUrls, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Enter a valid article URL'), findsOneWidget);
    expect(find.text('Save Article'), findsOneWidget);
    expect(find.text('Fetching article...'), findsNothing);

    await tester.enterText(find.byType(TextField), 'example.com/article');
    await tester.pump();
    expect(find.text('Enter a valid article URL'), findsNothing);

    await tester.tap(saveButtonFinder);
    await tester.pump();

    expect(importedUrls, ['https://example.com/article']);
  });

  testWidgets('cancel button dismisses the sheet', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
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
          onImportArticle: (_, {onStage}) async => null,
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
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    expect(
      find.text('Creates a clean article for offline reading.'),
      findsOneWidget,
    );
    expect(find.text('Keeps the original source link.'), findsOneWidget);
    expect(find.text('Adds it to your Library.'), findsOneWidget);
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
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    final pasteButtonFinder = find.byIcon(AppIcons.paste);
    final pasteIcon = tester.widget<Icon>(pasteButtonFinder);
    expect(find.widgetWithIcon(IconButton, AppIcons.paste), findsNothing);
    expect(
      pasteIcon.color,
      Theme.of(tester.element(find.byType(TextField))).colorScheme.primary,
    );
    final fieldRect = tester.getRect(find.byType(TextField));
    final pasteRect = tester.getRect(
      find.byKey(const ValueKey('articleUrlPasteButton')),
    );
    expect(pasteRect.center.dx, greaterThan(fieldRect.center.dx));
    expect(fieldRect.right - pasteRect.right, closeTo(AppSpacing.sm, 1));

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
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    final pasteIcon = tester.widget<Icon>(find.byIcon(AppIcons.paste));
    expect(find.widgetWithIcon(IconButton, AppIcons.paste), findsNothing);
    expect(
      pasteIcon.color,
      Theme.of(tester.element(find.byType(TextField))).colorScheme.primary,
    );

    await tester.tap(find.byIcon(AppIcons.paste));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(clipboardReadCount, 1);
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('article success fades between aligned status views', (
    tester,
  ) async {
    final importCompleter = Completer<Article?>();

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) => importCompleter.future,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://example.com/a');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Fetching article...'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'https://example.com/a',
      ),
      findsOneWidget,
    );
    final uploadingTitleTop = tester
        .getTopLeft(
          find.text('Fetching article...'),
        )
        .dy;

    importCompleter.complete(_fakeArticle(title: 'Saved article'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('importFlowStatusTransition')),
      findsWidgets,
    );

    await tester.pumpAndSettle();

    expect(find.text('Article saved!'), findsOneWidget);
    expect(find.text('Saved article'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Article saved!')).dy,
      closeTo(uploadingTitleTop, 1),
    );
  });

  testWidgets('book upload status icon matches article upload position', (
    tester,
  ) async {
    final articleImportCompleter = Completer<Article?>();

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) => articleImportCompleter.future,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://example.com/a');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final articleIconRect = tester.getRect(
      find.byKey(const ValueKey('importFlowStatusIcon')),
    );

    articleImportCompleter.complete(_fakeArticle(title: 'Saved article'));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final bookImportCompleter = Completer<Book?>();

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Test.epub'),
          onImportBook: (file, {onProgress}) => bookImportCompleter.future,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final bookIconRect = tester.getRect(
      find.byKey(const ValueKey('importFlowStatusIcon')),
    );

    expect(bookIconRect.size, equals(articleIconRect.size));
    expect(bookIconRect.center.dx, closeTo(articleIconRect.center.dx, 0.1));
    expect(bookIconRect.center.dy, closeTo(articleIconRect.center.dy, 0.1));
  });

  testWidgets('book upload requires accepting terms before file picker', (
    tester,
  ) async {
    var accepted = false;
    var acceptCalls = 0;
    var pickerCalls = 0;
    var termsCalls = 0;
    var privacyCalls = 0;

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async {
            pickerCalls += 1;
            return null;
          },
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
          isBookImportTermsAccepted: () => accepted,
          acceptBookImportTerms: () async {
            acceptCalls += 1;
            accepted = true;
          },
          onOpenTerms: () async => termsCalls += 1,
          onOpenPrivacy: () async => privacyCalls += 1,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();

    expect(find.text('Before uploading'), findsOneWidget);
    expect(
      find.text(
        'Only upload books, comics, and documents you have the right to use in ReadFlex.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('I confirm I have the right to upload this file.'),
      findsOneWidget,
    );
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(pickerCalls, 0);

    var continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('importFlowLegalLink-Terms')));
    await tester.tap(
      find.byKey(const ValueKey('importFlowLegalLink-Privacy Policy')),
    );
    expect(termsCalls, 1);
    expect(privacyCalls, 1);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNotNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(acceptCalls, 1);
    expect(pickerCalls, 1);
    expect(accepted, isTrue);
    expect(find.text('Add to Library'), findsOneWidget);
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
          onImportArticle: (_, {onStage}) async => null,
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
          onImportArticle: (_, {onStage}) async => null,
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

  testWidgets('book success fades between aligned status views', (
    tester,
  ) async {
    final importCompleter = Completer<Book?>();

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Test.epub'),
          onImportBook: (file, {onProgress}) => importCompleter.future,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Uploading book...'), findsOneWidget);
    expect(find.text('Test.epub'), findsOneWidget);
    final uploadingIconRect = tester.getRect(
      find.byKey(const ValueKey('importFlowStatusIcon')),
    );
    expect(uploadingIconRect.size, equals(const Size(56, 56)));
    final progressIndicatorRect = tester.getRect(
      find.byType(CircularProgressIndicator),
    );
    expect(progressIndicatorRect.width, lessThan(uploadingIconRect.width));
    expect(progressIndicatorRect.height, lessThan(uploadingIconRect.height));

    importCompleter.complete(_fakeBook());
    await tester.pump();

    expect(
      find.byKey(const ValueKey('importFlowStatusTransition')),
      findsWidgets,
    );

    await tester.pumpAndSettle();

    expect(find.text('Book added!'), findsOneWidget);
    expect(find.text('Test.epub'), findsOneWidget);

    final successIconRect = tester.getRect(
      find.byKey(const ValueKey('importFlowStatusIcon')),
    );
    expect(successIconRect.size, equals(uploadingIconRect.size));
    expect(
      successIconRect.center.dx,
      closeTo(uploadingIconRect.center.dx, 0.1),
    );
    expect(
      successIconRect.center.dy,
      closeTo(uploadingIconRect.center.dy, 0.1),
    );
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
          onImportArticle: (_, {onStage}) async => null,
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
          onImportArticle: (_, {onStage}) async => null,
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

  testWidgets('book failure fades between aligned status views', (
    tester,
  ) async {
    final failureCompleter = Completer<void>();

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Bad.epub'),
          onImportBook: (file, {onProgress}) async {
            await failureCompleter.future;
            throw const BookImportException('File type not supported');
          },
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pump();

    expect(find.text('Uploading book...'), findsOneWidget);
    expect(find.text('Bad.epub'), findsOneWidget);

    failureCompleter.complete();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('importFlowStatusTransition')),
      findsWidgets,
    );

    await tester.pumpAndSettle();

    expect(find.text('File type not supported'), findsOneWidget);
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

Article _fakeArticle({String title = 'Article'}) => Article(
  id: 'article-1',
  title: title,
  url: 'https://example.com/a',
  contentPath: '/articles/article-1/article.json',
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
