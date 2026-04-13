import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Centralized icon constants backed by Lucide Icons.
///
/// All icon references across the app go through this class. If we need
/// to swap an icon or change icon sets, this is the only file to touch.
abstract final class AppIcons {
  // ── Navigation ────────────────────────────────────────────
  static const IconData home = LucideIcons.home;
  static const IconData library = LucideIcons.library;
  static const IconData dictionary = LucideIcons.bookOpen;
  static const IconData practice = LucideIcons.brain;
  static const IconData profile = LucideIcons.user;

  // ── Actions ───────────────────────────────────────────────
  static const IconData add = LucideIcons.plus;
  static const IconData close = LucideIcons.x;
  static const IconData search = LucideIcons.search;
  static const IconData searchOff = LucideIcons.searchX;
  static const IconData refresh = LucideIcons.rotateCcw;
  static const IconData remove = LucideIcons.minus;
  static const IconData moreHorizontal = LucideIcons.moreHorizontal;
  static const IconData chevronRight = LucideIcons.chevronRight;

  // ── Content ───────────────────────────────────────────────
  static const IconData book = LucideIcons.bookOpen;
  static const IconData article = LucideIcons.fileText;
  static const IconData articleBadge = LucideIcons.newspaper;
  static const IconData bookmark = LucideIcons.bookmark;
  static const IconData bookmarkAdd = LucideIcons.bookmarkPlus;
  static const IconData highlight = LucideIcons.highlighter;
  static const IconData flashcard = LucideIcons.layers;
  static const IconData quote = LucideIcons.quote;
  static const IconData check = LucideIcons.check;
  static const IconData clock = LucideIcons.clock;

  // ── Reader ────────────────────────────────────────────────
  static const IconData translate = LucideIcons.languages;
  static const IconData volumeUp = LucideIcons.volume2;

  // ── Layout ────────────────────────────────────────────────
  static const IconData viewList = LucideIcons.list;
  static const IconData viewGrid = LucideIcons.layoutGrid;

  // ── Import ────────────────────────────────────────────────
  static const IconData uploadFile = LucideIcons.upload;
  static const IconData link = LucideIcons.link;

  // ── Theme ─────────────────────────────────────────────────
  static const IconData lightMode = LucideIcons.sun;
  static const IconData darkMode = LucideIcons.moon;
  static const IconData systemMode = LucideIcons.monitor;

  // ── Settings / Profile ────────────────────────────────────
  static const IconData textFields = LucideIcons.type;
  static const IconData language = LucideIcons.globe;
  static const IconData cloud = LucideIcons.cloud;
  static const IconData download = LucideIcons.download;
  static const IconData notifications = LucideIcons.bell;
  static const IconData shield = LucideIcons.shield;
  static const IconData info = LucideIcons.info;
  static const IconData terms = LucideIcons.bookMarked;
  static const IconData designSystem = LucideIcons.palette;
  static const IconData logOut = LucideIcons.logOut;

  // ── Premium ───────────────────────────────────────────────
  static const IconData premium = LucideIcons.crown;
  static const IconData sparkles = LucideIcons.sparkles;
  static const IconData cloudSync = LucideIcons.cloud;

  // ── Onboarding ────────────────────────────────────────────
  static const IconData readAnything = LucideIcons.bookOpen;
  static const IconData highlightSave = LucideIcons.highlighter;
  static const IconData buildFlashcards = LucideIcons.layers;
  static const IconData translateLearn = LucideIcons.languages;
  static const IconData practiceRemember = LucideIcons.brain;

  // ── States ────────────────────────────────────────────────
  static const IconData error = LucideIcons.alertCircle;
  static const IconData celebration = LucideIcons.partyPopper;

  // ── Formatting (design system demo) ───────────────────────
  static const IconData tune = LucideIcons.sparkles;
}
