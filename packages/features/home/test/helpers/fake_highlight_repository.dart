import 'package:highlight_repository/highlight_repository.dart';
import 'package:shared/shared.dart';

class FakeHighlightRepository extends HighlightRepository {
  List<Highlight> highlights = [];
  bool shouldThrow = false;

  @override
  Future<List<Highlight>> getHighlights() async {
    if (shouldThrow) throw StorageException(cause: 'fake');
    return highlights;
  }
}
