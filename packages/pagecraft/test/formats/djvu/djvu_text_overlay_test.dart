import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagecraft/djvu.dart';

void main() {
  testWidgets(
    'long press selects a word and handle dragging extends by words',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = FixedPagesController(pageCount: 1, rtl: false);
      addTearDown(controller.dispose);
      final selection = DjvuTextSelection();
      addTearDown(selection.dispose);
      final events = <DjvuTextRange>[];
      final layer = DjvuTextLayer.fromJson(0, {
        'width': 400,
        'height': 600,
        'words': [
          {'text': 'First', 'x': 40, 'y': 100, 'width': 80, 'height': 30},
          {'text': 'second', 'x': 140, 'y': 100, 'width': 100, 'height': 30},
          {'text': 'third', 'x': 260, 'y': 100, 'width': 80, 'height': 30},
        ],
      });
      await tester.pumpWidget(
        _OverlayHost(
          controller: controller,
          selection: selection,
          layer: layer,
          onChanged: (range, _) => events.add(range),
        ),
      );
      await tester.longPressAt(const Offset(60, 115));
      await tester.pump();
      expect(selection.range, const DjvuTextRange(0, 5));
      expect(events.last, const DjvuTextRange(0, 5));
      expect(controller.inputLocked, isTrue);

      // The second handle starts at the selected word's bottom-right corner.
      await tester.dragFrom(const Offset(120, 130), const Offset(180, -15));
      await tester.pump();
      expect(selection.range, const DjvuTextRange(0, 18));
      expect(layer.textOf(selection.range!), 'First second third');
      expect(events.last, const DjvuTextRange(0, 18));
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(selection.isActive, isFalse);
      expect(controller.inputLocked, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

class _OverlayHost extends StatelessWidget {
  const _OverlayHost({
    required this.controller,
    required this.selection,
    required this.layer,
    required this.onChanged,
  });

  final FixedPagesController controller;
  final DjvuTextSelection selection;
  final DjvuTextLayer layer;
  final DjvuSelectionChanged onChanged;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox.expand(
      child: DjvuTextOverlay(
        page: 0,
        imageRect: const Rect.fromLTWH(0, 0, 400, 600),
        pageWidth: 400,
        pageHeight: 600,
        controller: controller,
        selection: selection,
        layer: layer,
        onSelectionChanged: onChanged,
      ),
    ),
  );
}
