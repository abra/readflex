import 'package:auth_service/auth_service.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:subscription_service/subscription_service.dart';

import 'profile_appearance_cubit.dart';
import 'profile_cubit.dart';

/// Profile tab: settings, auth status, premium.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.authService,
    required this.subscriptionService,
    required this.preferencesService,
    required this.onSignInPressed,
    required this.onDesignSystemPressed,
    required this.onPremiumPressed,
    super.key,
  });

  final AuthService authService;
  final SubscriptionService subscriptionService;
  final PreferencesService preferencesService;
  final VoidCallback onSignInPressed;
  final VoidCallback onDesignSystemPressed;
  final VoidCallback onPremiumPressed;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ProfileCubit(
            authService: authService,
            subscriptionService: subscriptionService,
          )..load(),
        ),
        BlocProvider(
          create: (_) => ProfileAppearanceCubit(
            preferencesService: preferencesService,
          ),
        ),
      ],
      child: ProfileView(
        onSignInPressed: onSignInPressed,
        onDesignSystemPressed: onDesignSystemPressed,
        onPremiumPressed: onPremiumPressed,
      ),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({
    required this.onSignInPressed,
    required this.onDesignSystemPressed,
    required this.onPremiumPressed,
    super.key,
  });

  final VoidCallback onSignInPressed;
  final VoidCallback onDesignSystemPressed;
  final VoidCallback onPremiumPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.large),
        children: [
          BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              return Column(
                children: [
                  _InfoActionCard(
                    leading: Icon(
                      state.isAuthenticated
                          ? Icons.person
                          : Icons.person_outline,
                    ),
                    title: state.isAuthenticated
                        ? state.email ?? 'Signed in'
                        : 'Not signed in',
                    subtitle: state.isAuthenticated
                        ? null
                        : 'Sign in to sync your data',
                    action: state.isAuthenticated
                        ? TextButton(
                            onPressed: state.isLoading
                                ? null
                                : () => context.read<ProfileCubit>().signOut(),
                            child: const Text('Sign out'),
                          )
                        : FilledButton(
                            onPressed: onSignInPressed,
                            child: const Text('Sign in'),
                          ),
                  ),
                  const SizedBox(height: Spacing.medium),
                  _InfoActionCard(
                    leading: Icon(
                      state.isPremium ? Icons.star : Icons.star_border,
                    ),
                    title: state.isPremium ? 'Premium' : 'Free plan',
                    subtitle: state.isPremium
                        ? null
                        : 'Unlock AI features and more',
                    action: state.isPremium
                        ? null
                        : FilledButton.tonal(
                            onPressed: onPremiumPressed,
                            child: const Text('Upgrade'),
                          ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: Spacing.large),
          const _AppearanceSection(),
          const SizedBox(height: Spacing.large),
          _InfoActionCard(
            leading: const Icon(Icons.design_services_outlined),
            title: 'Design System Preview',
            subtitle: 'Open the live component showcase screen',
            action: OutlinedButton(
              onPressed: onDesignSystemPressed,
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: Spacing.large),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About Readflex'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _InfoActionCard extends StatelessWidget {
  const _InfoActionCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? action;

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
                  if (subtitle != null) ...[
                    const SizedBox(height: Spacing.xSmall),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: Spacing.medium),
              Flexible(child: action!),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppearanceSection extends StatefulWidget {
  const _AppearanceSection();

  @override
  State<_AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends State<_AppearanceSection> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileAppearanceCubit, ProfileAppearanceState>(
      builder: (context, state) {
        final readerTheme = ReaderThemePreset.fromId(
          state.readerAppearance.themeId,
        );
        final readerFont = ReaderFontPreset.fromId(
          state.readerAppearance.fontId,
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.mediumLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Spacing.medium),
                _ReaderPreviewCard(
                  theme: readerTheme.data,
                  font: readerFont,
                  textScale: state.readerAppearance.textScale,
                  lineHeight: state.readerAppearance.lineHeight,
                ),
                const SizedBox(height: Spacing.mediumLarge),
                Text(
                  'App theme',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: Spacing.small),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (value) {
                    context.read<ProfileAppearanceCubit>().setThemeMode(
                      value.first,
                    );
                  },
                ),
                const SizedBox(height: Spacing.mediumLarge),
                Text(
                  'Reader theme',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: Spacing.small),
                Wrap(
                  spacing: Spacing.small,
                  runSpacing: Spacing.small,
                  children: ReaderThemePreset.values.map((preset) {
                    return ChoiceChip(
                      label: Text(preset.label),
                      selected: preset == readerTheme,
                      onSelected: (_) {
                        context.read<ProfileAppearanceCubit>().setReaderTheme(
                          preset.id,
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: Spacing.mediumLarge),
                Text(
                  'Reader font',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: Spacing.small),
                Wrap(
                  spacing: Spacing.small,
                  runSpacing: Spacing.small,
                  children: ReaderFontPreset.values.map((preset) {
                    return ChoiceChip(
                      label: Text(preset.label),
                      selected: preset == readerFont,
                      onSelected: (_) {
                        context.read<ProfileAppearanceCubit>().setReaderFont(
                          preset.id,
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: Spacing.mediumLarge),
                _SliderRow(
                  label: 'Text size',
                  valueLabel:
                      '${(state.readerAppearance.textScale * 100).round()}%',
                  value: state.readerAppearance.textScale,
                  min: 0.85,
                  max: 1.45,
                  onChanged: (value) {
                    context.read<ProfileAppearanceCubit>().previewTextScale(
                      value,
                    );
                  },
                  onChangeEnd: (value) {
                    context.read<ProfileAppearanceCubit>().commitTextScale(
                      value,
                    );
                  },
                ),
                const SizedBox(height: Spacing.medium),
                _SliderRow(
                  label: 'Line height',
                  valueLabel: state.readerAppearance.lineHeight.toStringAsFixed(
                    2,
                  ),
                  value: state.readerAppearance.lineHeight,
                  min: 1.2,
                  max: 2.0,
                  onChanged: (value) {
                    context.read<ProfileAppearanceCubit>().previewLineHeight(
                      value,
                    );
                  },
                  onChangeEnd: (value) {
                    context.read<ProfileAppearanceCubit>().commitLineHeight(
                      value,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReaderPreviewCard extends StatelessWidget {
  const _ReaderPreviewCard({
    required this.theme,
    required this.font,
    required this.textScale,
    required this.lineHeight,
  });

  final ReaderThemeData theme;
  final ReaderFontPreset font;
  final double textScale;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.mediumLarge),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reader preview',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: theme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: Spacing.small),
          Text(
            'The quiet page makes long-form reading feel steady and focused.',
            style: base.copyWith(
              fontFamily: font.fontFamily,
              fontSize: base.fontSize! * textScale,
              height: lineHeight,
              color: theme.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
