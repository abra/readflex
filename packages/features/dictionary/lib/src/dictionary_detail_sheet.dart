import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:language_tools/language_tools.dart';

/// Bottom sheet shown when the user taps a row in the dictionary list.
///
/// Faithful to the readwell `EntryDetailSheet` reference:
///   • Large serif word + inline Mastered badge → italic POS · pronunciation,
///     with a round speaker button on the right.
///   • A pull-quote block with a coloured left border for the first usage
///     example, footer-attributed to the source.
///   • An "IN THIS CONTEXT" kicker over the translation.
///   • Sticky action bar at the bottom: Practice (flex) + Delete.
///
/// Mastered toggle is intentionally omitted for now — FSRS doesn't expose a
/// clean "force-mastered" path, and the data model has only a derived
/// `mastered` set on the bloc state.
class DictionaryDetailSheet extends StatelessWidget {
  const DictionaryDetailSheet({
    required this.entry,
    required this.mastered,
    required this.onDelete,
    this.sourceTitle,
    this.onPractice,
    super.key,
  });

  final DictionaryEntry entry;
  final bool mastered;
  final String? sourceTitle;

  /// Wired from the screen — pops sheet then navigates to the Practice
  /// tab. When `null` the action button is hidden so the sheet still
  /// works in standalone (test) contexts without a navigation host.
  final VoidCallback? onPractice;

  /// Pops sheet then dispatches a delete event on the parent bloc.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final sourceQuote = _sourceQuoteForEntry(entry);
    final verbForms = _verbFormsForEntry(entry);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(entry: entry, mastered: mastered),
                        if (verbForms != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _IrregularVerbFormsBlock(forms: verbForms),
                        ],
                        if (sourceQuote != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _SourceQuote(
                            quote: sourceQuote,
                            sourceTitle: sourceTitle,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        _ContextSection(entry: entry, muted: muted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ActionBar(
                  onPractice: onPractice,
                  onDelete: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IrregularVerbForms? _verbFormsForEntry(DictionaryEntry entry) {
  final partOfSpeech = entry.partOfSpeech;
  if (!looksLikeVerbPartOfSpeech(partOfSpeech)) return null;
  return findEnglishIrregularVerbForms(entry.word);
}

class _IrregularVerbFormsBlock extends StatelessWidget {
  const _IrregularVerbFormsBlock({required this.forms});

  final IrregularVerbForms forms;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IRREGULAR VERB',
          style: context.text.kicker.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        _VerbFormsPill(forms: forms),
      ],
    );
  }
}

class _VerbFormsPill extends StatelessWidget {
  const _VerbFormsPill({required this.forms});

  final IrregularVerbForms forms;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          '${forms.base} / ${forms.pastSimpleLabel} / ${forms.pastParticipleLabel}',
          style: context.text.labelSmall.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Top row of the sheet: word + optional badge + meta line | speaker.
class _Header extends StatelessWidget {
  const _Header({required this.entry, required this.mastered});

  final DictionaryEntry entry;
  final bool mastered;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final appColors = context.appColors;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                    entry.word,
                    style: text.headlineSmall.copyWith(
                      fontFamily: AppTypography.fontFamilySerif,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.1,
                    ),
                  ),
                  if (mastered)
                    AppBadge(
                      label: 'Mastered',
                      foreground: appColors.successForeground,
                      background: appColors.success.withValues(alpha: 0.12),
                    ),
                ],
              ),
              if (entry.partOfSpeech != null || entry.pronunciation != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: _MetaLine(entry: entry, muted: muted),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _SpeakerButton(),
      ],
    );
  }
}

