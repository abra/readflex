part of 'translate_sheet.dart';

/// Explanation and alternatives, collapsed under **Meaning & alternatives**.
class _TranslationDetails extends StatefulWidget {
  const _TranslationDetails({
    required this.explanation,
    required this.alternatives,
    super.key,
  });

  final String? explanation;
  final List<String> alternatives;

  @override
  State<_TranslationDetails> createState() => _TranslationDetailsState();
}

class _TranslationDetailsState extends State<_TranslationDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(AppMotion.short);
    // Its section's outline frames the tile, so the tile draws no border; the
    // title is styled as the section's title.
    return ExpansionTile(
      title: Text(
        context.l10n.translationDetails,
        style: context.text.labelLarge,
      ),
      minTileHeight: AppSizes.buttonHeight,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      shape: const Border(),
      collapsedShape: const Border(),
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
