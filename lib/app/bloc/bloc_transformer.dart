// Default per-handler ordering, installed in starter.dart via Bloc.transformer.

import 'package:flutter_bloc/flutter_bloc.dart';

/// Serializes events within one `on<E>` registration only. Different event
/// types still overlap: related mutations need a shared event bucket, while
/// independent snapshot loads need freshness guards.
class SequentialBlocTransformer<Event> {
  Stream<Event> transform(Stream<Event> stream, EventMapper<Event> mapper) =>
      stream.asyncExpand(mapper);
}
