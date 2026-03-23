import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum ImportFlowResult { bookImported, articleImported }

/// Shows the import bottom sheet.
///
/// Two options: import book (file picker) or import article (URL).
/// [onImportBook] and [onImportArticle] must return `true` only when content
/// was actually added. This keeps the flow reusable and lets the caller own
/// the real import side effects, including current stub implementations.
Future<ImportFlowResult?> showImportFlowSheet(
  BuildContext context, {
  required AsyncValueGetter<bool> onImportBook,
  required Future<bool> Function(String url) onImportArticle,
}) {
  return showModalBottomSheet<ImportFlowResult>(
    context: context,
    isScrollControlled: true,
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
  final Future<bool> Function(String url) onImportArticle;

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
                const SizedBox(height: Spacing.medium),
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

  final Future<bool> Function(String url) onImportArticle;
  final VoidCallback onImported;

  @override
  State<_ArticleUrlInput> createState() => _ArticleUrlInputState();
}

class _ArticleUrlInputState extends State<_ArticleUrlInput> {
  final _controller = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
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
          const SizedBox(height: Spacing.medium),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const ButtonLoadingIndicator()
                : const Text('Import'),
          ),
          const SizedBox(height: Spacing.large),
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

    try {
      final imported = await widget.onImportArticle(url);
      if (!mounted) return;

      if (imported) {
        widget.onImported();
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to import article';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to import article';
      });
    }
  }
}
