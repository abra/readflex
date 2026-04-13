import 'package:auth_service/auth_service.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:subscription_service/subscription_service.dart';

import 'profile_appearance_cubit.dart';
import 'profile_cubit.dart';

part 'widgets/font_sheet.dart';
part 'widgets/settings_widgets.dart';

/// Profile tab: settings, auth status, premium.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.authService,
    required this.subscriptionService,
    required this.preferencesService,
    required this.onSignInPressed,
    required this.onDesignSystemPressed,
    required this.onPremiumPressed,
    this.appVersion = '1.0.0',
    super.key,
  });

  final AuthService authService;
  final SubscriptionService subscriptionService;
  final PreferencesService preferencesService;
  final VoidCallback onSignInPressed;
  final VoidCallback onDesignSystemPressed;
  final VoidCallback onPremiumPressed;
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('ProfileScreen');

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
      child: _ProfileView(
        onSignInPressed: onSignInPressed,
        onDesignSystemPressed: onDesignSystemPressed,
        onPremiumPressed: onPremiumPressed,
        appVersion: appVersion,
      ),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView({
    required this.onSignInPressed,
    required this.onDesignSystemPressed,
    required this.onPremiumPressed,
    required this.appVersion,
  });

  final VoidCallback onSignInPressed;
  final VoidCallback onDesignSystemPressed;
  final VoidCallback onPremiumPressed;
  final String appVersion;

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  bool _showHeaderShadow = false;
  bool _showFooterShadow = true;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final appColors = context.appColors;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ─── Fixed Header ───
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            child: BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) => _ProfileHeader(
                state: state,
                appColors: appColors,
                onSignInPressed: widget.onSignInPressed,
              ),
            ),
          ),
          // ─── Scrollable Content ───
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis != Axis.vertical) {
                      return false;
                    }
                    final showTop = notification.metrics.extentBefore > 0;
                    final showBottom = notification.metrics.extentAfter > 0;
                    if ((showTop != _showHeaderShadow ||
                            showBottom != _showFooterShadow) &&
                        mounted) {
                      setState(() {
                        _showHeaderShadow = showTop;
                        _showFooterShadow = showBottom;
                      });
                    }
                    return false;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      // ─── Stats ───
                      const _StatsRow(),
                      const SizedBox(height: AppSpacing.lg),

                      // ─── Appearance ───
                      _SectionLabel(label: 'APPEARANCE'),
                      const SizedBox(height: AppSpacing.md),
                      BlocBuilder<
                        ProfileAppearanceCubit,
                        ProfileAppearanceState
                      >(
                        builder: (context, state) => _ThemeRow(
                          themeMode: state.themeMode,
                          onChanged: (mode) {
                            context.read<ProfileAppearanceCubit>().setThemeMode(
                              mode,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ─── Reading ───
                      _SectionLabel(label: 'READING'),
                      const SizedBox(height: AppSpacing.md),
                      _SettingsGroup(
                        children: [
                          _SettingsRow(
                            icon: AppIcons.textFields,
                            label: 'Font & Text Size',
                            detail: _currentFontLabel(context),
                            onTap: () => _showFontSheet(context),
                          ),
                          _SettingsRow(
                            icon: AppIcons.language,
                            label: 'Translation Language',
                            detail: 'English',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ─── General ───
                      _SectionLabel(label: 'GENERAL'),
                      const SizedBox(height: AppSpacing.md),
                      _SettingsGroup(
                        children: [
                          _SettingsRow(
                            icon: AppIcons.cloud,
                            label: 'Sync & Backup',
                            detail: 'Off',
                          ),
                          _SettingsRow(
                            icon: AppIcons.download,
                            label: 'Offline Downloads',
                          ),
                          _SettingsRow(
                            icon: AppIcons.notifications,
                            label: 'Notifications',
                            detail: 'On',
                          ),
                          _SettingsRow(
                            icon: AppIcons.shield,
                            label: 'Privacy',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ─── About ───
                      _SectionLabel(label: 'ABOUT'),
                      const SizedBox(height: AppSpacing.md),
                      _SettingsGroup(
                        children: [
                          _SettingsRow(
                            icon: AppIcons.info,
                            label: 'Version',
                            detail: widget.appVersion,
                          ),
                          _SettingsRow(
                            icon: AppIcons.terms,
                            label: 'Terms & Licenses',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ─── Dev ───
                      _SectionLabel(label: 'DEVELOPER'),
                      const SizedBox(height: AppSpacing.md),
                      _SettingsGroup(
                        children: [
                          _SettingsRow(
                            icon: AppIcons.designSystem,
                            label: 'Design System',
                            onTap: widget.onDesignSystemPressed,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ─── Sign out ───
                      BlocBuilder<ProfileCubit, ProfileState>(
                        builder: (context, state) {
                          if (!state.isAuthenticated) {
                            return const SizedBox.shrink();
                          }
                          return Center(
                            child: TextButton.icon(
                              onPressed: state.isLoading
                                  ? null
                                  : () =>
                                        context.read<ProfileCubit>().signOut(),
                              icon: Icon(
                                AppIcons.logOut,
                                size: AppIconSize.sm,
                                color: cs.error,
                              ),
                              label: Text(
                                'Sign Out',
                                style: context.text.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: cs.error,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ScrollEdgeFade(visible: _showHeaderShadow),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ScrollEdgeFade(
                    visible: _showFooterShadow,
                    edge: ScrollFadeEdge.bottom,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _currentFontLabel(BuildContext context) {
    final state = context.read<ProfileAppearanceCubit>().state;
    final font = ReaderFontPreset.fromId(state.readerAppearance.fontId);
    return font.label;
  }

  void _showFontSheet(BuildContext context) {
    final cubit = context.read<ProfileAppearanceCubit>();

    showAppBottomSheet<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const _FontSheet(),
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.state,
    required this.appColors,
    required this.onSignInPressed,
  });

  final ProfileState state;
  final AppColorsExt appColors;
  final VoidCallback onSignInPressed;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.secondary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              state.isAuthenticated
                  ? (state.email?[0].toUpperCase() ?? 'U')
                  : 'G',
              style: context.text.titleMedium.copyWith(
                fontFamily: AppTypography.fontFamilySerif,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      state.isAuthenticated ? (state.email ?? 'User') : 'Guest',
                      style: context.text.titleMedium.copyWith(
                        fontFamily: AppTypography.fontFamilySerif,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (state.isPremium) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: appColors.proBadge.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        'PRO',
                        style: context.text.labelSmall.copyWith(
                          color: appColors.proBadgeForeground,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                state.isAuthenticated
                    ? 'Tap to manage account'
                    : 'Sign in to sync your data',
                style: context.text.labelSmall.copyWith(
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        Icon(
          AppIcons.chevronRight,
          size: AppIconSize.sm,
          color: cs.onSurface.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}

// ─── Stats ─────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _StatTile(value: '0', label: 'Books'),
        SizedBox(width: AppSpacing.sm),
        _StatTile(value: '0h', label: 'Read time'),
        SizedBox(width: AppSpacing.sm),
        _StatTile(value: '0', label: 'Streak'),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outline.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: context.text.titleMedium.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: context.text.labelSmall.copyWith(
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
