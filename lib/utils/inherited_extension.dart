// BuildContext extensions for ergonomic InheritedWidget and InheritedModel access.
//
// inhOf / inhMaybeOf             — typed access to InheritedWidget with a clear
//                                  error message when the widget is not in scope.
// inheritFrom / maybeInheritFrom — typed access to a specific aspect of an
//                                  InheritedModel for selective rebuilds.

import 'package:flutter/widgets.dart';

extension InheritedExtension on BuildContext {
  /// Returns the nearest [T] or null if not found.
  ///
  /// [listen] controls whether this widget subscribes to changes:
  /// - `true`  — rebuilds when [T] changes (use in build methods).
  /// - `false` — one-time read with no rebuild (use in callbacks/handlers).
  T? inhMaybeOf<T extends InheritedWidget>({bool listen = true}) => listen
      ? dependOnInheritedWidgetOfExactType<T>()
      : getInheritedWidgetOfExactType<T>();

  /// Returns the nearest [T], throws [ArgumentError] if not found.
  ///
  /// See [inhMaybeOf] for [listen] semantics.
  T inhOf<T extends InheritedWidget>({bool listen = true}) =>
      inhMaybeOf<T>(listen: listen) ??
      (throw ArgumentError(
        'Out of scope, not found inherited widget a $T of the exact type',
        'out_of_scope',
      ));

  /// Maybe inherit specific aspect from [InheritedModel].
  T? maybeInheritFrom<A extends Object, T extends InheritedModel<A>>({
    A? aspect,
  }) => InheritedModel.inheritFrom<T>(this, aspect: aspect);

  /// Inherit specific aspect from [InheritedModel], throws if not found.
  T inheritFrom<A extends Object, T extends InheritedModel<A>>({A? aspect}) =>
      maybeInheritFrom(aspect: aspect) ??
      (throw ArgumentError(
        'Out of scope, not found inherited model a $T of the exact type',
        'out_of_scope',
      ));
}
