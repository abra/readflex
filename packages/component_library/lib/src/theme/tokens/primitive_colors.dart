import 'package:flutter/material.dart';

/// Raw color values without semantic meaning.
///
/// Brand palette derived from the ReadWell design system.
/// **Never use directly in widgets** — go through [AppColorPalette],
/// [ColorScheme], or [AppColorsExt].
abstract final class PrimitiveColors {
  // ── Neutral ────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);

  // ── Light neutral (cool gray) ──────────────────────────────
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF3F0ED);
  static const Color gray200 = Color(0xFFE9EAEC);
  static const Color gray250 = Color(0xFFE3E5E8);
  static const Color gray300 = Color(0xFFE1E2E5);
  static const Color gray350 = Color(0xFFDEE0E3);
  static const Color gray500 = Color(0xFF8B919C);
  static const Color gray600 = Color(0xFF6C727F);
  static const Color gray700 = Color(0xFF434956);
  static const Color gray900 = Color(0xFF21242C);

  // ── Dark neutral (cool dark) ───────────────────────────────
  static const Color darkGray50 = Color(0xFFDEE0E3);
  static const Color darkGray100 = Color(0xFFCDD0D5);
  static const Color darkGray200 = Color(0xFFB2B6BD);
  static const Color darkGray400 = Color(0xFF757C8A);
  static const Color darkGray500 = Color(0xFF636874);
  static const Color darkGray600 = Color(0xFF282C33);
  static const Color darkGray700 = Color(0xFF24272E);
  static const Color darkGray750 = Color(0xFF1E2229);
  static const Color darkGray800 = Color(0xFF1A1D23);
  static const Color darkGray900 = Color(0xFF111318);

  // ── Wine / Primary accent ──────────────────────────────────
  static const Color wine500 = Color(0xFF7A1F2B);
  static const Color wine400 = Color(0xFFD88491);

  // ── Orange / Legacy accent ─────────────────────────────────
  static const Color orange500 = Color(0xFFC46C31);
  static const Color orange400 = Color(0xFFC68153);

  // ── Red / Destructive ──────────────────────────────────────
  static const Color red500 = Color(0xFFD22D2D);
  static const Color red600 = Color(0xFFB23434);

  // ── Warm tints (paper/reading) ─────────────────────────────
  static const Color warmWhite = Color(0xFFF5F3EF);
  static const Color warmText = Color(0xFF282C33);
  static const Color warmTextDark = Color(0xFFCDD0D5);
  static const Color warmSurfaceDark = Color(0xFF1A1D23);

  // ── Purple / AI accent ─────────────────────────────────────
  static const Color purple500 = Color(0xFF7A47D1);
  static const Color purple400 = Color(0xFF9975D7);

  // ── Highlight markers ──────────────────────────────────────
  static const Color highlightYellowLight = Color(0xFFF6E7AC);
  static const Color highlightBlueLight = Color(0xFFC2D9F0);
  static const Color highlightGreenLight = Color(0xFFBCE6D1);
  static const Color highlightPinkLight = Color(0xFFEAB8C9);
  static const Color highlightPurpleLight = Color(0xFFD1BAE8);

  static const Color highlightYellowDark = Color(0xFF63551D);
  static const Color highlightBlueDark = Color(0xFF294056);
  static const Color highlightGreenDark = Color(0xFF284838);
  static const Color highlightPinkDark = Color(0xFF642B3E);
  static const Color highlightPurpleDark = Color(0xFF472B64);

  // ── Status: warning (orange) ───────────────────────────────
  static const Color warningLight = Color(0xFFE66B19);
  static const Color warningFgLight = Color(0xFFB84F0A);
  static const Color warningDark = Color(0xFFDD7C3C);
  static const Color warningFgDark = Color(0xFFED975E);

  // ── Status: info (blue) ────────────────────────────────────
  static const Color infoLight = Color(0xFF23549F);
  static const Color infoFgLight = Color(0xFF103C7F);
  static const Color infoDark = Color(0xFF4784E1);
  static const Color infoFgDark = Color(0xFFB2CFFA);

  // ── Status: success (green) ────────────────────────────────
  static const Color successLight = Color(0xFF29A37A);
  static const Color successFgLight = Color(0xFF17825E);
  static const Color successDark = Color(0xFF39AC86);
  static const Color successFgDark = Color(0xFF5CD6AD);

  // ── Pro badge (golden) ─────────────────────────────────────
  static const Color proBadgeLight = Color(0xFFF2A60D);
  static const Color proBadgeFgLight = Color(0xFFAE7604);
  static const Color proBadgeDark = Color(0xFFE8AB30);
  static const Color proBadgeFgDark = Color(0xFFF4C871);

  // ── Rating (FSRS review buttons) ───────────────────────────
  static const Color ratingAgainLight = Color(0xFFCD5151);
  static const Color ratingHardLight = Color(0xFFCD8F51);
  static const Color ratingGoodLight = Color(0xFF59A680);
  static const Color ratingEasyLight = Color(0xFF648CB4);

  static const Color ratingAgainDark = Color(0xFFD27979);
  static const Color ratingHardDark = Color(0xFFD2A679);
  static const Color ratingGoodDark = Color(0xFF6EB994);
  static const Color ratingEasyDark = Color(0xFF7BA1C6);
}
