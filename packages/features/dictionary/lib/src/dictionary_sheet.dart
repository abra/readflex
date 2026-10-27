import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:dictionary_service/dictionary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';
import 'package:shared/shared.dart';

import 'dictionary_cubit.dart';
import 'word_save_status.dart';

Future<void> showDictionarySheet(
  BuildContext context, {
  required TextSelectionContext selection,
  required DictionaryLookupService dictionaryService,
  DictionaryRepository? dictionaryRepository,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => DictionarySheet(
      selection: selection,
      dictionaryService: dictionaryService,
      dictionaryRepository: dictionaryRepository,
    ),
  );
}

class DictionarySheet extends StatelessWidget {
  const DictionarySheet({
    required this.selection,
    required this.dictionaryService,
    this.dictionaryRepository,
    super.key,
  });

  final TextSelectionContext selection;
  final DictionaryLookupService dictionaryService;

  /// Where Save keeps the word; without it the sheet offers no Save.
  final DictionaryRepository? dictionaryRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DictionaryCubit(
        dictionaryService: dictionaryService,
        dictionaryRepository: dictionaryRepository,
      )..lookup(selection),
      child: _DictionarySheetView(
        selection: selection,
        canSave: dictionaryRepository != null,
        onCopy: (text) => Clipboard.setData(ClipboardData(text: text)),
      ),
    );
  }
}

class _DictionarySheetView extends StatelessWidget {
  const _DictionarySheetView({
    required this.selection,
    required this.canSave,
    required this.onCopy,
  });

