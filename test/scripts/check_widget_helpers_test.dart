import 'dart:io';

import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../scripts/check_widget_helpers.dart' show findWidgetHelpers;

// Resolved inside the app package, so Flutter types are real; the overlay
// never touches the disk.
const _fixture = '''
import 'package:flutter/material.dart';

typedef StepBuilder = Widget Function(BuildContext context);

Widget topLevel() => const SizedBox();

Future<Widget> later() async => const SizedBox();

String title() => '';

abstract class Contract {
  Widget icon(BuildContext context);
}

class Probe extends StatefulWidget {
  const Probe({super.key});

  static Text caption() => const Text('');

  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  Widget get header => const SizedBox();

  set footer(Widget value) {}

  Widget _section() => const SizedBox();

  List<Widget> _rows() => const [];

  Iterable<Widget>? _maybeRows() => null;

  Widget Function() _factory() => () => const SizedBox();

  @override
  Widget build(BuildContext context) {
    item() => const Text('inferred');
    ButtonStyle style() => const ButtonStyle();
    return Builder(builder: (context) => item());
  }
}

extension on BuildContext {
  Widget padded(Widget child) => Padding(padding: EdgeInsets.zero, child: child);
}
''';

void main() {
  test(
    'finds functions, methods and getters that return widgets',
    () async {
      final path = File(
        '${Directory.current.path}/lib/widget_helper_fixture.dart',
      ).absolute.path;
      final resources = OverlayResourceProvider(
        PhysicalResourceProvider.INSTANCE,
      )..setOverlay(path, content: _fixture, modificationStamp: 0);

      final helpers = await findWidgetHelpers([
        path,
      ], resourceProvider: resources);

      expect(
        [for (final helper in helpers) '${helper.name}: ${helper.type}'],
        [
          'topLevel: Widget',
          'caption: Text',
          'header: Widget',
          '_section: Widget',
          '_rows: List<Widget>',
          '_maybeRows: Iterable<Widget>?',
          'item: Text',
          'padded: Widget',
        ],
      );
      expect(helpers.map((helper) => helper.path), everyElement(path));
      expect(helpers.first.line, 5);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'reports nothing for code without helpers',
    () async {
      final path = File(
        '${Directory.current.path}/lib/widget_helper_clean_fixture.dart',
      ).absolute.path;
      final resources =
          OverlayResourceProvider(PhysicalResourceProvider.INSTANCE)
            ..setOverlay(
              path,
              content: '''
import 'package:flutter/widgets.dart';

class Clean extends StatelessWidget {
  const Clean({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''',
              modificationStamp: 0,
            );

      expect(
        await findWidgetHelpers([path], resourceProvider: resources),
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
