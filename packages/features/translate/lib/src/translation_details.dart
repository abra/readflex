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
    final content = _TranslationDetailsContent(
      explanation: widget.explanation,
      alternatives: widget.alternatives,
    );
    if (context.isCupertino) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: AppTappable(
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.buttonHeight,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.translationDetails,
                        style: context.text.labelLarge,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: duration,
                      child: Icon(
                        AppIcons.chevronDown,
                        size: AppIconSize.sm,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            alignment: AlignmentDirectional.topStart,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: content,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      );
    }
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
      children: [content],
    );
  }
}

class _TranslationDetailsContent extends StatelessWidget {
  const _TranslationDetailsContent({
    required this.explanation,
    required this.alternatives,
  });

  final String? explanation;
  final List<String> alternatives;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (explanation != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            explanation!,
            style: context.text.bodyMedium,
            textDirection: translationTextDirection(explanation!),
          ),
        ),
      if (alternatives.isNotEmpty) ...[
        Text(
          context.l10n.translationAlternatives,
          style: context.text.labelMedium.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final alternative in alternatives)
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
