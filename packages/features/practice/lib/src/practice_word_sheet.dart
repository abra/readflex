import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';

import 'practice_item.dart';

enum PracticeWordSheetOutcome { open, remove }

/// A saved word as it was saved: pronunciation and part of speech, the
/// meaning in context, the word's own meaning, the sentence and its
/// translation. Open in book and Remove complete with an outcome.
Future<PracticeWordSheetOutcome?> showPracticeWordSheet(
  BuildContext context, {
  required PracticeWordItem word,
  required bool canOpenInSource,
}) => showAppBottomSheet<PracticeWordSheetOutcome>(
  context,
  builder: (sheetContext) => PracticeWordSheet(
    word: word,
    canOpenInSource: canOpenInSource,
    onOpen: () => Navigator.of(sheetContext).pop(PracticeWordSheetOutcome.open),
    onRemove: () =>
        Navigator.of(sheetContext).pop(PracticeWordSheetOutcome.remove),
    onClose: () => Navigator.of(sheetContext).pop(),
  ),
);

class PracticeWordSheet extends StatelessWidget {
  const PracticeWordSheet({
    required this.word,
    required this.canOpenInSource,
    required this.onOpen,
    required this.onRemove,
    required this.onClose,
    super.key,
  });

  final PracticeWordItem word;
  final bool canOpenInSource;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final entry = word.entry;
    final direction = _direction(entry.word);
    final sentence = entry.context?.trim();
    final sentenceTranslation = entry.contextTranslation?.trim();
    final base = entry.baseTranslation?.trim();
    final metadata = AppLexicalMetadataRow(
      pronunciation: entry.pronunciation,
      partOfSpeech: entry.partOfSpeech,
      textDirection: direction,
    );
    return ActionBottomSheetLayout(
      title: entry.word,
      onClose: onClose,
      closeLabel: l10n.commonClose,
      constrainBody: true,
      footer: AppSheetActions(
        primaryLabel: l10n.practiceOpenInBook,
        onPrimary: canOpenInSource ? onOpen : null,
        secondaryLabel: l10n.wordUnsave,
        onSecondary: onRemove,
        destructiveSecondary: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          if (!metadata.isEmpty) metadata,
          AppSheetSection(
            title: l10n.translationInContext,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: SelectableText(
                entry.translation,
                textDirection: _direction(entry.translation),
                style: text.titleMedium.copyWith(letterSpacing: 0),
              ),
            ),
          ),
          if (base != null && base.isNotEmpty)
            AppSheetSection(
              title: l10n.translationWordMeaning,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: SelectableText(
                  base,
                  textDirection: _direction(base),
                  style: text.bodyLarge,
                ),
              ),
            ),
          if (sentence != null && sentence.isNotEmpty)
            AppSheetSection(
              title: l10n.translationSentence,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSourceQuote(
                      textDirection: _direction(sentence),
                      child: Text(
                        sentence,
                        textDirection: _direction(sentence),
                        style: text.bodyMedium.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (sentenceTranslation != null &&
                        sentenceTranslation.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SelectableText(
                        sentenceTranslation,
                        textDirection: _direction(sentenceTranslation),
                        style: text.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (word.sourceTitle case final title?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                title,
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

TextDirection _direction(String value) =>
    Bidi.detectRtlDirectionality(value) ? TextDirection.rtl : TextDirection.ltr;
