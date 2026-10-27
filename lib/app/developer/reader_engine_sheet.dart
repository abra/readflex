import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex/app/native_reader_formats.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// Formats that have a native engine to switch to, in the sheet's order.
const readerEngineFormats = [BookFormat.cbz, BookFormat.pdf];

/// Opens the developer sheet that picks the engine per format: WebView
/// (foliate-js) or native (`vellum`). Each choice applies as it is
/// tapped and is kept in preferences until "Use build settings" drops
/// the override. Development builds only.
Future<void> showReaderEngineSheet(
  BuildContext context, {
  required PreferencesService preferencesService,
  required Set<BookFormat> buildFormats,
}) => showAppBottomSheet<void>(
  context,
  scrimClosesFlow: true,
  builder: (_) => ReaderEngineSheet(
    preferencesService: preferencesService,
    buildFormats: buildFormats,
  ),
);

/// The sheet's content; follows the preferences stream so several
/// taps in a row show the saved state.
@visibleForTesting
class ReaderEngineSheet extends StatelessWidget {
  const ReaderEngineSheet({
    super.key,
    required this.preferencesService,
    required this.buildFormats,
  });

  final PreferencesService preferencesService;
  final Set<BookFormat> buildFormats;

  Set<BookFormat> _effective(Preferences preferences) {
    final override = preferences.nativeReaderFormats;
    if (override == null) return buildFormats;
    return nativeReaderFormatsFromNames(override);
  }

  Future<void> _setNative(
    Preferences preferences,
    BookFormat format,
    bool native,
  ) {
    final formats = {..._effective(preferences)};
    if (native) {
      formats.add(format);
    } else {
      formats.remove(format);
    }
    return preferencesService.setNativeReaderFormats([
      for (final format in readerEngineFormats)
        if (formats.contains(format)) format.name,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ActionBottomSheetLayout.scrollable(
      title: l10n.developerReaderEngineTitle,
      onClose: () => Navigator.of(context).pop(),
      closeLabel: l10n.commonClose,
      child: StreamBuilder<Preferences>(
        stream: preferencesService.stream,
        initialData: preferencesService.current,
        builder: (context, snapshot) {
          final preferences = snapshot.data ?? preferencesService.current;
          final effective = _effective(preferences);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.developerReaderEngineHint,
                key: const ValueKey('readerEngineHint'),
                style: context.text.bodySmall.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              for (final format in readerEngineFormats) ...[
                const SizedBox(height: AppSpacing.lg),
                AppSettingsSection(
                  title: format.name.toUpperCase(),
                  child: AppChoiceControl<bool>(
                    key: ValueKey('readerEngine-${format.name}'),
                    selected: effective.contains(format),
                    onChanged: (native) =>
                        _setNative(preferences, format, native),
                    options: [
                      AppChoiceOption(
                        value: false,
                        label: l10n.developerReaderEngineWebView,
                      ),
                      AppChoiceOption(
                        value: true,
                        label: l10n.developerReaderEngineNative,
                      ),
                    ],
                  ),
                ),
              ],
              if (preferences.nativeReaderFormats != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const ValueKey('readerEngineReset'),
                    onPressed: () =>
                        preferencesService.setNativeReaderFormats(null),
                    child: Text(l10n.developerReaderEngineReset),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
