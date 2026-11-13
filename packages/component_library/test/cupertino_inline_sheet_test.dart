import 'package:component_library/component_library.dart';
import 'package:component_library/src/app_cupertino_sheet_surface.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _phone = Size(390, 844);
const _safeInsets = FakeViewPadding(top: 47, bottom: 34);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Cupertino inline card shares modal framing in $brightness', (
      tester,
    ) async {
      await _pumpHost(tester, brightness: brightness);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final card = find.byType(AppCupertinoSheetSurface);
      final bounds = tester.getRect(card);
      expect(bounds.left, 8);
      expect(bounds.right, 382);
      expect(bounds.bottom, 844 - 34);
      expect(bounds.height, closeTo((844 - 34 - 47 - 8) * .6, .01));
      final popup = tester.widget<CupertinoPopupSurface>(
        find.byType(CupertinoPopupSurface),
      );
      expect(popup.blurSigma, 0);
      expect(popup.isSurfacePainted, isFalse);
      final context = tester.element(card);
      expect(context.appTheme.sheetColor.a, 1);
      expect(
        tester
            .widget<ColoredBox>(
              find
                  .descendant(of: card, matching: find.byType(ColoredBox))
                  .first,
            )
            .color,
        context.appTheme.sheetColor,
      );
      expect(
        tester
            .widget<ModalBarrier>(
              find.descendant(
                of: find.byType(AppInlineSheet),
                matching: find.byType(ModalBarrier),
              ),
            )
            .color,
        brightness == Brightness.dark
            ? const Color(0x7A000000)
            : const Color(0x33000000),
      );
      final body = tester.state<_RetainedBodyState>(find.byType(_RetainedBody));
      expect(body.bottomPadding, 0);
      expect(body.keyboardInset, 0);
      await tester.drag(find.text('Contents'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(card).top, 47 + 8);
      expect(tester.getRect(card).bottom, 844 - 34);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Cupertino centered card caps its width at 540', (tester) async {
    await _pumpHost(tester, size: const Size(800, 1024));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final bounds = tester.getRect(find.byType(AppCupertinoSheetSurface));
    expect(bounds.width, 540);
    expect(bounds.center.dx, 400);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Cupertino keyboard, panel resize and reopen retain editor/list',
    (
      tester,
    ) async {
      await _pumpHost(tester);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(AppTextField), 'Chapter 12');
      final editor = tester.state(find.byType(EditableText));
      final body = tester.state<_RetainedBodyState>(find.byType(_RetainedBody));
      body.scroll.jumpTo(200);
      await tester.pump();
      tester.view
        ..viewInsets = const FakeViewPadding(bottom: 291)
        ..padding = const FakeViewPadding(top: 47);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(AppCupertinoSheetSurface)).bottom,
        844 - 291 - 8,
      );
      expect(body.bottomPadding, 0);
      expect(body.keyboardInset, 0);
      expect(tester.state(find.byType(EditableText)), same(editor));
      expect(body.focus.hasFocus, isTrue);
      tester.view
        ..physicalSize = const Size(1024, 1366)
        ..viewInsets = const FakeViewPadding()
        ..padding = _safeInsets;
      await tester.pumpAndSettle();
      expect(find.byType(AppCupertinoSheetSurface), findsNothing);
      final panel = tester.getRect(find.byType(AppSurface));
      expect(panel.width, 420);
      expect(panel.right, 1024);
      expect(panel.top, 47);
      expect(panel.bottom, 1366);
      expect(tester.state(find.byType(EditableText)), same(editor));
      expect(body.focus.hasFocus, isTrue);
      expect(body.field.text, 'Chapter 12');
      expect(body.scroll.offset, 200);
      tester.view.physicalSize = _phone;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(EditableText)), same(editor));
      expect(body.focus.hasFocus, isTrue);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AppCupertinoSheetSurface), findsNothing);
      expect(body.focus.hasFocus, isFalse);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(EditableText)), same(editor));
      expect(body.field.text, 'Chapter 12');
      expect(body.scroll.offset, 200);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cupertino inline sheet settles immediately with reduced motion',
    (
      tester,
    ) async {
      await _pumpHost(tester, reduceMotion: true);
      await tester.tap(find.text('Open'));
      await tester.pump();
      final card = find.byType(AppCupertinoSheetSurface);
      final bounds = tester.getRect(card);
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getRect(card), bounds);
      await tester.tapAt(const Offset(195, 120));
      await tester.pump();
      await tester.pump();
      expect(card, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  Size size = _phone,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = _safeInsets
    ..viewPadding = _safeInsets;
  addTearDown(tester.view.reset);
  final adapter = AppTheme.forPlatform(TargetPlatform.iOS, brightness);
  await tester.pumpWidget(
    CupertinoApp(
      theme: AppTheme.cupertino(adapter),
      builder: (context, child) => AppPlatformTheme(
        platform: TargetPlatform.iOS,
        brightness: brightness,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(reduceMotion: reduceMotion),
          child: child!,
        ),
      ),
      home: const CupertinoPageScaffold(
        resizeToAvoidBottomInset: false,
        child: _NativeInlineHost(),
      ),
    ),
  );
}

class _NativeInlineHost extends StatefulWidget {
  const _NativeInlineHost();

  @override
  State<_NativeInlineHost> createState() => _NativeInlineHostState();
}

class _NativeInlineHostState extends State<_NativeInlineHost> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Align(
        alignment: Alignment.topCenter,
        child: CupertinoButton(
          onPressed: () => setState(() => _visible = true),
          child: const Text('Open'),
        ),
      ),
      Positioned.fill(
        child: AppInlineSheet(
          visible: _visible,
          semanticsLabel: 'Contents',
          onClose: () => setState(() => _visible = false),
          header: BottomSheetHeader(
            title: 'Contents',
            closeLabel: 'Close',
            onClose: () => setState(() => _visible = false),
          ),
          body: const _RetainedBody(),
        ),
      ),
    ],
  );
}

class _RetainedBody extends StatefulWidget {
  const _RetainedBody();

  @override
  State<_RetainedBody> createState() => _RetainedBodyState();
}

class _RetainedBodyState extends State<_RetainedBody> {
  final field = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  double? bottomPadding;
  double? keyboardInset;

  @override
  void dispose() {
    field.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bottomPadding = MediaQuery.paddingOf(context).bottom;
    keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Column(
      children: [
        AppTextField(controller: field, focusNode: focus),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            itemCount: 50,
            itemBuilder: (_, index) => SizedBox(
              height: 48,
              child: Text('Chapter $index'),
            ),
          ),
        ),
      ],
    );
  }
}
