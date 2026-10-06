import 'package:flutter/material.dart';

import 'theme/app_typography.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// Muted metadata line under a headword: reading, pronunciation and part of
/// speech, wrapping onto further lines when the width is narrow.
///
/// Every string is already localized or language-specific; the row does not
/// translate grammatical tags. [pronunciation] is IPA and always renders
/// left-to-right in the bundled phonetic font. [reading] follows
/// [textDirection], the headword's own writing direction; part of speech is
/// interface copy and follows the ambient direction. Each piece keeps its own
/// semantics node so assistive technology reads them as separate items.
/// Renders nothing when all three are null or blank.
class AppLexicalMetadataRow extends StatelessWidget {
  const AppLexicalMetadataRow({
    this.pronunciation,
    this.reading,
    this.partOfSpeech,
    this.textDirection,
    super.key,
  });

  final String? pronunciation;
  final String? reading;
  final String? partOfSpeech;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final reading = _nonBlank(this.reading);
    final pronunciation = _nonBlank(this.pronunciation);
    final partOfSpeech = _nonBlank(this.partOfSpeech);
    if (reading == null && pronunciation == null && partOfSpeech == null) {
      return const SizedBox.shrink();
    }
    final style = context.text.bodyMedium.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    // The row is UI chrome and keeps the ambient direction; only the reading
    // (content in the headword's script) takes the headword direction.
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (reading != null)
          Semantics(
            container: true,
            child: Text(reading, textDirection: textDirection, style: style),
          ),
        if (pronunciation != null)
          Semantics(
            container: true,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                pronunciation,
                style: style.copyWith(
                  fontFamily: AppTypography.fontFamilyPhonetic,
                ),
              ),
            ),
          ),
        if (partOfSpeech != null)
          Semantics(container: true, child: Text(partOfSpeech, style: style)),
      ],
    );
  }
}

String? _nonBlank(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}
