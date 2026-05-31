import 'dart:async';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ui.Image wideImage;

  setUpAll(() async {
    wideImage = await createTestImage(width: 40, height: 20, cache: false);
  });

  tearDownAll(() {
    wideImage.dispose();
  });

  testWidgets('AppSourceCoverFrame renders cover and overlay content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 180,
            child: AppSourceCoverFrame(
              cover: ColoredBox(color: Colors.red),
              overlays: [
                Center(child: Text('EPUB')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AppSourceCoverFrame), findsOneWidget);
    expect(find.text('EPUB'), findsOneWidget);

    final decoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(AppSourceCoverFrame),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    final shadows = decoration.boxShadow!;
    expect(
      decoration.borderRadius,
      BorderRadius.circular(appSourceCoverRadius),
    );
    expect(shadows, hasLength(2));
    expect(shadows.every((shadow) => shadow.offset.dx < 0), isTrue);
    expect(shadows.every((shadow) => shadow.offset.dy > 0), isTrue);

    final frameRect = tester.getRect(find.byType(AppSourceCoverFrame));
    final coverRect = tester.getRect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == Colors.red,
      ),
    );
    expect(coverRect, frameRect);
  });

  testWidgets(
    'AppSourceCover falls back for failed cover decode without Flutter error',
    (tester) async {
      final previousOnError = FlutterError.onError;
      final previousDebugPrint = debugPrint;
      final errors = <FlutterErrorDetails>[];
      final logs = <String>[];
      FlutterError.onError = errors.add;
      debugPrint = (message, {wrapWidth}) {
        if (message case final message?) logs.add(message);
      };
      addTearDown(() {
        FlutterError.onError = previousOnError;
        debugPrint = previousDebugPrint;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 180,
              child: AppSourceCover(
                title: 'Broken Cover',
                seed: 'book-1',
                coverImage: _FailingImageProvider('cover.jpeg'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      FlutterError.onError = previousOnError;
      debugPrint = previousDebugPrint;

      expect(errors, isEmpty);
      expect(find.byType(AppCoverArt), findsOneWidget);
      expect(find.text('Broken Cover'), findsOneWidget);

      final log = logs.join('\n');
      expect(log, contains('[source-cover-decode]'));
      expect(log, contains('Broken Cover'));
      expect(log, contains('book-1'));
      expect(log, contains('cover.jpeg'));
    },
  );

  testWidgets(
    'AppSourceCover renders article fallback instead of cover image',
    (
      tester,
    ) async {
      final previousOnError = FlutterError.onError;
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previousOnError);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 180,
              child: AppSourceCover(
                title: 'Saved Article',
                seed: 'article-1',
                source: 'Example',
                coverImage: _FailingImageProvider('article.jpeg'),
                isArticle: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      FlutterError.onError = previousOnError;

      expect(errors, isEmpty);
      expect(find.byType(AppCoverArt), findsOneWidget);
      expect(find.text('Saved Article'), findsOneWidget);
      expect(find.text('EXAMPLE'), findsOneWidget);
    },
  );

  testWidgets('AppCoverArt suppresses article author text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 180,
            child: AppCoverArt(
              title: 'Saved Article',
              author: 'Article Author',
              source: 'Example',
              seed: 'article-1',
              isArticle: true,
              height: 180,
              width: 120,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Saved Article'), findsOneWidget);
    expect(find.text('EXAMPLE'), findsOneWidget);
    expect(find.text('ARTICLE AUTHOR'), findsNothing);
  });

  testWidgets('AppCoverArt applies RTL direction to fallback cover text', (
    tester,
  ) async {
    const title = 'الأزمة الاقتصادية تتصدر الاهتمامات';
    const source = 'الجزيرة';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 180,
            child: AppCoverArt(
              title: title,
              source: source,
              seed: 'article-rtl',
              isArticle: true,
              centerText: true,
              textDirection: TextDirection.rtl,
              height: 180,
              width: 120,
            ),
          ),
        ),
      ),
    );

    final titleText = tester.widget<Text>(find.text(title));
    final sourceText = tester.widget<Text>(find.text(source));

    expect(titleText.textDirection, TextDirection.rtl);
    expect(titleText.textAlign, TextAlign.start);
    expect(sourceText.textDirection, TextDirection.rtl);
    expect(sourceText.textAlign, TextAlign.start);
  });

  testWidgets('AppCoverArt text does not inherit Hero overlay fallback style', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DefaultTextStyle(
            style: TextStyle(
              color: Colors.yellow,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.double,
            ),
            child: SizedBox(
              width: 120,
              height: 180,
              child: AppCoverArt(
                title: 'Article Title',
                source: 'Example',
                seed: 'article-1',
                isArticle: true,
                centerText: true,
                bottomReserve: 16,
                showMatte: false,
                height: 180,
                width: 120,
              ),
            ),
          ),
        ),
      ),
    );

    for (final label in ['Article Title', 'EXAMPLE']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.inherit, isFalse);
      expect(text.style?.decoration, TextDecoration.none);
    }
  });

  testWidgets(
    'AppCoverArt keeps fallback title above external bottom reserve',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 180,
              child: AppCoverArt(
                title: 'Fallback Book Title',
                seed: 'book-1',
                bottomReserve: 40,
                showMatte: false,
                height: 180,
                width: 120,
              ),
            ),
          ),
        ),
      );

      final coverRect = tester.getRect(find.byType(AppCoverArt));
      final titleRect = tester.getRect(find.text('Fallback Book Title'));

      expect(titleRect.bottom, lessThanOrEqualTo(coverRect.bottom - 40));
    },
  );

  testWidgets('AppCoverArt can top-align fallback title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 180,
            child: AppCoverArt(
              title: 'Top Book Title',
              seed: 'book-1',
              topAlignText: true,
              bottomReserve: 40,
              showMatte: false,
              height: 180,
              width: 120,
            ),
          ),
        ),
      ),
    );

    final coverRect = tester.getRect(find.byType(AppCoverArt));
    final titleRect = tester.getRect(find.text('Top Book Title'));

    expect(titleRect.top, lessThan(coverRect.top + 40));
  });

  testWidgets('AppCoverArt respects external top reserve', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 180,
            child: AppCoverArt(
              title: 'Reserved Book Title',
              seed: 'book-1',
              topAlignText: true,
              topReserve: 44,
              bottomReserve: 40,
              showMatte: false,
              height: 180,
              width: 120,
            ),
          ),
        ),
      ),
    );

    final coverRect = tester.getRect(find.byType(AppCoverArt));
    final titleRect = tester.getRect(find.text('Reserved Book Title'));

    expect(titleRect.top, greaterThanOrEqualTo(coverRect.top + 44));
  });

  testWidgets('AppImageAspectRatio uses fallback ratio without image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: AppImageAspectRatio(
              fallbackAspectRatio: 2 / 3,
              child: ColoredBox(color: Colors.red),
            ),
          ),
        ),
      ),
    );

    final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspectRatio.aspectRatio, 2 / 3);
  });

  testWidgets('AppImageAspectRatio uses decoded image ratio', (tester) async {
    final image = _TestImageProvider(wideImage);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: AppImageAspectRatio(
              image: image,
              fallbackAspectRatio: 2 / 3,
              child: const ColoredBox(color: Colors.red),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspectRatio.aspectRatio, 2);
  });

  testWidgets('ActionBottomSheetLayout renders title and child', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActionBottomSheetLayout(
            title: 'Sheet',
            child: Text('Body'),
          ),
        ),
      ),
    );

    expect(find.text('Sheet'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('ActionBottomSheetLayout renders optional header action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActionBottomSheetLayout(
            title: 'Sheet',
            headerTrailing: Text('Reset'),
            child: Text('Body'),
          ),
        ),
      ),
    );

    expect(find.text('Sheet'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('showAppBottomSheet calls onFullyHidden after exit animation', (
    tester,
  ) async {
    var fullyHidden = false;
    final systemCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          systemCalls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(
                      showAppBottomSheet<void>(
                        context,
                        onFullyHidden: () => fullyHidden = true,
                        builder: (sheetContext) {
                          return SizedBox(
                            height: 120,
                            child: Center(
                              child: TextButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                child: const Text('Close sheet'),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Open sheet'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    final restoresAfterOpen = systemCalls
        .where((call) => call.method == 'SystemChrome.restoreSystemUIOverlays')
        .length;
    expect(restoresAfterOpen, greaterThan(0));

    await tester.tap(find.text('Close sheet'));
    await tester.pump();

    expect(fullyHidden, isFalse);

    await tester.pumpAndSettle();

    expect(fullyHidden, isTrue);
    expect(
      systemCalls
          .where(
            (call) => call.method == 'SystemChrome.restoreSystemUIOverlays',
          )
          .length,
      greaterThan(restoresAfterOpen),
    );
  });

  testWidgets('showAppBottomSheet reserves minimum bottom spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.zero),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(
                        showAppBottomSheet<void>(
                          context,
                          builder: (_) => const SizedBox(
                            height: 80,
                            child: Text('Sheet content'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open sheet'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    final safeArea = tester.widget<AppBottomSafeArea>(
      find.byType(AppBottomSafeArea),
    );
    expect(safeArea.minimumBottom, AppSpacing.lg);
    expect(find.text('Sheet content'), findsOneWidget);
  });

  testWidgets('AppBottomActionBar renders provided actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: AppBottomActionBar(
            children: [
              IconButton(
                icon: const Icon(AppIcons.back),
                onPressed: () {},
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(AppIcons.bookmark),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(AppBottomActionBar), findsOneWidget);
    expect(find.byIcon(AppIcons.back), findsOneWidget);
    expect(find.byIcon(AppIcons.bookmark), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppBottomActionBar)).height,
      AppSizes.navBarHeight + AppSpacing.lg,
    );

    final decoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(AppBottomActionBar),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;

    expect(decoration.boxShadow, isNull);
    expect(decoration.border, isA<Border>());
  });

  testWidgets('SelectionPreviewCard renders selected text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SelectionPreviewCard(text: 'Selected text'),
        ),
      ),
    );

    expect(find.text('Selected text'), findsOneWidget);
  });

  testWidgets('ButtonLoadingIndicator renders progress indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ButtonLoadingIndicator(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
  testWidgets('EmptyState renders icon, message, and subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.book,
            message: 'No items',
            subtitle: 'Add something',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.book), findsOneWidget);
    expect(find.text('No items'), findsOneWidget);
    expect(find.text('Add something'), findsOneWidget);
  });

  testWidgets('EmptyState renders message only when no icon or subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(message: 'Empty'),
        ),
      ),
    );

    expect(find.text('Empty'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('SearchField renders hint text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchField(hintText: 'Search...'),
        ),
      ),
    );

    expect(find.text('Search...'), findsOneWidget);
  });

  testWidgets('SearchField calls onChanged when text entered', (
    tester,
  ) async {
    String? lastQuery;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchField(
            hintText: 'Search...',
            onChanged: (q) => lastQuery = q,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    expect(lastQuery, 'hello');
  });

  testWidgets('AppBadge renders label with correct colors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppBadge(
            label: 'PRO',
            foreground: Colors.white,
            background: Colors.purple,
          ),
        ),
      ),
    );

    expect(find.text('PRO'), findsOneWidget);
  });

  testWidgets('SectionLabel renders uppercase label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionLabel(label: 'GENERAL'),
        ),
      ),
    );

    expect(find.text('GENERAL'), findsOneWidget);
  });

  testWidgets('SettingsGroup renders children with dividers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SettingsGroup(
            children: [
              const Text('Row 1'),
              const Text('Row 2'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Row 1'), findsOneWidget);
    expect(find.text('Row 2'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('SettingsRow renders icon, label, and detail', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsRow(
            icon: Icons.settings,
            label: 'Font',
            detail: 'Inter',
            onTap: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Font'), findsOneWidget);
    expect(find.text('Inter'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('StatCard with icon renders icon, value, and label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            icon: Icons.book,
            value: '42',
            label: 'Books',
            color: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.book), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
  });

  testWidgets('StatCard without icon renders bordered container', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(value: '0h', label: 'Read time'),
        ),
      ),
    );

    expect(find.text('0h'), findsOneWidget);
    expect(find.text('Read time'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });
  testWidgets('BottomSheetHeader renders title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BottomSheetHeader(title: 'Title'),
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('CenteredCircularProgressIndicator renders indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CenteredCircularProgressIndicator(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ErrorState renders message and retry button', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorState(
            message: 'Something went wrong',
            retryLabel: 'Retry',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('ScrollEdgeFade renders with top edge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScrollEdgeFade(visible: true),
        ),
      ),
    );

    expect(find.byType(ScrollEdgeFade), findsOneWidget);
    expect(find.byType(AnimatedOpacity), findsOneWidget);
  });

  testWidgets('ScrollEdgeFade hides when not visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScrollEdgeFade(visible: false),
        ),
      ),
    );

    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, 0);
  });

  testWidgets('MediaCollectionCard renders title and subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: MediaCollectionCard(
              media: const ColoredBox(color: Colors.blue),
              title: 'Card Title',
              subtitle: 'Card Subtitle',
              meta: 'EPUB',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Card Title'), findsOneWidget);
    expect(find.text('Card Subtitle'), findsOneWidget);
    expect(find.text('EPUB'), findsOneWidget);
  });

  testWidgets('MediaCollectionCard renders without optional fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: MediaCollectionCard(
              media: const ColoredBox(color: Colors.blue),
              title: 'Title Only',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Title Only'), findsOneWidget);
  });

  testWidgets('OfflineBanner renders default message and icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: OfflineBanner()),
      ),
    );

    expect(find.text('Offline'), findsOneWidget);
    expect(find.byIcon(AppIcons.offline), findsOneWidget);
  });

  testWidgets('OfflineBanner renders custom message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: OfflineBanner(message: 'No connection'),
        ),
      ),
    );

    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('MediaCollectionCard calls onTap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: MediaCollectionCard(
              media: const ColoredBox(color: Colors.blue),
              title: 'Tappable',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tappable'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('AppFilterChip exposes a 48dp tap target around 32dp body', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppFilterChip(
              label: 'All',
              selected: true,
              onTap: _noop,
            ),
          ),
        ),
      ),
    );

    final tapBoxSize = tester.getSize(find.byType(AppFilterChip));
    expect(tapBoxSize.height, AppSizes.chipTapTarget);

    final visibleBodySize = tester.getSize(
      find.descendant(
        of: find.byType(AppFilterChip),
        matching: find.byType(Material).last,
      ),
    );
    expect(visibleBodySize.height, AppSizes.chipHeight);
  });

  testWidgets('AppFilterChip onTap fires from the padding above the body', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppFilterChip(
              label: 'All',
              selected: false,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    // Tap 4dp from the top of the 48dp tap box — squarely inside the
    // 8dp invisible pad, outside the visible 32dp chip body.
    final topLeft = tester.getTopLeft(find.byType(AppFilterChip));
    final size = tester.getSize(find.byType(AppFilterChip));
    await tester.tapAt(Offset(topLeft.dx + size.width / 2, topLeft.dy + 4));
    expect(taps, 1);
  });

  testWidgets('SearchField clear button hit area matches base button height', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'query');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SearchField(
            hintText: 'Search...',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump();

    final clearIcon = find.byIcon(AppIcons.close);
    expect(clearIcon, findsOneWidget);
    final hitArea = tester.getSize(
      find.ancestor(of: clearIcon, matching: find.byType(GestureDetector)),
    );
    expect(hitArea.width, greaterThanOrEqualTo(AppSizes.buttonHeight));
    expect(hitArea.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
  });

  testWidgets(
    'MarkedText renders marked ranges without marker brackets',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: MarkedText(text: 'She [[looked up]] the word.'),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      expect(richText.text.toPlainText(), 'She looked up the word.');
      expect(
        MarkedText.stripMarkers('She [[looked up]] the word.'),
        'She looked up the word.',
      );

      final rootSpan = richText.text as TextSpan;
      TextSpan? markedSpan;
      rootSpan.visitChildren((span) {
        if (span is TextSpan && span.text == 'looked up') {
          markedSpan = span;
        }
        return true;
      });
      expect(markedSpan?.style?.fontWeight, FontWeight.w700);
    },
  );
}

void _noop() {}

class _TestImageProvider extends ImageProvider<_TestImageProvider> {
  const _TestImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_TestImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_TestImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _TestImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.value(ImageInfo(image: key.image.clone())),
    );
  }
}

class _FailingImageProvider extends ImageProvider<_FailingImageProvider> {
  const _FailingImageProvider(this.label);

  final String label;

  @override
  Future<_FailingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_FailingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _FailingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(
        StateError('Failed to decode $label'),
        StackTrace.current,
      ),
    );
  }

  @override
  String toString() => 'FailingImageProvider($label)';
}
