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

/// Profile tab root screen (route `/profile`).
///
/// Shows account header, reading stats, appearance/reading/general/about
/// settings groups, and a sign-out button. Owns [ProfileCubit] (account
/// data) and [ProfileAppearanceCubit] (theme + reader preferences) for
/// its subtree. Navigation callbacks for sign-in, paywall, and the
/// design-system screen are injected by the composition root.
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
              buildWhen: (prev, curr) =>
                  prev.authStatus != curr.authStatus ||
                  prev.email != curr.email ||
                  prev.subscriptionStatus != curr.subscriptionStatus,
              builder: (context, state) => _ProfileHeader(
                state: state,
                appColors: appColors,
                onSignInPressed: widget.onSignInPressed,
              ),
            ),
          ),
          // ─── Scrollable Content ───
          Expanded(
            child: ScrollEdgeFadeStack(
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
                  SectionLabel(label: 'APPEARANCE'),
                  const SizedBox(height: AppSpacing.md),
                  BlocSelector<
                    ProfileAppearanceCubit,
                    ProfileAppearanceState,
                    ThemeMode
                  >(
                    selector: (state) => state.themeMode,
                    builder: (context, themeMode) => _ThemeRow(
                      themeMode: themeMode,
                      onChanged: (mode) {
                        context.read<ProfileAppearanceCubit>().setThemeMode(
                          mode,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ─── Reading ───
                  SectionLabel(label: 'READING'),
                  const SizedBox(height: AppSpacing.md),
                  SettingsGroup(
                    children: [
                      // Font label subscribes to the appearance cubit so
                      // it tracks picks made inside the bottom sheet —
                      // earlier we read `cubit.state` synchronously here
                      // (no subscribe), which left the label stale until
                      // an unrelated rebuild forced a refresh.
                      BlocSelector<
                        ProfileAppearanceCubit,
                        ProfileAppearanceState,
                        String
                      >(
                        selector: (s) => s.readerAppearance.fontId,
                        builder: (context, fontId) => SettingsRow(
                          icon: AppIcons.textFields,
                          label: 'Font & Text Size',
                          detail: ReaderFontPreset.fromId(fontId).label,
                          onTap: () => _showFontSheet(context),
                        ),
                      ),
                      SettingsRow(
                        icon: AppIcons.language,
                        label: 'Translation Language',
                        detail: 'English',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ─── General ───
                  SectionLabel(label: 'GENERAL'),
                  const SizedBox(height: AppSpacing.md),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: AppIcons.cloud,
                        label: 'Sync & Backup',
                        detail: 'Off',
                      ),
                      SettingsRow(
                        icon: AppIcons.download,
                        label: 'Offline Downloads',
                      ),
                      SettingsRow(
                        icon: AppIcons.notifications,
                        label: 'Notifications',
                        detail: 'On',
                      ),
                      SettingsRow(
                        icon: AppIcons.shield,
                        label: 'Privacy',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ─── About ───
                  SectionLabel(label: 'ABOUT'),
                  const SizedBox(height: AppSpacing.md),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: AppIcons.info,
                        label: 'Version',
                        detail: widget.appVersion,
                      ),
                      SettingsRow(
                        icon: AppIcons.terms,
                        label: 'Terms & Licenses',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ─── Dev ───
                  SectionLabel(label: 'DEVELOPER'),
                  const SizedBox(height: AppSpacing.md),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        icon: AppIcons.designSystem,
                        label: 'Design System',
                        onTap: widget.onDesignSystemPressed,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ─── Sign out ───
                  BlocSelector<ProfileCubit, ProfileState, bool>(
                    selector: (state) => state.isAuthenticated,
                    builder: (context, isAuthenticated) {
                      if (!isAuthenticated) {
                        return const SizedBox.shrink();
                      }
                      return BlocSelector<ProfileCubit, ProfileState, bool>(
                        selector: (state) => state.isLoading,
                        builder: (context, isLoading) {
                          return Center(
                            child: TextButton.icon(
                              onPressed: isLoading
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
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
                    AppBadge(
                      label: 'PRO',
                      foreground: appColors.proBadgeForeground,
                      background: appColors.proBadge.withValues(alpha: 0.15),
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
        Expanded(
          child: StatCard(value: '0', label: 'Books'),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatCard(value: '0h', label: 'Read time'),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatCard(value: '0', label: 'Streak'),
        ),
      ],
    );
  }
}
