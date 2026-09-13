import 'package:domain_models/domain_models.dart';

List<Book> libraryWorkload(int count) => List.generate(
  count,
  (index) => Book(
    id: 'workload-$index',
    title: 'Book $index',
    author: 'Author ${index % 100}',
    filePath: 'fixture.fb2',
    format: index % 7 == 0 ? BookFormat.cbz : BookFormat.fb2,
    addedAt: DateTime.utc(2026).add(Duration(minutes: index)),
    readingProgress: index.isEven ? 0 : 0.5,
  ),
  growable: false,
);