  final TextSelectionContext selection;
  final bool canSave;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout.scrollable(
      title: context.l10n.dictionaryTitle,
      closeLabel: context.l10n.commonClose,
      onClose: () => Navigator.of(context).pop(),
      bodyPadding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: BlocConsumer<DictionaryCubit, DictionarySheetState>(
        // Only a tap that saved: the lookup of an earlier save is silent.
        listenWhen: (previous, current) =>
            previous.saveStatus == WordSaveStatus.saving &&
            current.saveStatus == WordSaveStatus.saved,
        listener: (context, _) => showToast(
          context,
          type: NotificationType.success,
          message: context.l10n.wordSaved,
        ),
        builder: (context, state) {
          final body = _DictionaryBody(
            selection: selection,
            state: state,
            canSave: canSave,
            onCopy: onCopy,
          );
          if (state.status == DictionarySheetStatus.success) return body;
          final phrase = selection.effectiveSelectedText;
          final direction = _contentDirection(phrase);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSourceQuote(
                  key: const ValueKey('dictionary-source-quote'),
                  textDirection: direction,
                  child: Text(
                    phrase,
                    key: const ValueKey('dictionary-source-phrase'),
                    textDirection: direction,
                    style: context.text.bodyMedium.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                body,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DictionaryBody extends StatelessWidget {
  const _DictionaryBody({
    required this.selection,
    required this.state,
    required this.canSave,
    required this.onCopy,
  });

  final TextSelectionContext selection;
  final DictionarySheetState state;
  final bool canSave;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DictionaryCubit>();
    return switch (state.status) {
      DictionarySheetStatus.initial ||
      DictionarySheetStatus.loading => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: CenteredCircularProgressIndicator(),
      ),
      DictionarySheetStatus.success => _DictionaryResultView(
        result: state.result!,
        selectedText: selection.effectiveSelectedText,
        saveStatus: state.saveStatus,
        onToggleSaved: canSave ? () => cubit.toggleSaved(selection) : null,
        onCopy: onCopy,
      ),
      DictionarySheetStatus.notFound => AppStatusMessage(
        title: context.l10n.dictionaryNotFoundTitle,
        body: context.l10n.dictionaryNotFoundBody,
      ),
      DictionarySheetStatus.unsupportedLanguage => AppStatusMessage(
        title: context.l10n.dictionaryUnsupportedLanguageTitle,
        body: context.l10n.dictionaryUnsupportedLanguageBody,
      ),
      DictionarySheetStatus.failure => AppStatusMessage(
        title: context.l10n.dictionaryFailureTitle,
        body: context.l10n.dictionaryFailureBody,
        actionLabel: context.l10n.commonRetry,
        onAction: () => cubit.lookup(selection),
      ),
    };
  }
}

/// The selected word's entry with its contextual expression first.
///
/// The headword and its metadata lead, outside the sections. The expression
/// the word forms in its sentence follows in an outlined **In this context**
/// section, then the word's own definitions under **Word meaning**, the same
/// order as Translation. Further entries follow as their own sections.
class _DictionaryResultView extends StatelessWidget {
  const _DictionaryResultView({
    required this.result,
    required this.selectedText,
    required this.saveStatus,
    required this.onToggleSaved,
    required this.onCopy,
  });

  final DictionaryLookupResult result;
  final String selectedText;
  final WordSaveStatus saveStatus;

  /// Saves the word to Vocabulary; `null` when the sheet cannot save.
  final VoidCallback? onToggleSaved;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final entries = result.entries;
    final word = entries.first;
    final inContext = entries.length > 1 ? entries[1] : null;
    // Regular weight: the section titles are the bold lines.
    final subentryStyle = context.text.titleMedium.copyWith(
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DictionaryEntryHeader(
          entry: word,
          selectedText: selectedText,
          style: context.text.headlineSmall,
          onCopy: onCopy,
          saveStatus: saveStatus,
          onToggleSaved: onToggleSaved,
        ),
        const SizedBox(height: AppSpacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: [
            if (inContext != null)
              _EntrySection(
                entry: inContext,
                title: context.l10n.dictionaryInContext,
                style: subentryStyle,
                onCopy: onCopy,
              ),
            if (word.definitions.isNotEmpty)
              AppSheetSection(
                title: inContext == null
                    ? null
                    : context.l10n.dictionaryWordMeaning,
                child: _DictionaryDefinitions(entry: word),
              ),
            for (final entry in entries.skip(2))
              _EntrySection(entry: entry, style: subentryStyle, onCopy: onCopy),
          ],
        ),
      ],
    );
  }
}

/// An entry in its own outlined section: its lemma row, with the section's
/// [title] as the row's lead, then its definitions.
class _EntrySection extends StatelessWidget {
  const _EntrySection({
    required this.entry,
    required this.style,
    required this.onCopy,
    this.title,
  });

  final DictionaryLexicalEntry entry;
  final TextStyle style;
  final Future<void> Function(String) onCopy;
  final String? title;

  @override
  Widget build(BuildContext context) {
    // The lemma row keeps the room above and below itself; definitions after
    // it need the room below.
    return AppSheetSection(
      padding: entry.definitions.isEmpty
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DictionaryEntryHeader(
            entry: entry,
            title: title,
            style: style,
            onCopy: onCopy,
          ),
          _DictionaryDefinitions(entry: entry),
        ],
      ),
    );
  }
}

/// An entry's lemma in [style] with its metadata right below it, Copy (and
/// Save for the headword) on the lemma's line and an optional section
/// [title] above. The row keeps 12dp of room above and below its text at any
/// text size.
class _DictionaryEntryHeader extends StatelessWidget {
  const _DictionaryEntryHeader({
    required this.entry,
    required this.style,
    required this.onCopy,
    this.selectedText,
    this.title,
    this.saveStatus = WordSaveStatus.notSaved,
    this.onToggleSaved,
  });

  final DictionaryLexicalEntry entry;
  final TextStyle style;
  final Future<void> Function(String) onCopy;
  final WordSaveStatus saveStatus;
  final VoidCallback? onToggleSaved;

