import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

import 'article_import_outcome.dart';
import 'import_flow_result.dart';

/// Shows the import bottom sheet.
///
/// Currently uses a callback-based API with local `setState` because the
/// flow is simple (pick action → execute → done/error). No Cubit needed yet.
///
/// When the sheet evolves into a multi-step flow (animated screen
/// transitions, progress bar, loading/success/error states within a single
/// sheet), introduce an `ImportFlowCubit` to manage step transitions and
/// intermediate UI states. The callbacks will remain — the Cubit will call
/// them and translate results into state changes for the UI.
///
/// [onImportBook] — called when the user taps "Import book file".
/// Should open a file picker, import the book, and return `true` on success.
///
/// [onImportArticle] — called with the URL when the user submits an
/// article link. Returns an [ArticleImportOutcome] so the sheet can show
/// reason-specific error messages.
Future<ImportFlowResult?> showImportFlowSheet(
  BuildContext context, {
  required Future<bool> Function() onImportBook,
  required Future<ArticleImportOutcome> Function(String url) onImportArticle,
}) {
  return showAppBottomSheet<ImportFlowResult>(
    context,
    builder: (_) => _ImportFlowSheet(
      onImportBook: onImportBook,
      onImportArticle: onImportArticle,
    ),
  );
}

class _ImportFlowSheet extends StatefulWidget {
  const _ImportFlowSheet({
    required this.onImportBook,
    required this.onImportArticle,
  });

  final Future<bool> Function() onImportBook;
  final Future<ArticleImportOutcome> Function(String url) onImportArticle;

  @override
  State<_ImportFlowSheet> createState() => _ImportFlowSheetState();
}

class _ImportFlowSheetState extends State<_ImportFlowSheet> {
  bool _showUrlInput = false;
  bool _isImportingBook = false;

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout(
      title: 'Add to Library',
      onClose: () => Navigator.of(context).pop(),
      child: !_showUrlInput
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.uploadFile),
                  title: const Text('Import book file'),
                  subtitle: const Text('EPUB, PDF, FB2, MOBI'),
                  enabled: !_isImportingBook,
                  onTap: _isImportingBook ? null : _handleBookImport,
                ),
                ListTile(
                  leading: const Icon(AppIcons.link),
                  title: const Text('Add article by URL'),
                  subtitle: const Text('Paste a web article link'),
                  onTap: () => setState(() => _showUrlInput = true),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            )
          : _ArticleUrlInput(
              onImportArticle: widget.onImportArticle,
              onImported: () {
                Navigator.of(context).pop(ImportFlowResult.articleImported);
              },
            ),
    );
  }

  Future<void> _handleBookImport() async {
    setState(() => _isImportingBook = true);

    final imported = await widget.onImportBook();
    if (!mounted) return;

    setState(() => _isImportingBook = false);

    if (imported) {
      Navigator.of(context).pop(ImportFlowResult.bookImported);
    }
  }
}

class _ArticleUrlInput extends StatefulWidget {
  const _ArticleUrlInput({
    required this.onImportArticle,
    required this.onImported,
  });

  final Future<ArticleImportOutcome> Function(String url) onImportArticle;
  final VoidCallback onImported;

  @override
  State<_ArticleUrlInput> createState() => _ArticleUrlInputState();
}

class _ArticleUrlInputState extends State<_ArticleUrlInput> {
  final _controller = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  static String _messageFor(ArticleImportFailureReason reason) {
    return switch (reason) {
      ArticleImportFailureReason.invalidUrl =>
        "That doesn't look like a valid URL",
      ArticleImportFailureReason.network =>
        'Couldn\'t reach the site — check your connection',
      ArticleImportFailureReason.httpError =>
        'The site returned an error. Try a different link.',
      ArticleImportFailureReason.noReadableContent =>
        'This page doesn\'t have a readable article',
      ArticleImportFailureReason.storage =>
        'Couldn\'t save the article to your device',
      ArticleImportFailureReason.unknown =>
        'Something went wrong while importing',
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'https://...',
              labelText: 'Article URL',
              errorText: _errorMessage,
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const ButtonLoadingIndicator()
                : const Text('Import'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please enter a URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final outcome = await widget.onImportArticle(url);

    if (!mounted) return;

    switch (outcome) {
      case ArticleImportSuccess():
        widget.onImported();
      case ArticleImportFailure(:final reason):
        setState(() {
          _isLoading = false;
          _errorMessage = _messageFor(reason);
        });
    }
  }
}
