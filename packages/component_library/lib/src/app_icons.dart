import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Centralized icon constants backed by Lucide Icons.
///
/// All icon references across the app go through this class. If we need
/// to swap an icon or change icon sets, this is the only file to touch.
abstract final class AppIcons {
  // ── Navigation ────────────────────────────────────────────
  static const IconData library = LucideIcons.library;

  // ── Actions ───────────────────────────────────────────────
  static const IconData add = LucideIcons.plus;
  static const IconData close = LucideIcons.x;
  static const IconData search = LucideIcons.search;
  static const IconData searchOff = LucideIcons.searchX;
  static const IconData refresh = LucideIcons.rotateCcw;
  static const IconData remove = LucideIcons.minus;
  static const IconData delete = LucideIcons.trash2;
  static const IconData play = LucideIcons.play;
  static const IconData paste = LucideIcons.clipboardPaste;
  static const IconData moreHorizontal = LucideIcons.moreHorizontal;
  static const IconData moreVertical = LucideIcons.moreVertical;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData chevronRight = LucideIcons.chevronRight;

  // ── Content ───────────────────────────────────────────────
  static const IconData book = LucideIcons.bookOpen;
  static const IconData article = LucideIcons.fileText;
  static const IconData articleBadge = LucideIcons.newspaper;
  static const IconData bookmark = LucideIcons.bookmark;
  static const IconData bookmarkAdd = LucideIcons.bookmarkPlus;
  static const IconData collection = LucideIcons.folder;
  static const IconData collectionAdd = LucideIcons.folderPlus;
  static const IconData collectionFavourites = LucideIcons.heart;
  static const IconData author = LucideIcons.user;
  static const IconData highlight = LucideIcons.highlighter;
  static const IconData quote = LucideIcons.quote;
  static const IconData check = LucideIcons.check;
  static const IconData clock = LucideIcons.clock;
  static const IconData global = LucideIcons.globe;

  // ── Reader ────────────────────────────────────────────────
  static const IconData volumeUp = LucideIcons.volume2;
  static const IconData back = chevronLeft;
  static const IconData toc = LucideIcons.list;
  static const IconData font = LucideIcons.type;
  static const IconData pageTurnHorizontal = LucideIcons.arrowLeftRight;
  static const IconData pageTurnVertical = LucideIcons.arrowUpDown;
  static const IconData alignStart = LucideIcons.alignLeft;
  static const IconData alignEnd = LucideIcons.alignRight;
  static const IconData alignJustify = LucideIcons.alignJustify;
  static const IconData share = LucideIcons.share2;

  // ── Layout ────────────────────────────────────────────────
  static const IconData viewList = LucideIcons.list;
  static const IconData viewGrid = LucideIcons.layoutGrid;

  // ── Import ────────────────────────────────────────────────
  static const IconData uploadFile = LucideIcons.upload;
  static const IconData link = LucideIcons.link;

  // ── Theme ─────────────────────────────────────────────────
  static const IconData lightMode = LucideIcons.sun;
  static const IconData darkMode = LucideIcons.moon;
  static const IconData brightnessLow = LucideIcons.sunDim;
  static const IconData deviceMode = LucideIcons.smartphone;

  // ── Metadata ──────────────────────────────────────────────
  static const IconData language = LucideIcons.globe;

  // ── Onboarding ────────────────────────────────────────────
  static const IconData readAnything = LucideIcons.bookOpen;
  static const IconData highlightSave = LucideIcons.highlighter;

  // ── States ────────────────────────────────────────────────
  static const IconData error = LucideIcons.alertCircle;
  static const IconData celebration = LucideIcons.partyPopper;
  static const IconData offline = LucideIcons.wifiOff;
}
