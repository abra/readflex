import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'translation_text_direction.dart';

class TranslationDetails extends StatefulWidget {
  const TranslationDetails({
    required this.lemma,
    required this.explanation,
    required this.alternatives,
    super.key,
  });

  final String? lemma;
  final String? explanation;
  final List<String> alternatives;

  @override
  State<TranslationDetails> createState() => _TranslationDetailsState();
}

class _TranslationDetailsState extends State<TranslationDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final border = Border(
      top: BorderSide(color: context.colors.outlineVariant),
    );
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return ExpansionTile(
      title: Text(
        context.l10n.translationDetails,
        style: context.text.bodyMedium,
      ),
      minTileHeight: AppSizes.buttonHeight,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      shape: border,
      collapsedShape: border,
      expansionAnimationStyle: AnimationStyle(duration: duration),
      onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
      trailing: AnimatedRotation(
        turns: _expanded ? 0.5 : 0,
        duration: duration,
        child: Icon(
          AppIcons.chevronDown,
          size: AppIconSize.sm,
          color: context.colors.onSurfaceVariant,
        ),
      ),
      children: [
        if (widget.lemma != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              widget.lemma!,
              textDirection: translationTextDirection(widget.lemma!),
              style: context.text.bodyMedium.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        if (widget.explanation != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              widget.explanation!,
              style: context.text.bodyMedium,
              textDirection: translationTextDirection(widget.explanation!),
            ),
          ),
        if (widget.alternatives.isNotEmpty) ...[
          Text(
            context.l10n.translationAlternatives,
            style: context.text.labelMedium.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final alternative in widget.alternatives)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                alternative,
                style: context.text.bodyMedium,
                textDirection: translationTextDirection(alternative),
              ),
            ),
        ],
      ],
    );
  }
}
