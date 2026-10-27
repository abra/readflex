part of 'library_grid_sliver.dart';

/// Covers in [libraryGridColumnCount] columns of the width the grid gets in
/// layout. Only that width picks the columns, so the keyboard resizing the
/// body's height relayouts the grid without rebuilding its tiles.
class _LibraryGridDelegate extends SliverGridDelegate {
  const _LibraryGridDelegate({required this.textScale});

  final double textScale;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    // The sliver sits inside the 16dp gutters the column rule counts.
    final columns = libraryGridColumnCount(
      constraints.crossAxisExtent + AppSpacing.lg * 2,
      textScale: textScale,
    );
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 2 / 3,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(_LibraryGridDelegate oldDelegate) =>
      oldDelegate.textScale != textScale;
}
