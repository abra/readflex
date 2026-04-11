import 'dart:developer' as developer;

import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum ImportFlowResult { bookImported, articleImported }

/// Outcome of an article import attempt. Callers return this from the
/// [showImportFlowSheet] `onImportArticle` callback so the sheet can show
/// a reason-specific error message instead of a generic "failed".
sealed class ArticleImportOutcome {
  const ArticleImportOutcome();

  /// Successful import — the sheet will close.
  const factory ArticleImportOutcome.success() = ArticleImportSuccess;

  /// Import failed for [reason]. The sheet renders a message keyed off the
  /// reason and stays open so the user can retry or edit the URL.
  const factory ArticleImportOutcome.failure(
    ArticleImportFailureReason reason,
  ) = ArticleImportFailure;
}

final class ArticleImportSuccess extends ArticleImportOutcome {
  const ArticleImportSuccess();
}

final class ArticleImportFailure extends ArticleImportOutcome {
  const ArticleImportFailure(this.reason);

  final ArticleImportFailureReason reason;
}

/// User-facing categories of article import failure.
///
/// Intentionally coarse: the sheet only needs enough to show a helpful
/// one-line message. Exact technical details stay in logs.
enum ArticleImportFailureReason {
  /// URL didn't parse.
  invalidUrl,

  /// Device offline / DNS / timeout — anything network-shaped.
  network,

  /// Site responded but with an error status.
  httpError,

  /// Fetched successfully but readability couldn't extract an article.
  noReadableContent,

  /// Import reached the repository but saving to disk or DB failed.
  storage,

  /// Catch-all for unexpected failures.
  unknown,
}

/// Shows the import bottom sheet.
///
/// Two options: import book (file picker) or import article (URL).
/// [onImportBook] must return `true` only when content was actually added.
/// [onImportArticle] returns an [ArticleImportOutcome] so the sheet can
/// translate infrastructure-level failures (parser, storage) into a
/// human-readable message.
Future<ImportFlowResult?> showImportFlowSheet(
  BuildContext context, {
  required AsyncValueGetter<bool> onImportBook,
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

  final AsyncValueGetter<bool> onImportBook;
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
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Import book file'),
                  subtitle: const Text('EPUB, PDF, FB2, MOBI'),
                  enabled: !_isImportingBook,
                  onTap: _isImportingBook ? null : _handleBookImport,
                ),
                ListTile(
                  leading: const Icon(Icons.link),
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

    ArticleImportOutcome outcome;
    try {
      outcome = await widget.onImportArticle(url);
    } catch (e, st) {
      // Any exception that escapes the callback is a bug in the composition
      // glue (it's supposed to hand us a typed outcome). Log and fall back
      // to the generic 'unknown' bucket so the user still sees something.
      developer.log(
        'Article import threw unexpectedly',
        error: e,
        stackTrace: st,
        name: 'ImportFlowSheet',
      );
      outcome = const ArticleImportOutcome.failure(
        ArticleImportFailureReason.unknown,
      );
    }

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
