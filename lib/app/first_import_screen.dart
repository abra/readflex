// Full-screen setup screen shown once after onboarding.
//
// Prompts the user to add their first book or article via the import flow.
// After a successful import the caller navigates to the main app.

import 'package:article_parser/article_parser.dart';
import 'package:article_repository/article_repository.dart';
import 'package:flutter/material.dart';
import 'package:import_flow/import_flow.dart';

class FirstImportScreen extends StatelessWidget {
  const FirstImportScreen({
    required this.articleParser,
    required this.articleRepository,
    required this.onBookFilePicked,
    required this.onContentAdded,
    super.key,
  });

  final ArticleParser articleParser;
  final ArticleRepository articleRepository;
  final VoidCallback onBookFilePicked;
  final VoidCallback onContentAdded;

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
                onPressed: () => showImportFlowSheet(
                  context,
                  articleParser: articleParser,
                  articleRepository: articleRepository,
                  onBookFilePicked: onBookFilePicked,
                  onArticleImported: onContentAdded,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              const SizedBox(height: 12),
              // TODO: remove — temporary stub for testing the flow.
              OutlinedButton(
                onPressed: () async {
                  await articleRepository.addArticle(
                    title: 'Sample Article',
                    url: 'https://example.com/sample',
                    cleanedHtml: '<p>This is a sample article.</p>',
                  );
                  onContentAdded();
                },
                child: const Text('Add sample (dev)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