/// "italic POS · pronunciation" row beneath the word.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.entry, required this.muted});

  final DictionaryEntry entry;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final dotColor = muted.withValues(alpha: 0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (entry.partOfSpeech != null)
          Text(
            entry.partOfSpeech!,
            style: text.labelSmall.copyWith(
              fontStyle: FontStyle.italic,
              color: muted,
            ),
          ),
        if (entry.partOfSpeech != null && entry.pronunciation != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (entry.pronunciation != null)
          Flexible(
            child: Text(
              entry.pronunciation!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

/// Round 36×36 speaker button. UI-only: TTS isn't wired yet, so tapping
/// is a no-op. Kept in place so the layout matches the reference and the
/// hookup later is one-line.
class _SpeakerButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {},
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            AppIcons.volumeUp,
            size: 16,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

/// Pull-quote with a coloured left border; uses the first usage example
/// as the body and source title as the footer. Mirrors the reference
/// `border-l-2 border-primary/40` style.
class _SourceQuote extends StatelessWidget {
  const _SourceQuote({required this.quote, this.sourceTitle});

  final String quote;
  final String? sourceTitle;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: cs.primary.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkedText(
            text: quote,
            style: text.bodyMedium.copyWith(
              fontFamily: AppTypography.fontFamilySerif,
              fontStyle: FontStyle.italic,
              color: cs.onSurface.withValues(alpha: 0.9),
              height: 1.55,
            ),
            highlightStyle: text.bodyMedium.copyWith(
              fontFamily: AppTypography.fontFamilySerif,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              color: cs.primary,
              height: 1.55,
            ),
          ),
          if (sourceTitle != null && sourceTitle!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            RichText(
              text: TextSpan(
                style: text.labelSmall.copyWith(color: muted),
                children: [
                  const TextSpan(text: 'from '),
                  TextSpan(
                    text: sourceTitle,
                    style: text.labelSmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "IN THIS CONTEXT" kicker label + primary translation (serif xl).
class _ContextSection extends StatelessWidget {
  const _ContextSection({required this.entry, required this.muted});

  final DictionaryEntry entry;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IN THIS CONTEXT',
          style: text.kicker.copyWith(
            color: muted,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          entry.translation,
          style: text.titleLarge.copyWith(
            fontFamily: AppTypography.fontFamilySerif,
            color: cs.onSurface,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

String? _sourceQuoteForEntry(DictionaryEntry entry) {
  if (entry.usageExamples.isNotEmpty) return entry.usageExamples.first;
  final context = entry.context;
  if (context == null || context.isEmpty) return null;
  return _markedContextForEntry(entry);
}

String _markedContextForEntry(DictionaryEntry entry) {
  final context = entry.context ?? '';
  if (context.contains(MarkedText.startMarker) &&
      context.contains(MarkedText.endMarker)) {
    return context;
  }

  final term = entry.word.trim();
  if (term.isEmpty) return context;
  final index = _findContextTermIndex(context, term);
  if (index == null) return context;
  final end = index + term.length;
  return '${context.substring(0, index)}'
      '${MarkedText.startMarker}${context.substring(index, end)}'
      '${MarkedText.endMarker}${context.substring(end)}';
}

int? _findContextTermIndex(String context, String term) {
  final haystack = context.toLowerCase();
  final needle = term.toLowerCase();
  var index = haystack.indexOf(needle);
  while (index >= 0) {
    final end = index + needle.length;
    if (_hasTermBoundaries(context, index, end)) return index;
    index = haystack.indexOf(needle, index + 1);
  }
  return null;
}

bool _hasTermBoundaries(String value, int start, int end) {
  final before = start == 0 ? null : value.codeUnitAt(start - 1);
  final after = end >= value.length ? null : value.codeUnitAt(end);
  return !_isTermChar(before) && !_isTermChar(after);
}

bool _isTermChar(int? codeUnit) {
  if (codeUnit == null) return false;
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x27;
}

/// Sticky bottom action bar: Practice (flex) + Delete (square). Practice
/// is hidden when [onPractice] is null so the bar collapses gracefully
/// in test/standalone contexts.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onDelete, this.onPractice});

  final VoidCallback? onPractice;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Row(
      children: [
        if (onPractice != null) ...[
          Expanded(
            child: SizedBox(
              height: AppSizes.buttonHeight,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onPractice!();
                },
                icon: const Icon(AppIcons.practice, size: 16),
                label: const Text('Practice'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        SizedBox(
          width: AppSizes.buttonHeight,
          height: AppSizes.buttonHeight,
          child: Material(
            color: cs.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Center(
                child: Icon(AppIcons.delete, size: 16, color: cs.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