  /// The selected form, shown before the lemma when it differs.
  final String? selectedText;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final direction = _contentDirection(entry.lemma);
    final title = this.title;
    // The backend returns the part of speech in the term's own language; the
    // sheet has no localization map for it, so the raw label is shown.
    final metadata = AppLexicalMetadataRow(
      reading: entry.reading,
      pronunciation: entry.pronunciation,
      partOfSpeech: entry.partOfSpeech,
      textDirection: direction,
    );
    final onToggleSaved = this.onToggleSaved;
    final l10n = context.l10n;
    final copy = AppCopyButton(
      key: ValueKey(entry),
      onCopy: () => onCopy(
        [
          entry.lemma,
          for (var i = 0; i < entry.definitions.length; i++)
            '${i + 1}. ${entry.definitions[i].text}',
        ].join('\n'),
      ),
      copyLabel: l10n.commonCopy,
      copiedLabel: l10n.commonCopied,
      failureLabel: l10n.commonCopyFailed,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionCount = onToggleSaved == null ? 1 : 2;
        final lemmaStyle = appFitSelectableText(
          context,
          style,
          text: entry.lemma,
          boxWidth: AppSheetActionRow.childWidthFor(
            constraints.maxWidth,
            actionCount: actionCount,
          ),
          textDirection: direction,
        );
        return AppSheetActionRow(
          // Copy trails the lemma, also in an interface of the other
          // direction.
          textDirection: direction,
          firstLineStyle: lemmaStyle,
          lead: title == null ? null : AppSheetSectionTitle(title),
          leadSpacing: AppSpacing.sm,
          minTextRoom: AppSpacing.md,
          action: onToggleSaved == null
              ? copy
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSaveToggleButton(
                      key: const ValueKey('dictionary-save-word'),
                      saved: saveStatus == WordSaveStatus.saved,
                      busy: saveStatus == WordSaveStatus.saving,
                      failed: saveStatus == WordSaveStatus.failure,
                      onPressed: onToggleSaved,
                      saveLabel: l10n.wordSave,
                      savedLabel: l10n.wordSaved,
                      unsaveLabel: l10n.wordUnsave,
                      failureLabel: l10n.wordSaveFailed,
                    ),
                    copy,
                  ],
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DictionaryLemma(
                lemma: entry.lemma,
                selectedText: selectedText,
                style: lemmaStyle,
              ),
              if (!metadata.isEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                metadata,
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Numbered definitions of [entry], 12dp apart, ending at the last one.
class _DictionaryDefinitions extends StatelessWidget {
  const _DictionaryDefinitions({required this.entry});

  final DictionaryLexicalEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          for (var index = 0; index < entry.definitions.length; index++)
            _DefinitionView(
              number: index + 1,
              definition: entry.definitions[index],
            ),
        ],
      ),
    );
  }
}

class _DictionaryLemma extends StatelessWidget {
  const _DictionaryLemma({
    required this.lemma,
    required this.selectedText,
    required this.style,
  });

  final String lemma;
  final String? selectedText;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final selected = selectedText?.trim();
    final hasDifferentForm =
        selected != null &&
        selected.isNotEmpty &&
        selected.toLowerCase() != lemma.trim().toLowerCase();
    final direction = _contentDirection(lemma);
    return Directionality(
      textDirection: direction,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasDifferentForm) ...[
            Text(
              selected,
              style: context.text.bodyMedium.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            ExcludeSemantics(
              child: Transform.flip(
                flipX: direction == TextDirection.rtl,
                child: Icon(
                  AppIcons.arrowRight,
                  size: AppIconSize.xs,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
          Semantics(header: true, child: SelectableText(lemma, style: style)),
        ],
      ),
    );
  }
}

class _DefinitionView extends StatelessWidget {
  const _DefinitionView({required this.number, required this.definition});

  final int number;
  final DictionaryDefinition definition;

  /// Number column: two digits and a period at the base text size.
  static const numberColumnWidth = AppSpacing.xl + AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _contentDirection(definition.text),
      child: Row(
        // The number sits on the definition's first line.
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            // Scale with the user's text size so "10." never wraps.
            width: MediaQuery.textScalerOf(context).scale(numberColumnWidth),
            child: Text(
              context.l10n.dictionaryDefinitionNumber(number),
              style: context.text.bodyMedium.copyWith(
                color: context.colors.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(definition.text, style: context.text.bodyLarge),
                for (final example in definition.examples) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    example,
                    textDirection: _contentDirection(example),
                    style: context.text.bodyMedium.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextDirection _contentDirection(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;
