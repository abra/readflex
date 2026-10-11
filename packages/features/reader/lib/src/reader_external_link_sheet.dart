import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_external_link_choice.dart';
import 'reader_external_link_destination.dart';

/// Asks before a link leaves the reader. Resolves to the reader's choice, or
/// null when the sheet is dismissed.
Future<ReaderExternalLinkChoice?> showReaderExternalLinkSheet(
  BuildContext context, {
  required ReaderExternalLinkDestination destination,
}) => showAppBottomSheet<ReaderExternalLinkChoice>(
  context,
  builder: (_) => ReaderExternalLinkSheet(destination: destination),
);

/// The link's real destination with Copy and Open.
class ReaderExternalLinkSheet extends StatelessWidget {
  const ReaderExternalLinkSheet({required this.destination, super.key});

  final ReaderExternalLinkDestination destination;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    return ActionBottomSheetLayout(
      title: l10n.readerExternalLinkTitle,
      closeLabel: l10n.commonClose,
      onClose: navigator.pop,
      constrainBody: true,
      footer: AppSheetActions(
        primaryLabel: l10n.readerExternalLinkOpen,
        onPrimary: () => navigator.pop(ReaderExternalLinkChoice.open),
        secondaryLabel: l10n.readerExternalLinkCopy,
        onSecondary: () => navigator.pop(ReaderExternalLinkChoice.copy),
      ),
      child: SingleChildScrollView(
        child: _ReaderExternalLinkAddress(destination: destination),
      ),
    );
  }
}

/// The target first, never shortened, then the whole address in at most
/// three lines; Copy carries all of it. Addresses read left to right in every
/// interface.
class _ReaderExternalLinkAddress extends StatelessWidget {
  const _ReaderExternalLinkAddress({required this.destination});

  final ReaderExternalLinkDestination destination;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          destination.target,
          key: const ValueKey('reader-external-link-target'),
          style: context.text.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          destination.address,
          key: const ValueKey('reader-external-link-address'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
