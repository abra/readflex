import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:monitoring/monitoring.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Deletes [pickedFile] after its import when it is the copy the platform
/// picker made for this app.
///
/// file_picker copies an Android pick into `<cache>/file_picker/<timestamp>/`
/// and moves an iOS pick into the app's `tmp/`; the library keeps its own
/// copy. Files outside the app's temporary and cache directories, such as
/// desktop originals, are never touched. Failures are logged, never thrown.
Future<void> deletePickedBookFile(File pickedFile, {required Logger logger}) =>
    deletePickedBookFileWithin(
      pickedFile,
      temporaryDirectories: () async => [
        // iOS `tmp/` (TMPDIR); Android code cache.
        Directory.systemTemp,
        // Android cache; iOS `Library/Caches`.
        await getTemporaryDirectory(),
      ],
      logger: logger,
    );

@visibleForTesting
Future<void> deletePickedBookFileWithin(
  File pickedFile, {
  required Future<List<Directory>> Function() temporaryDirectories,
  required Logger logger,
}) async {
  // Desktop pickers return the user's original file, never a copy.
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  try {
    if (!await pickedFile.exists()) return;
    // Both sides resolved: iOS reports one folder as /var and /private/var,
    // and a link must never lead the delete out of the temporary directory.
    final path = await pickedFile.resolveSymbolicLinks();
    for (final directory in await temporaryDirectories()) {
      if (!await directory.exists()) continue;
      final root = await directory.resolveSymbolicLinks();
      if (!p.isWithin(root, path)) continue;

      await File(path).delete();
      final pickFolder = Directory(p.dirname(path));
      if (p.isWithin(root, pickFolder.path) &&
          p.basename(pickFolder.parent.path) == 'file_picker' &&
          await pickFolder.list().isEmpty) {
        await pickFolder.delete();
      }
      return;
    }
  } catch (error, stackTrace) {
    logger.warn(
      'Picked book copy cleanup failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
