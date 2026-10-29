import 'package:domain_models/domain_models.dart';

/// The rows removed by one deletion, retained only while Undo is available.
class HighlightDeletion {
  const HighlightDeletion({required this.highlight, this.reviewItem});

  final Highlight highlight;
  final ReviewItem? reviewItem;
}
