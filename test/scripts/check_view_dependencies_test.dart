import 'dart:convert';
import 'dart:io';

import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../scripts/check_widget_helpers.dart'
    show ViewDependency, findViewDependencies;

void main() {
  test(
    'finds View fields and constructor arguments through resolved types',
    () async {
      final dependencies = await _check('''
import 'package:flutter/widgets.dart';
import 'package:book_repository/book_repository.dart' as books;
import 'package:preferences_service/preferences_service.dart';

typedef Store = books.BookRepository;
abstract class DataSource implements books.BookRepository {}

abstract class EntryView extends StatelessWidget {
  EntryView(this.store, {PreferencesService? service});
  final Store store;
}

abstract class ConstructorView extends StatelessWidget {
  ConstructorView(books.BookRepository repository);
}

abstract class WrappedView extends StatelessWidget {
  WrappedView(this.repositories);
  final Map<String, List<DataSource?>> repositories;
}

abstract class RecordView extends StatelessWidget {
  RecordView(this.positional, this.named);
  final (books.BookRepository, int) positional;
  final ({PreferencesService service, int count}) named;
}

abstract class GenericView<T extends books.BookRepository>
    extends StatelessWidget {
  GenericView(this.store);
  final T store;
}

abstract class WidgetBase extends StatelessWidget {
  const WidgetBase({required this.repository});
  final books.BookRepository repository;
}

abstract class SuperView extends WidgetBase {
  const SuperView({required super.repository});
}
''');

      expect(dependencies.map((dependency) => dependency.name), [
        'EntryView.service',
        'EntryView.store',
        'ConstructorView.repository',
        'WrappedView.repositories',
        'RecordView.positional',
        'RecordView.named',
        'GenericView.store',
        'SuperView.repository',
      ]);
      expect(
        dependencies.singleWhere((d) => d.name == 'EntryView.store').line,
        10,
      );
      expect(
        dependencies.singleWhere((d) => d.name == 'GenericView.store').type,
        'T',
      );
      expect(dependencies.map((d) => d.path), everyElement(_fixturePath));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'checks the State of a View through an intermediate generic base',
    () async {
      final dependencies = await _check('''
import 'package:flutter/widgets.dart';
import 'package:preferences_service/preferences_service.dart';

abstract class PreferencesProxy implements PreferencesService {}
abstract class ProbeView extends StatefulWidget {}
abstract class IntermediateState<T extends StatefulWidget> extends State<T> {}

abstract class UnusuallyNamedState extends IntermediateState<ProbeView> {
  late PreferencesProxy preferences;
}

abstract class WidgetHost extends StatefulWidget {}
abstract class HostState extends State<WidgetHost> {
  late PreferencesService preferences;
}
''');

      expect(dependencies.map((dependency) => dependency.name), [
        'UnusuallyNamedState.preferences',
      ]);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'recognizes storage, network and parser resources including inferred fields',
    () async {
      final dependencies = await _check('''
import 'dart:io' as io;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' as db;
import 'package:local_storage/local_storage.dart';
import 'package:pagecraft/all_formats.dart';

abstract class Transport implements http.Client {}
class ContentParser {}

abstract class ResourceView extends StatelessWidget {
  ResourceView(
    this.transport, this.ioConnection, this.database, this.applicationDatabase, this.book,
    this.source, this.parser, this.archive,
  );
  final Transport transport;
  final io.HttpClient ioConnection;
  final db.GeneratedDatabase database;
  final AppDatabase applicationDatabase;
  final EpubBook book;
  final TextBookSource source;
  final ContentParser parser;
  final ZipArchive archive;
  final connection = http.Client();
}
''');

      expect(dependencies.map((dependency) => dependency.name), [
        'ResourceView.transport',
        'ResourceView.ioConnection',
        'ResourceView.database',
        'ResourceView.applicationDatabase',
        'ResourceView.book',
        'ResourceView.source',
        'ResourceView.parser',
        'ResourceView.archive',
        'ResourceView.connection',
      ]);
      expect(dependencies.last.type, 'Client');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'allows payloads, UI contracts, composition and renderer hosts',
    () async {
      final dependencies = await _check('''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:book_repository/book_repository.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:domain_models/domain_models.dart';
import 'package:pagecraft/epub.dart';

abstract class ContentView extends StatelessWidget {
  ContentView(
    this.preferences, this.definition, this.translation, this.book,
    this.textController, this.menuController, this.inputClient,
    this.metadata, this.onChanged, this.onSave, this.createdAt,
  );
  final ReaderAppearancePreferences preferences;
  final DictionaryLookupResult definition;
  final ContextualTranslationResult translation;
  final Book book;
  final TextEditingController textController;
  final MenuController menuController;
  final TextInputClient inputClient;
  final EpubMetadata metadata;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSave;
  final DateTime createdAt;
}

abstract class ImportScreen extends StatelessWidget {
  ImportScreen(this.repository);
  final BookRepository repository;
}

abstract class ImportSheet extends StatelessWidget {
  ImportSheet(this.service);
  final PreferencesService service;
}

abstract class RenderHost extends StatelessWidget {
  RenderHost(this.book);
  final EpubBook book;
}

class CopyTextAction {
  CopyTextAction(this.service);
  final PreferencesService service;
}

class DataView {
  DataView(this.repository);
  final BookRepository repository;
}
''');

      expect(dependencies, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'restricts the View dependency rule to feature production paths',
    () async {
      final dependencies = await _check('''
import 'package:flutter/widgets.dart';
import 'package:book_repository/book_repository.dart';

abstract class InfrastructureView extends StatelessWidget {
  InfrastructureView(this.repository);
  final BookRepository repository;
}
''', path: '${Directory.current.path}/lib/view_dependency_fixture.dart');

      expect(dependencies, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

String get _fixturePath => File(
  '${Directory.current.path}/packages/features/reader/lib/'
  'view_dependency_fixture.dart',
).absolute.path;

Future<List<ViewDependency>> _check(String source, {String? path}) {
  final fixture = File(path ?? _fixturePath).absolute.path;
  final resources = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE)
    ..setOverlay(fixture, content: source, modificationStamp: 0);
  // Use the app's resolved graph for service DTO fixtures without depending on
  // the Reader's intentionally narrower production dependency list.
  final packageConfig = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  final config =
      jsonDecode(packageConfig.readAsStringSync()) as Map<String, Object?>;
  final packages = (config['packages'] as List<Object?>)
      .cast<Map<String, Object?>>();
  for (final package in packages) {
    package['rootUri'] = packageConfig.uri
        .resolve(package['rootUri'] as String)
        .toString();
  }
  resources.setOverlay(
    '${Directory.current.path}/packages/features/reader/'
    '.dart_tool/package_config.json',
    content: jsonEncode(config),
    modificationStamp: 0,
  );
  return findViewDependencies([fixture], resourceProvider: resources);
}
