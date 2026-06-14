part of '../profile_screen.dart';

const _translationLanguageOptions = [
  _TranslationLanguageOption(code: 'en', label: 'English'),
  _TranslationLanguageOption(code: 'ru', label: 'Russian'),
];

String _translationLanguageLabel(String? code) {
  if (code == null) return 'Auto';
  for (final option in _translationLanguageOptions) {
    if (option.code == code) return option.label;
  }
  return code.toUpperCase();
}

class _TranslationLanguageOption {
  const _TranslationLanguageOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

class _LanguageSelectionSheet extends StatelessWidget {
  const _LanguageSelectionSheet({
    required this.title,
    required this.selectedCode,
    required this.includeAuto,
    required this.onSelected,
  });

  final String title;
  final String? selectedCode;
  final bool includeAuto;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout(
      title: title,
      child: SettingsGroup(
        children: [
          if (includeAuto)
            _LanguageOptionRow(
              icon: AppIcons.systemMode,
              label: 'Auto',
              selected: selectedCode == null,
              onTap: () => _select(context, null),
            ),
          for (final option in _translationLanguageOptions)
            _LanguageOptionRow(
              icon: AppIcons.language,
              label: option.label,
              selected: selectedCode == option.code,
              onTap: () => _select(context, option.code),
            ),
        ],
      ),
    );
  }

  void _select(BuildContext context, String? code) {
    Navigator.of(context).pop();
    onSelected(code);
  }
}

class _LanguageOptionRow extends StatelessWidget {
  const _LanguageOptionRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final text = context.text;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppIconSize.sm,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: text.bodyMedium.copyWith(color: cs.onSurface),
              ),
            ),
            if (selected)
              Icon(
                AppIcons.check,
                size: AppIconSize.sm,
                color: cs.primary,
              ),
          ],
        ),
      ),
    );
  }
}
