import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_highlight_effect_listener.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  for (final fail in [false, true]) {
    testWidgets('delete feedback awaits storage (failure=$fail)', (
      tester,
    ) async {
      final repository = _DelayedDeleteRepository()..shouldThrow = fail;
      final bloc = ReaderBloc(
        bookRepository: FakeBookRepository(),
        highlightRepository: repository,
        initialSource: Book(
          id: 'b',
          title: 'Book',
          filePath: '/book.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
        ),
      );
      addTearDown(bloc.close);
      var childBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          home: ToastWrapper(
            child: BlocProvider.value(
              value: bloc,
              child: ReaderHighlightEffectListener(
                child: Builder(
                  builder: (_) {
                    childBuilds++;
                    return Scaffold(
                      body: TextButton(
                        onPressed: () => bloc.add(
                          const ReaderHighlightDeleteRequested(
                            highlightId: 'h',
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete'));
      await tester.pump();
      expect(find.text('Highlight removed'), findsNothing);
      expect(find.text('Failed to delete the item'), findsNothing);
      expect(bloc.state.highlightEffect, isNull);
      repository.release.complete();
      await tester.pump();
      final message = find.text(
        fail ? 'Failed to delete the item' : 'Highlight removed',
      );
      for (var frame = 0; frame < 10 && message.evaluate().isEmpty; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(bloc.state.highlightEffect?.success, !fail);
      expect(
        message,
        findsOneWidget,
      );
      expect(
        childBuilds,
        1,
        reason: 'Mutation feedback must not rebuild reader content',
      );
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });
  }
}

class _DelayedDeleteRepository extends FakeHighlightRepository {
  final release = Completer<void>();

  @override
  Future<void> deleteHighlight(String id) async {
    await release.future;
    await super.deleteHighlight(id);
  }
}
