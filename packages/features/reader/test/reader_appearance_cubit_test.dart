import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _supportedCodes = ['en'];
const _sourceId = 'source-1';

void main() {
  late PreferencesService preferencesService;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: _supportedCodes,
    );
  });

  group('ReaderAppearanceCubit', () {
    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'initial state inherits global reader appearance',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      verify: (cubit) {
        expect(cubit.state.hasOverride, isFalse);
        expect(cubit.state.effectiveAppearance.fontId, 'serif');
        expect(cubit.state.effectiveAppearance.themeId, 'paper');
        expect(cubit.state.effectiveAppearance.sideMargin, 8);
        expect(
          cubit.state.effectiveAppearance.pageTurnStyle,
          ReaderPageTurnStyle.horizontal,
        );
        expect(
          cubit.state.effectiveAppearance.textAlignment,
          ReaderTextAlignment.start,
        );
      },
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'setFont persists a source-specific override',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) => cubit.setFont('sans'),
      expect: () => [
        isA<ReaderAppearanceState>()
            .having((s) => s.hasOverride, 'hasOverride', isTrue)
            .having((s) => s.effectiveAppearance.fontId, 'fontId', 'sans'),
      ],
      verify: (_) {
        expect(preferencesService.current.readerFontId, 'serif');
        expect(
          preferencesService.readerAppearanceOverrideFor(_sourceId)?.fontId,
          'sans',
        );
      },
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'global changes still flow through non-overridden traits',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) async {
        await cubit.setFont('sans');
        await preferencesService.update(
          (prefs) => prefs.copyWith(readerThemeId: 'night'),
        );
      },
      skip: 1,
      expect: () => [
        isA<ReaderAppearanceState>()
            .having((s) => s.effectiveAppearance.fontId, 'fontId', 'sans')
            .having((s) => s.effectiveAppearance.themeId, 'themeId', 'night'),
      ],
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'setTextAlignment persists a source-specific override',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) => cubit.setTextAlignment(ReaderTextAlignment.justify),
      expect: () => [
        isA<ReaderAppearanceState>().having(
          (s) => s.effectiveAppearance.textAlignment,
          'textAlignment',
          ReaderTextAlignment.justify,
        ),
      ],
      verify: (_) {
        expect(
          preferencesService
              .readerAppearanceOverrideFor(_sourceId)
              ?.textAlignment,
          ReaderTextAlignment.justify,
        );
      },
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'setTextAlignment supports logical end alignment',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) => cubit.setTextAlignment(ReaderTextAlignment.end),
      expect: () => [
        isA<ReaderAppearanceState>().having(
          (s) => s.effectiveAppearance.textAlignment,
          'textAlignment',
          ReaderTextAlignment.end,
        ),
      ],
      verify: (_) {
        expect(
          preferencesService
              .readerAppearanceOverrideFor(_sourceId)
              ?.textAlignment,
          ReaderTextAlignment.end,
        );
      },
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'setPageTurnStyle persists a source-specific override',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) => cubit.setPageTurnStyle(ReaderPageTurnStyle.vertical),
      expect: () => [
        isA<ReaderAppearanceState>().having(
          (s) => s.effectiveAppearance.pageTurnStyle,
          'pageTurnStyle',
          ReaderPageTurnStyle.vertical,
        ),
      ],
      verify: (_) {
        expect(
          preferencesService
              .readerAppearanceOverrideFor(_sourceId)
              ?.pageTurnStyle,
          ReaderPageTurnStyle.vertical,
        );
      },
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'previewTextScale emits immediately without persisting',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) => cubit.previewTextScale(1.25),
      expect: () => [
        isA<ReaderAppearanceState>().having(
          (s) => s.effectiveAppearance.textScale,
          'textScale',
          1.25,
        ),
      ],
      verify: (_) {
        expect(
          preferencesService.readerAppearanceOverrideFor(_sourceId),
          isNull,
        );
      },
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'commitTextScale persists the source override',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) => cubit.commitTextScale(1.2),
      wait: const Duration(milliseconds: 300),
      expect: () => [
        isA<ReaderAppearanceState>().having(
          (s) => s.effectiveAppearance.textScale,
          'textScale',
          1.2,
        ),
      ],
      verify: (_) {
        expect(
          preferencesService.readerAppearanceOverrideFor(_sourceId)?.textScale,
          1.2,
        );
      },
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'resetTextScale clears only the text scale override',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) async {
        await cubit.setFont('sans');
        cubit.previewTextScale(1.2);
        await cubit.resetTextScale();
      },
      expect: () => [
        isA<ReaderAppearanceState>()
            .having((s) => s.effectiveAppearance.fontId, 'fontId', 'sans')
            .having((s) => s.effectiveAppearance.textScale, 'textScale', 1.0),
        isA<ReaderAppearanceState>()
            .having((s) => s.effectiveAppearance.fontId, 'fontId', 'sans')
            .having((s) => s.effectiveAppearance.textScale, 'textScale', 1.2),
        isA<ReaderAppearanceState>()
            .having((s) => s.effectiveAppearance.fontId, 'fontId', 'sans')
            .having((s) => s.effectiveAppearance.textScale, 'textScale', 1.0),
      ],
      verify: (_) {
        final override = preferencesService.readerAppearanceOverrideFor(
          _sourceId,
        );
        expect(override?.fontId, 'sans');
        expect(override?.textScale, isNull);
      },
    );

    test(
      'resetTextScale clears local override and inherits global scale',
      () async {
        await preferencesService.update(
          (prefs) => prefs.copyWith(readerTextScale: 1.15),
        );
        final cubit = ReaderAppearanceCubit(
          preferencesService: preferencesService,
          sourceId: _sourceId,
        );
        addTearDown(cubit.close);

        cubit.previewTextScale(1.0);
        await cubit.resetTextScale();

        expect(cubit.state.hasOverride, isFalse);
        expect(cubit.state.effectiveAppearance.textScale, 1.15);
        expect(
          preferencesService.readerAppearanceOverrideFor(_sourceId),
          isNull,
        );
      },
    );

    test(
      'resetLineHeight clears local override and inherits global spacing',
      () async {
        await preferencesService.update(
          (prefs) => prefs.copyWith(readerLineHeight: 1.8),
        );
        final cubit = ReaderAppearanceCubit(
          preferencesService: preferencesService,
          sourceId: _sourceId,
        );
        addTearDown(cubit.close);

        cubit.previewLineHeight(1.6);
        await cubit.resetLineHeight();

        expect(cubit.state.hasOverride, isFalse);
        expect(cubit.state.effectiveAppearance.lineHeight, 1.8);
        expect(
          preferencesService.readerAppearanceOverrideFor(_sourceId),
          isNull,
        );
      },
    );

    test(
      'resetSideMargin clears local override and inherits global margin',
      () async {
        await preferencesService.update(
          (prefs) => prefs.copyWith(readerSideMargin: 10),
        );
        final cubit = ReaderAppearanceCubit(
          preferencesService: preferencesService,
          sourceId: _sourceId,
        );
        addTearDown(cubit.close);

        cubit.previewSideMargin(8);
        await cubit.resetSideMargin();

        expect(cubit.state.hasOverride, isFalse);
        expect(cubit.state.effectiveAppearance.sideMargin, 10);
        expect(
          preferencesService.readerAppearanceOverrideFor(_sourceId),
          isNull,
        );
      },
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'commitSideMargin persists the source override',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) => cubit.commitSideMargin(10),
      wait: const Duration(milliseconds: 300),
      expect: () => [
        isA<ReaderAppearanceState>().having(
          (s) => s.effectiveAppearance.sideMargin,
          'sideMargin',
          10,
        ),
      ],
      verify: (_) {
        expect(
          preferencesService.readerAppearanceOverrideFor(_sourceId)?.sideMargin,
          10,
        );
      },
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'resetSideMargin clears only the side margin override',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) async {
        await cubit.setFont('sans');
        cubit.previewSideMargin(10);
        await cubit.resetSideMargin();
      },
      expect: () => [
        isA<ReaderAppearanceState>()
            .having((s) => s.effectiveAppearance.fontId, 'fontId', 'sans')
            .having((s) => s.effectiveAppearance.sideMargin, 'sideMargin', 8),
        isA<ReaderAppearanceState>()
            .having((s) => s.effectiveAppearance.fontId, 'fontId', 'sans')
            .having((s) => s.effectiveAppearance.sideMargin, 'sideMargin', 10),
        isA<ReaderAppearanceState>()
            .having((s) => s.effectiveAppearance.fontId, 'fontId', 'sans')
            .having((s) => s.effectiveAppearance.sideMargin, 'sideMargin', 8),
      ],
      verify: (_) {
        final override = preferencesService.readerAppearanceOverrideFor(
          _sourceId,
        );
        expect(override?.fontId, 'sans');
        expect(override?.sideMargin, isNull);
      },
    );

    blocTest<ReaderAppearanceCubit, ReaderAppearanceState>(
      'reset clears the source override',
      build: () => ReaderAppearanceCubit(
        preferencesService: preferencesService,
        sourceId: _sourceId,
      ),
      act: (cubit) async {
        await cubit.setFont('sans');
        await cubit.reset();
      },
      verify: (cubit) {
        expect(cubit.state.hasOverride, isFalse);
        expect(cubit.state.effectiveAppearance.fontId, 'serif');
        expect(
          preferencesService.readerAppearanceOverrideFor(_sourceId),
          isNull,
        );
      },
    );

    test(
      'reset clears local overrides and inherits global appearance',
      () async {
        await preferencesService.update(
          (prefs) => prefs.copyWith(
            readerThemeId: 'night',
            readerTextScale: 1.15,
          ),
        );
        final cubit = ReaderAppearanceCubit(
          preferencesService: preferencesService,
          sourceId: _sourceId,
        );
        addTearDown(cubit.close);

        await cubit.setFont('sans');
        await cubit.reset();

        expect(cubit.state.hasOverride, isFalse);
        expect(cubit.state.effectiveAppearance.themeId, 'night');
        expect(cubit.state.effectiveAppearance.textScale, 1.15);
        expect(
          preferencesService.readerAppearanceOverrideFor(_sourceId),
          isNull,
        );
      },
    );
  });
}
