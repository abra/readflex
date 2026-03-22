import 'package:auth_service/auth_service.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:subscription_service/subscription_service.dart';

import 'profile_cubit.dart';

/// Profile tab: settings, auth status, premium.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.authService,
    required this.subscriptionService,
    required this.onSignInPressed,
    required this.onPremiumPressed,
    super.key,
  });

  final AuthService authService;
  final SubscriptionService subscriptionService;
  final VoidCallback onSignInPressed;
  final VoidCallback onPremiumPressed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(
        authService: authService,
        subscriptionService: subscriptionService,
      )..load(),
      child: ProfileView(
        onSignInPressed: onSignInPressed,
        onPremiumPressed: onPremiumPressed,
      ),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({
    required this.onSignInPressed,
    required this.onPremiumPressed,
    super.key,
  });

  final VoidCallback onSignInPressed;
  final VoidCallback onPremiumPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(Spacing.large),
            children: [
              // Auth section
              Card(
                child: ListTile(
                  leading: Icon(
                    state.isAuthenticated ? Icons.person : Icons.person_outline,
                  ),
                  title: Text(
                    state.isAuthenticated
                        ? state.email ?? 'Signed in'
                        : 'Not signed in',
                  ),
                  subtitle: state.isAuthenticated
                      ? null
                      : const Text('Sign in to sync your data'),
                  trailing: state.isAuthenticated
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
              ),
              const SizedBox(height: Spacing.medium),

              // Subscription section
              Card(
                child: ListTile(
                  leading: Icon(
                    state.isPremium ? Icons.star : Icons.star_border,
                  ),
                  title: Text(state.isPremium ? 'Premium' : 'Free plan'),
                  subtitle: state.isPremium
                      ? null
                      : const Text('Unlock AI features and more'),
                  trailing: state.isPremium
                      ? null
                      : FilledButton.tonal(
                          onPressed: onPremiumPressed,
                          child: const Text('Upgrade'),
                        ),
                ),
              ),
              const SizedBox(height: Spacing.large),

              // App info
              const Divider(),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('About Readflex'),
                subtitle: Text('Version 1.0.0'),
              ),
            ],
          );
        },
      ),
    );
  }
}
