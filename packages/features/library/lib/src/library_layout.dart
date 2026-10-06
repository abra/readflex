import 'package:component_library/component_library.dart';

/// Bottom padding for Library grid/list content: clears the 56dp FAB, its
/// lift above the safe area and a content gap so the last row's progress
/// bar is never hidden under the button.
const double kLibraryContentBottomPadding =
    56 + AppSpacing.sm + AppSpacing.lg + AppSpacing.lg;
