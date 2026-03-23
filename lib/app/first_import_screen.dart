// Full-screen setup screen shown once after onboarding.
//
// Prompts the user to add their first book or article.
// The actual import flow is orchestrated by the caller.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FirstImportScreen extends StatefulWidget {
  const FirstImportScreen({
    required this.onAddPressed,
    required this.onContentAdded,
    super.key,
  });

  final AsyncValueGetter<bool> onAddPressed;
  final VoidCallback onContentAdded;

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
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Add your first book or article',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Import a book file or paste an article link to get started.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isLoading ? null : _handleAddPressed,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isLoading ? 'Opening...' : 'Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
