part of '../profile_screen.dart';

// ─── Font & Text Size Sheet ────────────────────────────────

// Reader appearance bounds — mirror the values the cubit clamps against.
const double _minTextScale = 0.85;
const double _maxTextScale = 1.45;
const double _textScaleStep = 0.05;
const List<double> _lineHeightPresets = [1.2, 1.4, 1.6, 1.8, 2.0];
const double _lineHeightMatchTolerance = 0.05;

// Sheet chrome.
const double _dragHandleWidth = 40;
const double _dragHandleHeight = 4;
const double _sizeButtonSize = 36;

class _FontSheet extends StatelessWidget {
  const _FontSheet();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return BlocBuilder<ProfileAppearanceCubit, ProfileAppearanceState>(
      builder: (context, state) {
        final cubit = context.read<ProfileAppearanceCubit>();
        final readerFont = ReaderFontPreset.fromId(
          state.readerAppearance.fontId,
        );
        final textScale = state.readerAppearance.textScale;
        final lineHeight = state.readerAppearance.lineHeight;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl + bottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: _dragHandleWidth,
                  height: _dragHandleHeight,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                'Font & Text Size',
                style: text.titleLarge.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Font selection
              SectionLabel(label: 'FONT'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: ReaderFontPreset.values.map((preset) {
                  final active = preset == readerFont;
                  return GestureDetector(
                    onTap: () => cubit.setReaderFont(preset.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? cs.onSurface
                            : cs.secondary.withValues(alpha: 0.5),
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
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Size
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
              const SizedBox(height: AppSpacing.lg),

              // Line spacing
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
                children: _lineHeightPresets.map((v) {
                  final active =
                      (lineHeight - v).abs() < _lineHeightMatchTolerance;
                  final isLast = v == _lineHeightPresets.last;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: isLast ? 0 : AppSpacing.sm,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          cubit.previewLineHeight(v);
                          cubit.commitLineHeight(v);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? cs.onSurface
                                : cs.secondary.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            v.toStringAsFixed(1),
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
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Preview
              Container(
                width: double.infinity,
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
                      style: context.text.labelSmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'The happiness of your life depends upon the quality of your thoughts.',
                      style: TextStyle(
                        fontFamily: readerFont.fontFamily,
                        fontSize: text.bodyMedium.fontSize! * textScale,
                        height: lineHeight,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
