import 'dart:io';

import 'package:flutter/material.dart';

/// Resolves an optional local cover path into an image provider.
///
/// Feature widgets should not duplicate the `FileImage(File(path))` ceremony;
/// keeping it here makes cover loading behavior consistent across surfaces.
ImageProvider? appSourceCoverImageFromPath(String? path) {
  if (path == null || path.isEmpty) return null;
  return FileImage(File(path));
}
