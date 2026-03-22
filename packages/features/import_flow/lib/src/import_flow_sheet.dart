import 'package:article_parser/article_parser.dart';
import 'package:article_repository/article_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'import_article_cubit.dart';

/// Shows the import bottom sheet.
///
/// Two options: import book (file picker) or import article (URL).
/// [onBookFilePicked] is called when the user chooses to pick a book file —
/// the actual file picker is handled by the caller (composition root).
void showImportFlowSheet(
  BuildContext context, {
  required ArticleParser articleParser,
  required ArticleRepository articleRepository,
  required VoidCallback onBookFilePicked,
  required VoidCallback onArticleImported,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ImportFlowSheet(
      articleParser: articleParser,
      articleRepository: articleRepository,
      onBookFilePicked: onBookFilePicked,
      onArticleImported: onArticleImported,
    ),
  );
}

class _ImportFlowSheet extends StatefulWidget {
  const _ImportFlowSheet({
    required this.articleParser,
    required this.articleRepository,
    required this.onBookFilePicked,
    required this.onArticleImported,
  });

  final ArticleParser articleParser;
  final ArticleRepository articleRepository;
  final VoidCallback onBookFilePicked;
  final VoidCallback onArticleImported;

  @override
  State<_ImportFlowSheet> createState() => _ImportFlowSheetState();
}

class _ImportFlowSheetState extends State<_ImportFlowSheet> {
  bool _showUrlInput = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomSheetHeader(
              title: 'Add to Library',
              onClose: () => Navigator.of(context).pop(),
            ),
            if (!_showUrlInput) ...[
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Import book file'),
                subtitle: const Text('EPUB, PDF, FB2, MOBI'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onBookFilePicked();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Add article by URL'),
                subtitle: const Text('Paste a web article link'),
                onTap: () => setState(() => _showUrlInput = true),
              ),
              const SizedBox(height: Spacing.medium),
            ] else
              _ArticleUrlInput(
                articleParser: widget.articleParser,
                articleRepository: widget.articleRepository,
                onImported: () {
                  Navigator.of(context).pop();
                  widget.onArticleImported();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ArticleUrlInput extends StatefulWidget {
  const _ArticleUrlInput({
    required this.articleParser,
    required this.articleRepository,
    required this.onImported,
  });

  final ArticleParser articleParser;
  final ArticleRepository articleRepository;
  final VoidCallback onImported;

  @override
  State<_ArticleUrlInput> createState() => _ArticleUrlInputState();
}

class _ArticleUrlInputState extends State<_ArticleUrlInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ImportArticleCubit(
        articleParser: widget.articleParser,
        articleRepository: widget.articleRepository,
      ),
      child: BlocConsumer<ImportArticleCubit, ImportArticleState>(
        listener: (context, state) {
          if (state.status == ImportArticleStatus.success) {
            widget.onImported();
          }
        },
        builder: (context, state) {
          final isLoading = state.status == ImportArticleStatus.loading;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    labelText: 'Article URL',
                    errorText: state.status == ImportArticleStatus.failure
                        ? state.errorMessage
                        : null,
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _submit(context),
                ),
                const SizedBox(height: Spacing.medium),
                FilledButton(
                  onPressed: isLoading ? null : () => _submit(context),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Import'),
                ),
                const SizedBox(height: Spacing.large),
              ],
            ),
          );
        },
      ),
    );
  }

  void _submit(BuildContext context) {
    context.read<ImportArticleCubit>().importUrl(_controller.text);
  }
}
