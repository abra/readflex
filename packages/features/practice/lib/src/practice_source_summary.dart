import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';

/// What one source contributes to practice.
class PracticeSourceSummary extends Equatable {
  const PracticeSourceSummary({
    required this.source,
    required this.words,
    required this.highlights,
    required this.due,
  });

  final LibrarySource source;
  final int words;
  final int highlights;
  final int due;

  @override
  List<Object?> get props => [source, words, highlights, due];
}
