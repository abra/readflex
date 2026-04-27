import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

/// Visual sandbox for quickly evaluating the current design system in one place.
///
/// TODO: remove or gate behind a dev flag before production release.
class DesignSystemScreen extends StatefulWidget {
  const DesignSystemScreen({super.key});

  @override
  State<DesignSystemScreen> createState() => _DesignSystemScreenState();
}

class _DesignSystemScreenState extends State<DesignSystemScreen> {
  ThemeMode _themeMode = ThemeMode.light;
  int _selectedNavIndex = 0;
  String _selectedChip = 'Paper';
  Set<String> _selectedSegment = {'Comfort'};
  bool _switchValue = true;
  double _sliderValue = 0.58;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('DesignSystemScreen');

    return Theme(
      data: _themeMode == ThemeMode.dark ? AppTheme.dark() : AppTheme.light(),
      child: Builder(
        builder: (context) {
          final colorScheme = context.colors;
          final text = context.text;
          final appColors = context.appColors;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Design System'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(AppIcons.lightMode),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(AppIcons.darkMode),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: (value) {
                      setState(() => _themeMode = value.first);
                    },
                  ),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // ── Color Palette ──────────────────────────────────────
                _SectionCard(
                  title: 'Surface Hierarchy',
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _ColorSwatchCard(
                        label: 'Background',
                        color: colorScheme.surface,
                      ),
                      _ColorSwatchCard(
                        label: 'ContainerLowest',
                        color: colorScheme.surfaceContainerLowest,
                      ),
                      _ColorSwatchCard(
                        label: 'ContainerLow',
                        color: colorScheme.surfaceContainerLow,
                      ),
                      _ColorSwatchCard(
                        label: 'Container',
                        color: colorScheme.surfaceContainer,
                      ),
                      _ColorSwatchCard(
                        label: 'ContainerHigh',
                        color: colorScheme.surfaceContainerHigh,
                      ),
                      _ColorSwatchCard(
                        label: 'ContainerHighest',
                        color: colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Brand Colors',
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _ColorSwatchCard(
                        label: 'Primary',
                        color: colorScheme.primary,
                      ),
                      _ColorSwatchCard(
                        label: 'onPrimary',
                        color: colorScheme.onPrimary,
                      ),
                      _ColorSwatchCard(
                        label: 'Secondary',
                        color: colorScheme.secondary,
                      ),
                      _ColorSwatchCard(
                        label: 'onSecondary',
                        color: colorScheme.onSecondary,
                      ),
                      _ColorSwatchCard(
                        label: 'onSurface',
                        color: colorScheme.onSurface,
                      ),
                      _ColorSwatchCard(
                        label: 'Outline',
                        color: colorScheme.outline,
                      ),
                      _ColorSwatchCard(
                        label: 'Error',
                        color: colorScheme.error,
                      ),
                      _ColorSwatchCard(
                        label: 'onError',
                        color: colorScheme.onError,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Extended: Highlights',
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _ColorSwatchCard(
                        label: 'Yellow',
                        color: appColors.highlightYellow,
                      ),
                      _ColorSwatchCard(
                        label: 'Blue',
                        color: appColors.highlightBlue,
                      ),
                      _ColorSwatchCard(
                        label: 'Green',
                        color: appColors.highlightGreen,
                      ),
                      _ColorSwatchCard(
                        label: 'Pink',
                        color: appColors.highlightPink,
                      ),
                      _ColorSwatchCard(
                        label: 'Purple',
                        color: appColors.highlightPurple,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Extended: FSRS Ratings',
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _ColorSwatchCard(
                        label: 'Again',
                        color: appColors.ratingAgain,
                      ),
                      _ColorSwatchCard(
                        label: 'Hard',
                        color: appColors.ratingHard,
                      ),
                      _ColorSwatchCard(
                        label: 'Good',
                        color: appColors.ratingGood,
                      ),
                      _ColorSwatchCard(
                        label: 'Easy',
                        color: appColors.ratingEasy,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Extended: Semantic',
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _ColorSwatchCard(
                        label: 'Success',
                        color: appColors.success,
                      ),
                      _ColorSwatchCard(
                        label: 'SuccessFg',
                        color: appColors.successForeground,
                      ),
                      _ColorSwatchCard(
                        label: 'Warning',
                        color: appColors.warning,
                      ),
                      _ColorSwatchCard(
                        label: 'WarningFg',
                        color: appColors.warningForeground,
                      ),
                      _ColorSwatchCard(
                        label: 'Info',
                        color: appColors.info,
                      ),
                      _ColorSwatchCard(
                        label: 'ProBadge',
                        color: appColors.proBadge,
                      ),
                      _ColorSwatchCard(
                        label: 'ProBadgeFg',
                        color: appColors.proBadgeForeground,
                      ),
                      _ColorSwatchCard(
                        label: 'Divider',
                        color: appColors.divider,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Typography ────────────────────────────────────────
                _SectionCard(
                  title: 'Typography',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TypeRow(label: 'displayLarge', style: text.displayLarge),
                      _TypeRow(
                        label: 'displayMedium',
                        style: text.displayMedium,
                      ),
                      _TypeRow(label: 'displaySmall', style: text.displaySmall),
                      const Divider(height: AppSpacing.xl),
                      _TypeRow(
                        label: 'headlineLarge',
                        style: text.headlineLarge,
                      ),
                      _TypeRow(
                        label: 'headlineMedium',
                        style: text.headlineMedium,
                      ),
                      _TypeRow(
                        label: 'headlineSmall',
                        style: text.headlineSmall,
                      ),
                      const Divider(height: AppSpacing.xl),
                      _TypeRow(label: 'titleLarge', style: text.titleLarge),
                      _TypeRow(label: 'titleMedium', style: text.titleMedium),
                      _TypeRow(label: 'titleSmall', style: text.titleSmall),
                      const Divider(height: AppSpacing.xl),
                      _TypeRow(label: 'bodyLarge', style: text.bodyLarge),
                      _TypeRow(label: 'bodyMedium', style: text.bodyMedium),
                      _TypeRow(label: 'bodySmall', style: text.bodySmall),
                      const Divider(height: AppSpacing.xl),
                      _TypeRow(label: 'labelLarge', style: text.labelLarge),
                      _TypeRow(label: 'labelMedium', style: text.labelMedium),
                      _TypeRow(label: 'labelSmall', style: text.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Spacing ───────────────────────────────────────────
                _SectionCard(
                  title: 'Spacing Tokens',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SpacingRow(label: 'xxs = 2', size: AppSpacing.xxs),
                      _SpacingRow(label: 'xs  = 4', size: AppSpacing.xs),
                      _SpacingRow(label: 'sm  = 8', size: AppSpacing.sm),
                      _SpacingRow(label: 'md  = 12', size: AppSpacing.md),
                      _SpacingRow(label: 'lg  = 16', size: AppSpacing.lg),
                      _SpacingRow(label: 'xl  = 24', size: AppSpacing.xl),
                      _SpacingRow(label: 'xxl = 48', size: AppSpacing.xxl),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Radius ────────────────────────────────────────────
                _SectionCard(
                  title: 'Radius Tokens',
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      _RadiusSwatch(label: 'xs = 4', radius: AppRadius.xs),
                      _RadiusSwatch(label: 'sm = 8', radius: AppRadius.sm),
                      _RadiusSwatch(label: 'md = 12', radius: AppRadius.md),
                      _RadiusSwatch(label: 'lg = 16', radius: AppRadius.lg),
                      _RadiusSwatch(label: 'xl = 28', radius: AppRadius.xl),
                      _RadiusSwatch(
                        label: 'full = 999',
                        radius: AppRadius.full,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Buttons ───────────────────────────────────────────
                _SectionCard(
                  title: 'Buttons',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Primary Action'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Secondary Action'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text('Text Button'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(AppIcons.bookmark),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(AppIcons.tune),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Inputs & Selection ────────────────────────────────
                _SectionCard(
                  title: 'Inputs And Selection',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TextField(
                        decoration: InputDecoration(
                          labelText: 'Article URL',
                          hintText: 'https://example.com/story',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const SearchField(
                        hintText: 'Search books & articles...',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: 'Comfort',
                            label: Text('Comfort'),
                          ),
                          ButtonSegment(
                            value: 'Focus',
                            label: Text('Focus'),
                          ),
                          ButtonSegment(
                            value: 'Study',
                            label: Text('Study'),
                          ),
                        ],
                        selected: _selectedSegment,
                        onSelectionChanged: (value) {
                          setState(() => _selectedSegment = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: ['Paper', 'Warm', 'Mist', 'Night'].map((
                          chip,
                        ) {
                          return ChoiceChip(
                            label: Text(chip),
                            selected: _selectedChip == chip,
                            onSelected: (_) {
                              setState(() => _selectedChip = chip);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile.adaptive(
                        value: _switchValue,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reduce visual noise'),
                        subtitle: const Text('Example of a settings row'),
                        onChanged: (value) {
                          setState(() => _switchValue = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Text size', style: text.labelLarge),
                      Slider(
                        value: _sliderValue,
                        onChanged: (value) {
                          setState(() => _sliderValue = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Badges ────────────────────────────────────────────
                _SectionCard(
                  title: 'Badges',
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppBadge(
                        label: 'PRO',
                        foreground: appColors.proBadgeForeground,
                        background: appColors.proBadge,
                      ),
                      AppBadge(
                        label: 'Mastered',
                        foreground: appColors.successForeground,
                        background: appColors.success.withValues(alpha: 0.12),
                      ),
                      AppBadge(
                        label: 'New',
                        foreground: colorScheme.primary,
                        background: colorScheme.primary.withValues(alpha: 0.12),
                      ),
                      AppBadge(
                        label: 'Article',
                        foreground: colorScheme.onSecondary,
                        background: colorScheme.secondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Cards & Rows ──────────────────────────────────────
                _SectionCard(
                  title: 'Cards And Rows',
                  child: Column(
                    children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(AppIcons.book),
                          title: const Text('Sample Article'),
                          subtitle: const Text(
                            'A quiet reading surface with subtle borders',
                          ),
                          trailing: Text('12 min', style: text.labelMedium),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ActionRowCard(
                        leading: const Icon(AppIcons.sparkles),
                        title: 'Premium',
                        subtitle:
                            'Unlock AI tools and deeper reading workflows',
                        action: FilledButton(
                          onPressed: () {},
                          child: const Text('Upgrade'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Stat Cards ────────────────────────────────────────
                _SectionCard(
                  title: 'Stat Cards',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              value: '42',
                              label: 'Books read',
                              icon: AppIcons.book,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: StatCard(
                              value: '1,248',
                              label: 'Flashcards',
                              icon: AppIcons.flashcard,
                              color: appColors.info,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: StatCard(
                              value: '97%',
                              label: 'Retention',
                              icon: AppIcons.practice,
                              color: appColors.successForeground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(value: '128', label: 'Highlights'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: StatCard(value: '14', label: 'Streak days'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Settings ──────────────────────────────────────────
                _SectionCard(
                  title: 'Settings Group',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel(label: 'ACCOUNT'),
                      const SizedBox(height: AppSpacing.sm),
                      SettingsGroup(
                        children: [
                          SettingsRow(
                            icon: AppIcons.profile,
                            label: 'Profile',
                            detail: 'Jane Doe',
                            onTap: () {},
                          ),
                          SettingsRow(
                            icon: AppIcons.notifications,
                            label: 'Notifications',
                            onTap: () {},
                          ),
                          SettingsRow(
                            icon: AppIcons.language,
                            label: 'Language',
                            detail: 'English',
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const SectionLabel(label: 'ABOUT'),
                      const SizedBox(height: AppSpacing.sm),
                      SettingsGroup(
                        children: [
                          SettingsRow(
                            icon: AppIcons.info,
                            label: 'Version',
                            detail: '1.0.0',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── States ────────────────────────────────────────────
                _SectionCard(
                  title: 'Empty States',
                  child: Column(
                    children: [
                      SizedBox(
                        height: 160,
                        child: EmptyState(
                          icon: AppIcons.library,
                          message: 'Your library is empty',
                          subtitle: 'Add a book or article to get started',
                        ),
                      ),
                      const Divider(height: AppSpacing.xl),
                      const SizedBox(
                        height: 100,
                        child: EmptyState(message: 'No results found'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SectionCard(
                  title: 'Error State',
                  child: SizedBox(
                    height: 120,
                    child: ErrorState(
                      message: 'Failed to load library',
                      retryLabel: 'Retry',
                      onRetry: () {},
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Misc Components ───────────────────────────────────
                _SectionCard(
                  title: 'Misc Components',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BottomSheetHeader(title: 'Add Highlight', onClose: () {}),
                      const Divider(height: AppSpacing.xl),
                      const SelectionPreviewCard(
                        text:
                            'The obstacle is the way. What stands in the way becomes the way.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const OfflineBanner(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Cover Art ─────────────────────────────────────────
                const _SectionCard(
                  title: 'Cover Art',
                  child: _CoverArtPreview(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Library Grid ──────────────────────────────────────
                _SectionCard(
                  title: 'Library Grid',
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.48,
                    children: const [
                      _DemoLibraryCard(
                        title: 'Atomic Habits',
                        subtitle: 'James Clear',
                        meta: '42% read',
                        media: _DemoBookMedia(label: 'AB'),
                      ),
                      _DemoLibraryCard(
                        title: 'Matter-style Reading Interfaces',
                        subtitle: 'matter.com',
                        meta: 'Article',
                        media: _DemoArticleMedia(domain: 'matter.com'),
                      ),
                      _DemoLibraryCard(
                        title: 'Deep Work',
                        subtitle: 'Cal Newport',
                        meta: 'New book',
                        media: _DemoBookMedia(label: 'DW'),
                      ),
                      _DemoLibraryCard(
                        title: 'Long-form UX for Focused Reading',
                        subtitle: 'readwise.io',
                        meta: '1,248 words',
                        media: _DemoArticleMedia(domain: 'readwise.io'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Reader Presets ────────────────────────────────────
                _SectionCard(
                  title: 'Reader Presets',
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: ReaderThemePreset.values.map((preset) {
                      return _ReaderPresetCard(
                        label: preset.label,
                        themeData: preset.data,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Icons ─────────────────────────────────────────────
                const _SectionCard(
                  title: 'Icons',
                  child: _IconsPreview(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Navigation ────────────────────────────────────────
                _SectionCard(
                  title: 'Navigation',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: NavigationBar(
                      selectedIndex: _selectedNavIndex,
                      onDestinationSelected: (index) {
                        setState(() => _selectedNavIndex = index);
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(AppIcons.home),
                          selectedIcon: Icon(AppIcons.home),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Icon(AppIcons.library),
                          selectedIcon: Icon(AppIcons.library),
                          label: 'Library',
                        ),
                        NavigationDestination(
                          icon: Icon(AppIcons.dictionary),
                          selectedIcon: Icon(AppIcons.dictionary),
                          label: 'Dictionary',
                        ),
                        NavigationDestination(
                          icon: Icon(AppIcons.practice),
                          selectedIcon: Icon(AppIcons.practice),
                          label: 'Practice',
                        ),
                        NavigationDestination(
                          icon: Icon(AppIcons.profile),
                          selectedIcon: Icon(AppIcons.profile),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Section scaffold ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Color swatch ──────────────────────────────────────────────────────────

class _ColorSwatchCard extends StatelessWidget {
  const _ColorSwatchCard({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Container(
      width: 112,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelMedium.copyWith(color: textColor),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: context.text.bodySmall.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

// ─── Typography row ────────────────────────────────────────────────────────

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.label, required this.style});

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final family = style.fontFamily ?? AppTypography.fontFamilySans;
    final isSerif = family.contains('Serif') || family.contains('serif');
    final familyLabel = isSerif ? 'Serif' : 'Sans';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: context.text.labelSmall.copyWith(
                color: cs.onSurface.withValues(alpha: 0.45),
                fontFamily: AppTypography.fontFamilySans,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: isSerif ? cs.primary.withValues(alpha: 0.1) : cs.secondary,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              familyLabel,
              style: context.text.labelSmall.copyWith(
                fontSize: 9,
                color: isSerif
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.55),
                fontFamily: AppTypography.fontFamilySans,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'The quick brown fox',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Spacing row ───────────────────────────────────────────────────────────

class _SpacingRow extends StatelessWidget {
  const _SpacingRow({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: context.text.labelSmall.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.55),
                fontFamily: AppTypography.fontFamilySans,
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            color: context.colors.primary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

// ─── Radius swatch ─────────────────────────────────────────────────────────

class _RadiusSwatch extends StatelessWidget {
  const _RadiusSwatch({required this.label, required this.radius});

  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(radius.clamp(0, 26)),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: context.text.labelSmall.copyWith(
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

// ─── Reader preset card ────────────────────────────────────────────────────

class _ReaderPresetCard extends StatelessWidget {
  const _ReaderPresetCard({required this.label, required this.themeData});

  final String label;
  final ReaderThemeData themeData;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: themeData.surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: themeData.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelLarge.copyWith(
              color: themeData.secondaryTextColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A quiet page for long-form reading.',
            style: context.text.bodyMedium.copyWith(
              color: themeData.primaryTextColor,
              height: 1.55,
              fontFamily: AppTypography.fontFamilySerif,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 10,
            width: 60,
            decoration: BoxDecoration(
              color: themeData.panelColor,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Icons preview ─────────────────────────────────────────────────────────

class _IconsPreview extends StatelessWidget {
  const _IconsPreview();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final groups = <(String, List<(String, IconData)>)>[
      (
        'Navigation',
        [
          ('home', AppIcons.home),
          ('library', AppIcons.library),
          ('dictionary', AppIcons.dictionary),
          ('practice', AppIcons.practice),
          ('profile', AppIcons.profile),
        ],
      ),
      (
        'Actions',
        [
          ('add', AppIcons.add),
          ('close', AppIcons.close),
          ('search', AppIcons.search),
          ('refresh', AppIcons.refresh),
          ('remove', AppIcons.remove),
          ('moreHoriz', AppIcons.moreHorizontal),
          ('chevronRight', AppIcons.chevronRight),
        ],
      ),
      (
        'Content',
        [
          ('book', AppIcons.book),
          ('article', AppIcons.article),
          ('bookmark', AppIcons.bookmark),
          ('highlight', AppIcons.highlight),
          ('flashcard', AppIcons.flashcard),
          ('check', AppIcons.check),
          ('clock', AppIcons.clock),
          ('quote', AppIcons.quote),
        ],
      ),
      (
        'Reader & Theme',
        [
          ('translate', AppIcons.translate),
          ('viewList', AppIcons.viewList),
          ('viewGrid', AppIcons.viewGrid),
          ('lightMode', AppIcons.lightMode),
          ('darkMode', AppIcons.darkMode),
          ('systemMode', AppIcons.systemMode),
        ],
      ),
      (
        'States & Premium',
        [
          ('error', AppIcons.error),
          ('offline', AppIcons.offline),
          ('sparkles', AppIcons.sparkles),
          ('premium', AppIcons.premium),
          ('info', AppIcons.info),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (groupName, icons) in groups) ...[
          Text(
            groupName,
            style: context.text.labelSmall.copyWith(
              color: cs.onSurface.withValues(alpha: 0.45),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (iconLabel, icon) in icons)
                Column(
                  children: [
                    Icon(icon, size: AppIconSize.md, color: cs.onSurface),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      iconLabel,
                      style: context.text.labelSmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.45),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

// ─── Demo library card ─────────────────────────────────────────────────────

class _DemoLibraryCard extends StatelessWidget {
  const _DemoLibraryCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.media,
  });

  final String title;
  final String subtitle;
  final String meta;
  final Widget media;

  @override
  Widget build(BuildContext context) {
    return MediaCollectionCard(
      media: media,
      title: title,
      subtitle: subtitle,
      meta: meta,
      topRight: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.xs),
          child: Icon(AppIcons.moreHorizontal, size: AppIconSize.sm),
        ),
      ),
    );
  }
}

class _DemoBookMedia extends StatelessWidget {
  const _DemoBookMedia({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surfaceContainerHighest, colors.surfaceContainer],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Text('BOOK', style: text.labelSmall),
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: text.displaySmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoArticleMedia extends StatelessWidget {
  const _DemoArticleMedia({required this.domain});

  final String domain;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceContainerHighest),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WWW',
              style: text.displaySmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(domain, style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'ARTICLE',
              style: text.labelMedium.copyWith(
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action row card ───────────────────────────────────────────────────────

class _ActionRowCard extends StatelessWidget {
  const _ActionRowCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: leading,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: context.text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(child: action),
          ],
        ),
      ),
    );
  }
}

// ─── Cover art preview ─────────────────────────────────────────────────────

class _CoverArtSample {
  const _CoverArtSample({
    required this.title,
    this.author,
    this.source,
    this.isArticle = false,
    this.progress,
  });

  final String title;
  final String? author;
  final String? source;
  final bool isArticle;
  final double? progress;
}

const _coverArtSamples = <_CoverArtSample>[
  _CoverArtSample(
    title: 'Atomic Habits',
    author: 'James Clear',
    progress: 0.42,
  ),
  _CoverArtSample(title: 'Deep Work', author: 'Cal Newport'),
  _CoverArtSample(
    title: 'Matter-style Reading Interfaces',
    source: 'matter.com',
    isArticle: true,
    progress: 0.65,
  ),
  _CoverArtSample(
    title: 'Long-form UX for Focused Reading',
    source: 'readwise.io',
    isArticle: true,
  ),
  _CoverArtSample(
    title: 'Thinking in Systems',
    author: 'Donella Meadows',
    progress: 0.9,
  ),
  _CoverArtSample(title: 'The Pragmatic Programmer', author: 'Hunt & Thomas'),
];

class _CoverArtPreview extends StatelessWidget {
  const _CoverArtPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.66,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _coverArtSamples.length,
          itemBuilder: (context, index) {
            final sample = _coverArtSamples[index];
            return LayoutBuilder(
              builder: (context, constraints) => AppCoverArt(
                title: sample.title,
                author: sample.author,
                source: sample.source,
                isArticle: sample.isArticle,
                progress: sample.progress,
                height: constraints.maxHeight,
                width: constraints.maxWidth,
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: const [
            SizedBox(
              width: 44,
              height: 60,
              child: AppCoverArt(
                title: 'Atomic Habits',
                height: 60,
                width: 44,
                showAuthor: false,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 44,
              height: 60,
              child: AppCoverArt(
                title: 'Matter Reading',
                isArticle: true,
                progress: 0.4,
                height: 60,
                width: 44,
                showAuthor: false,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 44,
              height: 60,
              child: AppCoverArt(
                title: 'Deep Work',
                height: 60,
                width: 44,
                showAuthor: false,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 44,
              height: 60,
              child: AppCoverArt(
                title: 'The Pragmatic Programmer',
                height: 60,
                width: 44,
                showAuthor: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
