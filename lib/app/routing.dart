import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nota/app/config/supported_locales.dart';
import 'package:nota/app/dependency_container.dart';
import 'package:note_details/note_details.dart';
import 'package:note_list/note_list.dart';
import 'package:preferences_menu/preferences_menu.dart';
import 'package:shared/shared.dart';

abstract final class AppRoutes {
  static const notes = '/notes';
  static const newNote = '/notes/new';

  static String noteEditor(String id) => '/notes/$id';
}

GoRouter buildRouter({required DependenciesContainer dependencies}) {
  dependencies.logger.debug('buildRouter: GoRouter created');

  return GoRouter(
    debugLogDiagnostics: dependencies.config.isDev,
    initialLocation: AppRoutes.notes,
    routes: [
      GoRoute(
        path: AppRoutes.notes,
        builder: (context, state) => NoteListScreen(
          noteRepository: dependencies.noteRepository,
          preferencesService: dependencies.preferencesService,
          imageFiles: dependencies.imageFiles,
          onAddPressed: () => context.push<Note?>(AppRoutes.newNote),
          onNotePressed: (note) => context.push<Note?>(
            AppRoutes.noteEditor(note.id),
          ),
          onSettingsPressed: (ctx) => showModalBottomSheet<void>(
            context: ctx,
            isScrollControlled: true,
            builder: (_) => PreferencesMenu(
              service: dependencies.preferencesService,
              supportedLanguages: SupportedLocales.languages,
            ),
          ),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => NoteDetailsScreen(
              noteRepository: dependencies.noteRepository,
              imageFiles: dependencies.imageFiles,
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => NoteDetailsScreen(
              noteRepository: dependencies.noteRepository,
              imageFiles: dependencies.imageFiles,
              noteId: state.pathParameters['id'],
            ),
          ),
        ],
      ),
    ],
  );
}
