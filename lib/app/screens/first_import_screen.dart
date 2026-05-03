// Full-screen setup screen shown once after onboarding.
//
// Prompts the user to add their first book.
// The actual import flow is orchestrated by the caller.

import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FirstImportScreen extends StatefulWidget {
  const FirstImportScreen({
    required this.onAddPressed,
    required this.onContentAdded,
    required this.onSkipPressed,
    super.key,
  });

  final AsyncValueGetter<bool> onAddPressed;
  final VoidCallback onContentAdded;
  final VoidCallback onSkipPressed;

  @override
  State<FirstImportScreen> createState() => _FirstImportScreenState();
}

class _FirstImportScreenState extends State<FirstImportScreen> {
  bool _isLoading = false;

  Future<void> _handleAddPressed() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final contentAdded = await widget.onAddPressed();
      if (!mounted) return;
      if (contentAdded) {
        widget.onContentAdded();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('FirstImportScreen');

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AppIcons.book,
                size: 80,
                color: context.colors.primary,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Add your first book',
                style: context.text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Import a book file to get started.',
                style: context.text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: _isLoading ? null : _handleAddPressed,
                icon: _isLoading
                    ? const ButtonLoadingIndicator(size: AppIconSize.sm)
                    : const Icon(AppIcons.add),
                label: Text(_isLoading ? 'Opening...' : 'Add'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _isLoading ? null : widget.onSkipPressed,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
