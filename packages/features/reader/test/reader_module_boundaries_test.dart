import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sourceDirectory =
      [
            Directory('lib/src'),
            Directory('packages/features/reader/lib/src'),
          ]
          .firstWhere(
            (directory) =>
                File('${directory.path}/reader_screen.dart').existsSync(),
          )
          .absolute;
  final sources = {
    for (final file
        in sourceDirectory.listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart'))
        file.uri.path.substring(sourceDirectory.uri.path.length): file
            .readAsStringSync(),
  };
  final dependencies = {
    for (final entry in sources.entries)
      entry.key: _importsAndExports(entry.value),
  };

  test(
    'screen composition has no parts, engines or format-body dependencies',
    () {
      expect(sources['reader_screen.dart'], isNot(matches(r'\bpart\s')));
      expect(
        dependencies['reader_screen.dart'],
        isNot(anyElement(contains('pagecraft/'))),
      );
      expect(
        dependencies['reader_screen.dart'],
        isNot(anyElement(endsWith('_body.dart'))),
      );
      for (final entry in sources.entries) {
        expect(
          entry.value,
          isNot(contains("part of 'reader_screen.dart'")),
          reason: entry.key,
        );
      }
    },
  );

  test('format hosts cannot import the screen or another format host', () {
    for (final kind in ['text', 'article', 'comic', 'pdf', 'djvu']) {
      final host = 'reader_screen_${kind}_body.dart';
      final forbidden = dependencies[host]!.where(
        (uri) =>
            uri == 'reader_screen.dart' ||
            uri == 'reader_screen_content.dart' ||
            uri == 'reader_screen_chrome.dart' ||
            uri == 'reader_screen_drawers.dart' ||
            uri == 'reader_screen_context_panel.dart' ||
            uri.endsWith('_body.dart'),
      );
      expect(forbidden, isEmpty, reason: host);
      if (kind != 'text') {
        final engineImports = dependencies[host]!.where(
          (uri) => uri.startsWith('package:pagecraft/'),
        );
        expect(engineImports, ['package:pagecraft/$kind.dart'], reason: host);
      }
    }
  });

  test('document contract does not depend on Flutter, blocs or storage', () {
    expect(
      dependencies['reader_document.dart'],
      unorderedEquals([
        'package:domain_models/domain_models.dart',
        'package:equatable/equatable.dart',
      ]),
    );
    expect(sources['reader_document.dart'], isNot(matches(r'\bpart\s')));
  });

  test(
    'format policy is pure data independent of engines and state owners',
    () {
      expect(dependencies['reader_format_capabilities.dart'], [
        'package:domain_models/domain_models.dart',
      ]);
    },
  );

  test(
    'format classification stays outside presentation and progress helpers',
    () {
      for (final file in [
        'reader_chrome_actions.dart',
        'reader_contents_tabs.dart',
        'reader_progress_label.dart',
        'reader_selection_tip_cubit.dart',
        'reader_screen_chrome.dart',
        'reader_screen_content.dart',
        'reader_screen_drawers.dart',
        'reader_image_page_progress_overlay.dart',
      ]) {
        expect(sources[file], isNot(matches(r'BookFormat\.\w+')), reason: file);
      }
    },
  );

  test('shared page policies do not depend on renderer hosts or screen UI', () {
    for (final helper in [
      'reader_page_input.dart',
      'reader_page_location.dart',
      'reader_page_turn.dart',
      'reader_text_style.dart',
      'reader_text_annotations.dart',
      'reader_search_navigator.dart',
    ]) {
      expect(
        dependencies[helper],
        isNot(anyElement(startsWith('reader_screen'))),
        reason: helper,
      );
    }
  });

  test('reader library import/export graph stays acyclic', () {
    final visited = <String>{};
    final active = <String>[];
    void visit(String file) {
      expect(
        active,
        isNot(contains(file)),
        reason: 'Cycle: ${[...active, file].join(' -> ')}',
      );
      if (!visited.add(file)) return;
      active.add(file);
      for (final dependency in dependencies[file] ?? const <String>[]) {
        final uri = Uri.parse(dependency);
        if (uri.hasScheme) continue;
        final resolved = Uri.parse(file).resolveUri(uri).path;
        if (sources.containsKey(resolved)) visit(resolved);
      }
      active.removeLast();
    }

    for (final file in sources.keys) {
      visit(file);
    }
  });
}

List<String> _importsAndExports(String source) => [
  for (final match in RegExp(
    r'''^(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  ).allMatches(source))
    match.group(1)!,
];
