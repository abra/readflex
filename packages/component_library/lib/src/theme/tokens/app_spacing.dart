import 'primitive_spacing.dart';

/// Semantic spacing tokens — maps [PrimitiveSpacing] to UI roles.
///
/// Used in theme assembly and as fallback defaults.
/// In UI code prefer `context.dimens.spacingX` via [AppDimensExt].
abstract final class AppSpacing {
  static const double xxs = PrimitiveSpacing.s2;
  static const double xs = PrimitiveSpacing.s4;
  static const double sm = PrimitiveSpacing.s8;
  static const double md = PrimitiveSpacing.s12;
  static const double lg = PrimitiveSpacing.s16;
  static const double xl = PrimitiveSpacing.s20;
  static const double xxl = PrimitiveSpacing.s24;
  static const double xxxl = PrimitiveSpacing.s48;
  static const double xxxxl = PrimitiveSpacing.s64;
}
