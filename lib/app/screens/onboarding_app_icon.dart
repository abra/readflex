import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

/// The app icon asset shown at the top of onboarding. Its 2.0x and 3.0x
/// variants are resolved by device pixel ratio.
const onboardingAppIconAsset = 'assets/onboarding/app_icon.png';

/// The app's own icon, the one the reader just tapped, so the first screen
/// reads as Readflex greeting them rather than as a promotion.
///
/// Decorative: the heading below names the app, so the image is hidden from
/// screen readers.
class OnboardingAppIcon extends StatelessWidget {
  const OnboardingAppIcon({super.key});

  /// Logical size; the bundled variants match it at 1x, 2x and 3x.
  static const size = 64.0;

  /// The iOS icon mask is about 22% of the side.
  static const cornerRadius = 14.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(cornerRadius);
    return DecoratedBox(
      // A hairline keeps the white icon square defined on the light page.
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          onboardingAppIconAsset,
          width: size,
          height: size,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
