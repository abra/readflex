import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_comic_thumbnail_cubit.dart';
import 'package:reader/src/reader_image_highlight_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List bytes;
  const boundaryKey = ValueKey('crop');
  const left = HighlightImageArea(
    pageIndex: 0,
    x: 0,
    y: 0,
    width: .5,
    height: 1,
  );
  const right = HighlightImageArea(
    pageIndex: 0,
    x: .5,
    y: 0,
    width: .5,
    height: 1,
  );

  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      const Rect.fromLTWH(100, 0, 100, 100),
      Paint()..color = Colors.blue,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 100);
    bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
  });

  Future<void> pump(
    WidgetTester tester,
    ReaderComicThumbnailCubit cubit,
    HighlightImageArea area,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: BlocProvider.value(
              value: cubit,
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox.square(
                  dimension: 100,
                  child: ReaderImageHighlightPreview(area: area),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<Uint8List> pixels(WidgetTester tester) async {
    final context = tester.element(find.byType(ReaderImageHighlightPreview));
    await tester.runAsync(() => precacheImage(MemoryImage(bytes), context));
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        return (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    }))!;
  }

  List<int> rgb(Uint8List data, int x, int y) =>
      data.sublist((y * 100 + x) * 4, (y * 100 + x) * 4 + 3);
  final red = [
    Colors.red.r * 255,
    Colors.red.g * 255,
    Colors.red.b * 255,
  ].map((v) => v.round()).toList();
  final blue = [
    Colors.blue.r * 255,
    Colors.blue.g * 255,
    Colors.blue.b * 255,
  ].map((v) => v.round()).toList();

  testWidgets(
    'different areas share one page decode and paint only their crop',
    (tester) async {
      var calls = 0;
      final cubit = ReaderComicThumbnailCubit((_) async {
        calls++;
        return bytes;
      });
      addTearDown(cubit.close);
      await pump(tester, cubit, left);
      var data = await pixels(tester);
      expect(rgb(data, 5, 5), red);
      expect(rgb(data, 95, 95), red);
      await pump(tester, cubit, right);
      data = await pixels(tester);
      expect(rgb(data, 5, 5), blue);
      expect(rgb(data, 95, 95), blue);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('preserves aspect ratio and clamps legacy areas to the image', (
    tester,
  ) async {
    final cubit = ReaderComicThumbnailCubit((_) async => bytes);
    addTearDown(cubit.close);
    await pump(
      tester,
      cubit,
      const HighlightImageArea(pageIndex: 0, x: 0, y: 0, width: 1, height: 1),
    );
    var data = await pixels(tester);
    expect(rgb(data, 5, 50), red);
    expect(rgb(data, 95, 50), blue);
    expect(rgb(data, 5, 5), isNot(red));
    await pump(
      tester,
      cubit,
      const HighlightImageArea(
        pageIndex: 0,
        x: .75,
        y: 0,
        width: .5,
        height: 1,
      ),
    );
    data = await pixels(tester);
    expect(rgb(data, 50, 50), blue);
    expect(rgb(data, 5, 50), isNot(blue));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'loading and failure keep geometry; retry is local and late completion is discarded',
    (tester) async {
      final pending = Completer<Uint8List?>();
      var calls = 0;
      final cubit = ReaderComicThumbnailCubit(
        (_) async => ++calls == 1 ? null : pending.future,
      );
      addTearDown(cubit.close);
      await pump(tester, cubit, left);
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byKey(boundaryKey));
      expect(size, const Size.square(100));
      await tester.tap(find.byTooltip('Retry'));
      await tester.pump();
      expect(tester.getSize(find.byKey(boundaryKey)), size);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(bytes);
      await tester.pump();
      expect(cubit.state.containsKey(0), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing pages releases the old request; malformed crops stay local',
    (tester) async {
      final calls = <int>[];
      final pending = Completer<Uint8List?>();
      final cubit = ReaderComicThumbnailCubit((page) async {
        calls.add(page);
        return page == 0 ? pending.future : bytes;
      });
      addTearDown(cubit.close);
      await pump(tester, cubit, left);
      await pump(
        tester,
        cubit,
        const HighlightImageArea(
          pageIndex: 2,
          x: double.nan,
          y: 0,
          width: 1,
          height: 1,
        ),
      );
      pending.complete(bytes);
      await pixels(tester);
      expect(calls, [0, 2]);
      expect(cubit.state.containsKey(0), isFalse);
      expect(find.byIcon(AppIcons.book), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
