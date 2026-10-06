import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_language_sheet.dart';
import 'library_layout_cubit.dart';
import 'library_locale_cubit.dart';
import 'library_theme_cubit.dart';

Future<void> showLibraryDisplaySheet({
  required BuildContext context,
  required LibraryLayoutCubit layoutCubit,
  required LibraryLocaleCubit localeCubit,
  required LibraryThemeCubit themeCubit,
}) => showAppBottomSheet<void>(
  context,
  scrimClosesFlow: true,
  builder: (_) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: layoutCubit),
      BlocProvider.value(value: localeCubit),
      BlocProvider.value(value: themeCubit),
    ],
    child: const _LibraryDisplaySheet(),
  ),
);

class _LibraryDisplaySheet extends StatefulWidget {
  const _LibraryDisplaySheet();

  @override
  State<_LibraryDisplaySheet> createState() => _LibraryDisplaySheetState();
}

class _LibraryDisplaySheetState extends State<_LibraryDisplaySheet>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  )..addStatusListener(_onTransitionStatus);
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  late final _displayOffset = Tween(
    begin: Offset.zero,
    end: const Offset(-1, 0),
  ).animate(_curve);
  late final _languageOffset = Tween(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(_curve);
  var _languageVisible = false;
  var _transitionDirection = TextDirection.ltr;

  void _onTransitionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      setState(() {});
    }
  }

  void _showLanguage(bool visible) {
    if (_languageVisible == visible) return;
    setState(() {
      _languageVisible = visible;
      // A locale change must not flip the in-flight return animation.
      _transitionDirection = Directionality.of(context);
    });
    final target = visible ? 1.0 : 0.0;
    if (context.reduceMotion) {
      _controller.value = target;
    } else {
      _controller.animateTo(target);
    }
  }

  void _selectLanguage(Locale locale) {
    unawaited(context.read<LibraryLocaleCubit>().setLocale(locale));
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _step({
    required bool active,
    required Animation<Offset> position,
    required Widget child,
    bool maintainSize = false,
  }) {
    final content = TickerMode(
      enabled: active,
      child: ExcludeSemantics(
        excluding: !active,
        child: ExcludeFocus(
          excluding: !active,
          child: IgnorePointer(
            ignoring: !active,
            child: SlideTransition(
              position: position,
              textDirection: _transitionDirection,
              child: child,
            ),
          ),
        ),
      ),
    );
    final visible = active || _controller.isAnimating;
    return maintainSize
        ? Visibility(
            visible: visible,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: content,
          )
        : Offstage(offstage: !visible, child: content);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_languageVisible,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _showLanguage(false);
    },
    child: ClipRect(
      child: Stack(
        children: [
          // Only Display determines the height, even while hidden. Language
          // fills that space and scrolls without enlarging the parent sheet.
          _step(
            active: !_languageVisible,
            position: _displayOffset,
            maintainSize: true,
            child: _DisplaySettings(
              onLanguage: () => _showLanguage(true),
            ),
          ),
          Positioned.fill(
            child: _step(
              active: _languageVisible,
              position: _languageOffset,
              child: BlocBuilder<LibraryLocaleCubit, Locale>(
                builder: (context, locale) => LibraryLanguageSheet(
                  selectedLocale: locale,
                  onSelected: _selectLanguage,
                  onBack: () => _showLanguage(false),
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DisplaySettings extends StatelessWidget {
  const _DisplaySettings({required this.onLanguage});

  final VoidCallback onLanguage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ActionBottomSheetLayout.scrollable(
      title: l10n.libraryDisplayTitle,
      onClose: () => Navigator.of(context).pop(),
      closeLabel: l10n.commonClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSettingsSection(
            title: l10n.libraryDisplayView,
            child: BlocBuilder<LibraryLayoutCubit, LibraryLayoutMode>(
              builder: (context, mode) => AppChoiceControl(
                selected: mode,
                onChanged: context.read<LibraryLayoutCubit>().setLayoutMode,
                options: [
                  AppChoiceOption(
                    value: LibraryLayoutMode.list,
                    label: l10n.libraryDisplayList,
                    icon: AppIcons.viewList,
                  ),
                  AppChoiceOption(
                    value: LibraryLayoutMode.grid,
                    label: l10n.libraryDisplayGrid,
                    icon: AppIcons.viewGrid,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSettingsSection(
            title: l10n.libraryDisplayAppearance,
            child: BlocBuilder<LibraryThemeCubit, ThemeMode>(
              builder: (context, mode) => AppChoiceControl(
                selected: mode,
                onChanged: context.read<LibraryThemeCubit>().setThemeMode,
                options: [
                  AppChoiceOption(
                    value: ThemeMode.system,
                    label: l10n.libraryThemeSystem,
                  ),
                  AppChoiceOption(
                    value: ThemeMode.light,
                    label: l10n.libraryThemeLight,
                  ),
                  AppChoiceOption(
                    value: ThemeMode.dark,
                    label: l10n.libraryThemeDark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _LanguagePickerRow(onPressed: onLanguage),
        ],
      ),
    );
  }
}

class _LanguagePickerRow extends StatelessWidget {
  const _LanguagePickerRow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => BlocBuilder<LibraryLocaleCubit, Locale>(
    builder: (context, locale) {
      final language = ReadflexSupportedLocales.languages.firstWhere(
        (item) => item.code == locale.languageCode,
      );
      return AppDrillInRow(
        key: const ValueKey('libraryLanguagePicker'),
        title: context.l10n.libraryDisplayLanguage,
        value: language.name,
        // Settings rows keep the 56dp list-row height that sizes Display.
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        onTap: onPressed,
      );
    },
  );
}
