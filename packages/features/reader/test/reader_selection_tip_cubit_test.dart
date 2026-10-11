import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_selection_tip_cubit.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late PreferencesService preferences;

  Future<PreferencesService> createPreferences() =>
      PreferencesService.create(supportedCodes: const ['en']);

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await createPreferences();
  });
  tearDown(() => preferences.dispose());

  ReaderSelectionTipCubit createCubit() {
    final cubit = ReaderSelectionTipCubit(preferencesService: preferences);
    addTearDown(cubit.close);
    return cubit;
  }

  /// Runs one reader session in which the tip appears and is then hidden by
  /// a page turn.
  Future<void> sessionHiddenByPageTurn() async {
    final cubit = createCubit()
      ..showIfDue()
      ..hideForSession();
    expect(cubit.state, ReaderSelectionTipPhase.done);
    await pumpEventQueue();
  }

  group('initial phase', () {
    test('a fresh install waits to show the tip', () {
      expect(createCubit().state, ReaderSelectionTipPhase.waiting);
    });

    test('a dismissed tip is done', () async {
      await preferences.update(
        (p) => p.copyWith(readerSelectionTipDismissed: true),
      );
      expect(createCubit().state, ReaderSelectionTipPhase.done);
    });

    test('the tip is done after its last allowed session', () async {
      await preferences.update(
        (p) => p.copyWith(
          readerSelectionTipShowCount: ReaderSelectionTipCubit.maxShows - 1,
        ),
      );
      expect(createCubit().state, ReaderSelectionTipPhase.waiting);

      await preferences.update(
        (p) => p.copyWith(
          readerSelectionTipShowCount: ReaderSelectionTipCubit.maxShows,
        ),
      );
      expect(createCubit().state, ReaderSelectionTipPhase.done);
    });
  });

  group('showIfDue', () {
    test('shows once per session and counts that session', () async {
      final cubit = createCubit();
      final phases = <ReaderSelectionTipPhase>[];
      final subscription = cubit.stream.listen(phases.add);
      addTearDown(subscription.cancel);

      cubit
        ..showIfDue()
        ..showIfDue();
      await pumpEventQueue();

      expect(phases, [ReaderSelectionTipPhase.visible]);
      expect(preferences.current.readerSelectionTipShowCount, 1);
    });

    test('never shows again in a session after it was hidden', () async {
      final cubit = createCubit()
        ..showIfDue()
        ..hideForSession()
        ..showIfDue();
      await pumpEventQueue();

      expect(cubit.state, ReaderSelectionTipPhase.done);
      expect(preferences.current.readerSelectionTipShowCount, 1);
    });

    test('counts persist for the next app launch', () async {
      createCubit().showIfDue();
      await pumpEventQueue();

      final relaunched = await createPreferences();
      addTearDown(relaunched.dispose);
      expect(relaunched.current.readerSelectionTipShowCount, 1);
    });
  });

  group('hideForSession', () {
    test('does nothing before the tip appears', () {
      final cubit = createCubit()..hideForSession();
      expect(cubit.state, ReaderSelectionTipPhase.waiting);

      cubit.showIfDue();
      expect(cubit.state, ReaderSelectionTipPhase.visible);
    });

    test('hides a visible tip only until the next session', () async {
      await sessionHiddenByPageTurn();

      expect(preferences.current.readerSelectionTipDismissed, isFalse);
      expect(createCubit().state, ReaderSelectionTipPhase.waiting);
    });

    test('the tip retires after the allowed number of sessions', () async {
      for (var i = 0; i < ReaderSelectionTipCubit.maxShows; i++) {
        await sessionHiddenByPageTurn();
      }

      expect(
        preferences.current.readerSelectionTipShowCount,
        ReaderSelectionTipCubit.maxShows,
      );
      expect(createCubit().state, ReaderSelectionTipPhase.done);
    });
  });

  group('dismissForever', () {
    test('Got it on a visible tip ends it for good', () async {
      final cubit = createCubit()
        ..showIfDue()
        ..dismissForever();
      await pumpEventQueue();

      expect(cubit.state, ReaderSelectionTipPhase.done);
      expect(preferences.current.readerSelectionTipDismissed, isTrue);
      expect(createCubit().state, ReaderSelectionTipPhase.done);
    });

    test('a selection before the tip appears ends it for good', () async {
      final cubit = createCubit()..dismissForever();
      await pumpEventQueue();

      expect(cubit.state, ReaderSelectionTipPhase.done);
      expect(preferences.current.readerSelectionTipShowCount, 0);
      expect(preferences.current.readerSelectionTipDismissed, isTrue);
    });

    test('a selection after a page turn hid the tip still counts', () async {
      final cubit = createCubit()
        ..showIfDue()
        ..hideForSession()
        ..dismissForever();
      await pumpEventQueue();

      expect(cubit.state, ReaderSelectionTipPhase.done);
      expect(preferences.current.readerSelectionTipDismissed, isTrue);
    });

    test('does not write an existing dismissal again', () async {
      await preferences.update(
        (p) => p.copyWith(readerSelectionTipDismissed: true),
      );
      await pumpEventQueue();
      final writes = <Preferences>[];
      final subscription = preferences.stream.listen(writes.add);
      addTearDown(subscription.cancel);

      createCubit()
        ..dismissForever()
        ..dismissForever();
      await pumpEventQueue();

      expect(writes, isEmpty);
    });
  });

  test(
    'a write after the service is disposed is reported, not thrown',
    () async {
      final observer = _ErrorObserver();
      final previous = Bloc.observer;
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = previous);

      final cubit = createCubit();
      await preferences.dispose();
      cubit.showIfDue();
      await pumpEventQueue();

      expect(cubit.state, ReaderSelectionTipPhase.visible);
      expect(observer.errors.single, isA<StateError>());
    },
  );

  group('readerSupportsSelectionTip', () {
    bool supports(
      BookFormat? format, {
      SourceType sourceType = SourceType.book,
      bool? hasSearchableText,
    }) => readerSupportsSelectionTip(
      sourceType: sourceType,
      format: format,
      hasSearchableText: hasSearchableText,
    );

    test('articles and reflowable books can select text', () {
      expect(supports(null, sourceType: SourceType.article), isTrue);
      for (final format in [
        BookFormat.epub,
        BookFormat.fb2,
        BookFormat.mobi,
        BookFormat.azw3,
        null,
      ]) {
        expect(supports(format), isTrue, reason: '$format');
      }
    });

    test('comics cannot, whatever their features say', () {
      expect(supports(BookFormat.cbz), isFalse);
      expect(supports(BookFormat.cbz, hasSearchableText: true), isFalse);
    });

    test('a PDF can only with a known text layer', () {
      expect(supports(BookFormat.pdf, hasSearchableText: true), isTrue);
      expect(supports(BookFormat.pdf, hasSearchableText: false), isFalse);
      expect(supports(BookFormat.pdf), isFalse, reason: 'not known yet');
    });
  });

  group('isReaderPageTurn', () {
    test('book page turns and swipe snaps count', () {
      for (final reason in ['page', 'snap']) {
        expect(
          isReaderPageTurn(
            sourceType: SourceType.book,
            relocationReason: reason,
          ),
          isTrue,
          reason: reason,
        );
      }
    });

    test('restores, anchors, layout and unknown reasons do not', () {
      for (final reason in [
        'scroll',
        'anchor',
        'load',
        'style',
        'resize',
        null,
      ]) {
        expect(
          isReaderPageTurn(
            sourceType: SourceType.book,
            relocationReason: reason,
          ),
          isFalse,
          reason: '$reason',
        );
      }
    });

    test('articles never count: their scroll reason is not a reader', () {
      for (final reason in ['page', 'snap', 'scroll']) {
        expect(
          isReaderPageTurn(
            sourceType: SourceType.article,
            relocationReason: reason,
          ),
          isFalse,
          reason: reason,
        );
      }
    });
  });
}

class _ErrorObserver extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}
