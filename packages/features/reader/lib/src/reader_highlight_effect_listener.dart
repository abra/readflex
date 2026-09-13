import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';

import 'reader_bloc.dart';

/// Reports committed mutations without rebuilding the reader/WebView subtree.
class ReaderHighlightEffectListener extends StatelessWidget {
  const ReaderHighlightEffectListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocListener<ReaderBloc, ReaderState>(
    listenWhen: (previous, current) =>
        previous.highlightEffect != current.highlightEffect,
    listener: (context, state) {
      final effect = state.highlightEffect;
      if (effect == null) return;
      final l10n = context.l10n;
      if (!effect.success) {
        showToast(
          context,
          type: NotificationType.error,
          message: effect.operation == ReaderHighlightOperation.delete
              ? l10n.libraryDeleteFailed(1)
              : l10n.readerHighlightSaveFailed,
        );
        return;
      }
      final message = switch (effect.operation) {
        ReaderHighlightOperation.delete => l10n.readerHighlightRemoved,
        ReaderHighlightOperation.note => l10n.readerCommentUpdated,
        ReaderHighlightOperation.color => null,
      };
      if (message != null) {
        showToast(context, type: NotificationType.success, message: message);
      }
    },
    child: child,
  );
}
