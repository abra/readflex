import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'home_bloc.dart';

/// Entry point for the Home tab.
///
/// Pure composition: creates [HomeBloc] with all repositories, kicks
/// off the initial load, and delegates rendering to [HomeView]. Navigation
/// callbacks (`onBookPressed`, `onPracticePressed`) are wired in the
/// composition root.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.bookRepository,
    required this.highlightRepository,
    required this.fsrsRepository,
    required this.onBookPressed,
    required this.onPracticePressed,
    super.key,
  });

  final BookRepository bookRepository;
  final HighlightRepository highlightRepository;
  final FsrsRepository fsrsRepository;
  final void Function(Book book) onBookPressed;
  final VoidCallback onPracticePressed;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('HomeScreen');

    return BlocProvider(
      create: (_) => HomeBloc(
        bookRepository: bookRepository,
        highlightRepository: highlightRepository,
        fsrsRepository: fsrsRepository,
      )..add(const HomeLoadRequested()),
      child: HomeView(
        onBookPressed: onBookPressed,
        onPracticePressed: onPracticePressed,
      ),
    );
  }
}

/// Stateless body of the Home tab: reads [HomeBloc] state and renders the
/// dashboard (stats row + Continue Reading list). Currently a placeholder
/// while the port is in progress — see commented-out reference layout below.
class HomeView extends StatelessWidget {
  const HomeView({
    required this.onBookPressed,
    required this.onPracticePressed,
    super.key,
  });

  final void Function(Book book) onBookPressed;
  final VoidCallback onPracticePressed;

  @override
  Widget build(BuildContext context) {
    // TODO: implement home dashboard UI.
    return Placeholder();
  }
}

// ignore: unused_element
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state, required this.onPracticePressed});

  final HomeState state;
  final VoidCallback onPracticePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colors;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            icon: AppIcons.library,
            label: 'Sources',
            value: '${state.totalSources}',
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatCard(
            icon: AppIcons.highlight,
            label: 'Highlights',
            value: '${state.totalHighlights}',
            color: colorScheme.secondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatCard(
            icon: AppIcons.practice,
            label: 'Due',
            value: '${state.dueFlashcards}',
            color: state.dueFlashcards > 0
                ? colorScheme.error
                : colorScheme.outline,
            onTap: state.dueFlashcards > 0 ? onPracticePressed : null,
          ),
        ),
      ],
    );
  }
}
