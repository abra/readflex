part of '../profile_screen.dart';

// ─── Font & Text Size Sheet ────────────────────────────────

// Reader appearance bounds — mirror the values the cubit clamps against.
const double _minTextScale = 0.85;
const double _maxTextScale = 1.45;
const double _textScaleStep = 0.05;
const List<double> _lineHeightPresets = [1.2, 1.4, 1.6, 1.8, 2.0];
const double _lineHeightMatchTolerance = 0.05;

// Sheet chrome.
const double _sizeButtonSize = 36;
const double _previewCardHeight = 152;

class _FontSheet extends StatelessWidget {
  const _FontSheet();

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout(
      title: 'Font & Text Size',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label: 'FONT'),
          const SizedBox(height: AppSpacing.sm),
          const _FontRow(),
          const SizedBox(height: AppSpacing.lg),
          const _SizeSection(),
          const SizedBox(height: AppSpacing.lg),
          const _LineSpacingSection(),
          const SizedBox(height: AppSpacing.lg),
          const _FontPreview(),
        ],
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileAppearanceCubit, ProfileAppearanceState, String>(
      selector: (s) => s.readerAppearance.fontId,
      builder: (context, fontId) {
        final cubit = context.read<ProfileAppearanceCubit>();
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final preset in ReaderFontPreset.values)
              _FontButton(
                preset: preset,
                active: preset.id == fontId,
                onTap: () => cubit.setReaderFont(preset.id),
              ),
          ],
        );
      },
    );
  }
}

class _FontButton extends StatelessWidget {
  const _FontButton({
    required this.preset,
    required this.active,
    required this.onTap,
  });

  final ReaderFontPreset preset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: active ? cs.onSurface : cs.secondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          preset.label,
          style: text.bodyMedium.copyWith(
            color: active ? cs.surface : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _SizeSection extends StatelessWidget {
  const _SizeSection();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileAppearanceCubit, ProfileAppearanceState, double>(
      selector: (s) => s.readerAppearance.textScale,
      builder: (context, textScale) {
        final cs = context.colors;
        final text = context.text;
        final cubit = context.read<ProfileAppearanceCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SectionLabel(label: 'SIZE'),
                const Spacer(),
                Text(
                  '${(textScale * 100).round()}%',
                  style: text.labelSmall.copyWith(
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _SizeButton(
                  icon: AppIcons.remove,
                  onTap: () {
                    final v = (textScale - _textScaleStep).clamp(
                      _minTextScale,
                      _maxTextScale,
                    );
                    cubit.previewTextScale(v);
                    cubit.commitTextScale(v);
                  },
                ),
                Expanded(
                  child: Slider(
                    value: textScale,
                    min: _minTextScale,
                    max: _maxTextScale,
                    onChanged: cubit.previewTextScale,
                    onChangeEnd: cubit.commitTextScale,
                  ),
                ),
                _SizeButton(
                  icon: AppIcons.add,
                  onTap: () {
                    final v = (textScale + _textScaleStep).clamp(
                      _minTextScale,
                      _maxTextScale,
                    );
                    cubit.previewTextScale(v);
                    cubit.commitTextScale(v);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LineSpacingSection extends StatelessWidget {
  const _LineSpacingSection();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileAppearanceCubit, ProfileAppearanceState, double>(
      selector: (s) => s.readerAppearance.lineHeight,
      builder: (context, lineHeight) {
        final cs = context.colors;
        final text = context.text;
        final cubit = context.read<ProfileAppearanceCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SectionLabel(label: 'LINE SPACING'),
                const Spacer(),
                Text(
                  lineHeight.toStringAsFixed(1),
                  style: text.labelSmall.copyWith(
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final v in _lineHeightPresets)
                  _LineHeightButton(
                    value: v,
                    active: (lineHeight - v).abs() < _lineHeightMatchTolerance,
                    isLast: v == _lineHeightPresets.last,
                    onTap: () {
                      cubit.previewLineHeight(v);
                      cubit.commitLineHeight(v);
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LineHeightButton extends StatelessWidget {
  const _LineHeightButton({
    required this.value,
    required this.active,
    required this.isLast,
    required this.onTap,
  });

  final double value;
  final bool active;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.sm),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: active
                  ? cs.onSurface
                  : cs.secondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Text(
              value.toStringAsFixed(1),
              style: text.labelSmall.copyWith(
                fontWeight: FontWeight.w500,
                color: active
                    ? cs.surface
                    : cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FontPreview extends StatelessWidget {
  const _FontPreview();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileAppearanceCubit, ProfileAppearanceState>(
      buildWhen: (prev, curr) =>
          prev.readerAppearance.fontId != curr.readerAppearance.fontId ||
          prev.readerAppearance.textScale != curr.readerAppearance.textScale ||
          prev.readerAppearance.lineHeight != curr.readerAppearance.lineHeight,
      builder: (context, state) {
        final cs = context.colors;
        final text = context.text;
        final readerFont = ReaderFontPreset.fromId(
          state.readerAppearance.fontId,
        );
        return SizedBox(
          height: _previewCardHeight,
          width: double.infinity,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIEW',
                  style: text.labelSmall.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'The happiness of your life depends upon the quality of your thoughts.',
                    maxLines: 2,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontFamily: readerFont.fontFamily,
                      fontSize:
                          text.bodyMedium.fontSize! *
                          state.readerAppearance.textScale,
                      height: state.readerAppearance.lineHeight,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _sizeButtonSize,
        height: _sizeButtonSize,
        decoration: BoxDecoration(
          color: cs.secondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: AppIconSize.sm, color: cs.onSurface),
      ),
    );
  }
}
