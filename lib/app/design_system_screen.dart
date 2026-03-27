import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

/// Visual sandbox for quickly evaluating the current design system in one place.
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
    return Theme(
      data: _themeMode == ThemeMode.dark
          ? const DarkAppThemeData().materialThemeData
          : const LightAppThemeData().materialThemeData,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Design System'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.medium),
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
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
              padding: const EdgeInsets.all(Spacing.large),
              children: [
                Text(
                  'A compact preview of the app shell and reader surfaces.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: Spacing.large),
                _SectionCard(
                  title: 'Color Palette',
                  child: Wrap(
                    spacing: Spacing.small,
                    runSpacing: Spacing.small,
                    children: [
                      _ColorSwatchCard(
                        label: 'Scaffold',
                        color: theme.scaffoldBackgroundColor,
                      ),
                      _ColorSwatchCard(
                        label: 'Surface',
                        color: colorScheme.surface,
                      ),
                      _ColorSwatchCard(
                        label: 'Raised',
                        color: colorScheme.surfaceContainerHigh,
                      ),
                      _ColorSwatchCard(
                        label: 'Tint',
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      _ColorSwatchCard(
                        label: 'Primary',
                        color: colorScheme.primary,
                      ),
                      _ColorSwatchCard(
                        label: 'Border',
                        color: colorScheme.outline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.large),
                _SectionCard(
                  title: 'Typography',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display Large',
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: Spacing.small),
                      Text('Title Medium', style: theme.textTheme.titleMedium),
                      const SizedBox(height: Spacing.small),
                      Text(
                        'Body text is tuned for a calmer, reading-first hierarchy instead of stock Material.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: Spacing.small),
                      Text(
                        'Label text / utility controls',
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.large),
                _SectionCard(
                  title: 'Buttons',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Primary Action'),
                      ),
                      const SizedBox(height: Spacing.small),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Secondary Action'),
                      ),
                      const SizedBox(height: Spacing.small),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text('Text Button'),
                          ),
                          const SizedBox(width: Spacing.small),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.bookmark_border),
                          ),
                          const SizedBox(width: Spacing.small),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.tune),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.large),
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
                      const SizedBox(height: Spacing.medium),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: 'Comfort',
                            label: Text('Comfort'),
                          ),
                          ButtonSegment(value: 'Focus', label: Text('Focus')),
                          ButtonSegment(value: 'Study', label: Text('Study')),
                        ],
                        selected: _selectedSegment,
                        onSelectionChanged: (value) {
                          setState(() => _selectedSegment = value);
                        },
                      ),
                      const SizedBox(height: Spacing.medium),
                      Wrap(
                        spacing: Spacing.small,
                        runSpacing: Spacing.small,
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
                      const SizedBox(height: Spacing.medium),
                      SwitchListTile.adaptive(
                        value: _switchValue,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reduce visual noise'),
                        subtitle: const Text('Example of a settings row'),
                        onChanged: (value) {
                          setState(() => _switchValue = value);
                        },
                      ),
                      const SizedBox(height: Spacing.small),
                      Text(
                        'Text size',
                        style: theme.textTheme.labelLarge,
                      ),
                      Slider(
                        value: _sliderValue,
                        onChanged: (value) {
                          setState(() => _sliderValue = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.large),
                _SectionCard(
                  title: 'Library Grid',
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: Spacing.medium,
                    mainAxisSpacing: Spacing.medium,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.58,
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
                const SizedBox(height: Spacing.large),
                _SectionCard(
                  title: 'Cards And Rows',
                  child: Column(
                    children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.menu_book_outlined),
                          title: const Text('Sample Article'),
                          subtitle: const Text(
                            'A quiet reading surface with subtle borders',
                          ),
                          trailing: Text(
                            '12 min',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.small),
                      _ActionRowCard(
                        leading: const Icon(Icons.auto_awesome_outlined),
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
                const SizedBox(height: Spacing.large),
                _SectionCard(
                  title: 'Reader Presets',
                  child: Wrap(
                    spacing: Spacing.medium,
                    runSpacing: Spacing.medium,
                    children: ReaderThemePreset.values.map((preset) {
                      return _ReaderPresetCard(
                        label: preset.label,
                        themeData: preset.data,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: Spacing.large),
                _SectionCard(
                  title: 'Navigation',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    child: NavigationBar(
                      selectedIndex: _selectedNavIndex,
                      onDestinationSelected: (index) {
                        setState(() => _selectedNavIndex = index);
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.library_books_outlined),
                          selectedIcon: Icon(Icons.library_books),
                          label: 'Library',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xxLarge),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.mediumLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.medium),
            child,
          ],
        ),
      ),
    );
  }
}

class _ColorSwatchCard extends StatelessWidget {
  const _ColorSwatchCard({
    required this.label,
    required this.color,
  });

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
      padding: const EdgeInsets.all(Spacing.small),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
            ),
          ),
          const SizedBox(height: Spacing.large),
          Text(
            '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderPresetCard extends StatelessWidget {
  const _ReaderPresetCard({
    required this.label,
    required this.themeData,
  });

  final String label;
  final ReaderThemeData themeData;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: themeData.surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: themeData.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: themeData.secondaryTextColor,
            ),
          ),
          const SizedBox(height: Spacing.small),
          Text(
            'A quiet page for long-form reading.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: themeData.primaryTextColor,
              height: 1.55,
              fontFamily: 'SourceSerif4',
            ),
          ),
          const SizedBox(height: Spacing.medium),
          Container(
            height: 10,
            width: 60,
            decoration: BoxDecoration(
              color: themeData.panelColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

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
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: const Padding(
          padding: EdgeInsets.all(Spacing.xSmall),
          child: Icon(Icons.more_horiz, size: 18),
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
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainer,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.mediumLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.small,
                  vertical: 6,
                ),
                child: Text('BOOK', style: theme.textTheme.labelSmall),
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.mediumLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WWW',
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(domain, style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.small),
            Text(
              'ARTICLE',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.all(Spacing.mediumLarge),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: leading,
            ),
            const SizedBox(width: Spacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: Spacing.xSmall),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.medium),
            Flexible(child: action),
          ],
        ),
      ),
    );
  }
}
