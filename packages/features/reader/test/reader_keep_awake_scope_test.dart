import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:screen_control_service/screen_control_service.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  final book = Book(
    id: 'book-1',
    title: 'Test Book',
    filePath: '/books/test.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2024, 1, 1),
  );

  testWidgets('keeps screen awake while content-only mode is active', (
    tester,
  ) async {
    final service = _FakeScreenControlService();

    await tester.pumpWidget(
      ReaderKeepAwakeScope(
        active: true,
        screenControlService: service,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    expect(service.calls, const ['keepAwake']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(service.calls, const ['keepAwake', 'allowSleep']);
  });

  testWidgets('releases screen awake when content-only mode ends', (
    tester,
  ) async {
    final service = _FakeScreenControlService();

    await tester.pumpWidget(
      ReaderKeepAwakeScope(
        active: true,
        screenControlService: service,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      ReaderKeepAwakeScope(
        active: false,
        screenControlService: service,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    expect(service.calls, const ['keepAwake', 'allowSleep']);
  });

  testWidgets('does not keep screen awake while controls are visible', (
    tester,
  ) async {
    final service = _FakeScreenControlService();
    final uiCubit = ReaderUiCubit();
    final readerBloc = ReaderBloc(
      bookRepository: FakeBookRepository(),
      highlightRepository: FakeHighlightRepository(),
      initialSource: book,
    );
    addTearDown(uiCubit.close);
    addTearDown(readerBloc.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: readerBloc),
          BlocProvider.value(value: uiCubit),
        ],
        child: ReaderKeepAwakeDriver(
          screenControlService: service,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    uiCubit.showChrome();
    await tester.pumpAndSettle();

    uiCubit.hideChrome();
    await tester.pumpAndSettle();

    uiCubit.openSearchDrawer();
    await tester.pumpAndSettle();

    expect(
      service.calls,
      const ['keepAwake', 'allowSleep', 'keepAwake', 'allowSleep'],
    );
  });

  testWidgets('waits for reader ready state before keeping screen awake', (
    tester,
  ) async {
    final service = _FakeScreenControlService();
    final uiCubit = ReaderUiCubit();
    final bookRepository = FakeBookRepository()..seedBook(book);
    final readerBloc = ReaderBloc(
      bookRepository: bookRepository,
      highlightRepository: FakeHighlightRepository(),
    );
    addTearDown(uiCubit.close);
    addTearDown(readerBloc.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: readerBloc),
          BlocProvider.value(value: uiCubit),
        ],
        child: ReaderKeepAwakeDriver(
          screenControlService: service,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.calls, isEmpty);

    readerBloc.add(const ReaderSourceLoadRequested(sourceId: 'book-1'));
    await tester.pumpAndSettle();

    expect(service.calls, const ['keepAwake']);
  });

  testWidgets('releases in background and re-enables on resume', (
    tester,
  ) async {
    final service = _FakeScreenControlService();

    await tester.pumpWidget(
      ReaderKeepAwakeScope(
        active: true,
        screenControlService: service,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(service.calls, const ['keepAwake', 'allowSleep', 'keepAwake']);
  });
}

class _FakeScreenControlService implements ScreenControlService {
  final List<String> calls = [];

  @override
  Future<void> keepAwake() async {
    calls.add('keepAwake');
  }

  @override
  Future<void> allowSleep() async {
    calls.add('allowSleep');
  }

  @override
  Future<void> setApplicationBrightness(double brightness) async {
    calls.add('setBrightness');
  }

  @override
  Future<void> resetApplicationBrightness() async {
    calls.add('resetBrightness');
  }
}
