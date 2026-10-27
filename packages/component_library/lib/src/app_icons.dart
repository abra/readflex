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
  // Dismissal or non-destructive clearing, never deletion of saved items.
  static const IconData close = LucideIcons.x;
  static const IconData search = LucideIcons.search;
  static const IconData searchOff = LucideIcons.searchX;
  static const IconData refresh = LucideIcons.rotateCcw;
  static const IconData undo = LucideIcons.undo2;
  static const IconData remove = LucideIcons.minus;
  static const IconData delete = LucideIcons.trash2;
  static const IconData edit = LucideIcons.pencil;
  static const IconData play = LucideIcons.play;
  static const IconData paste = LucideIcons.clipboardPaste;
  static const IconData copy = LucideIcons.copy;
  static const IconData moreHorizontal = LucideIcons.moreHorizontal;
  static const IconData moreVertical = LucideIcons.moreVertical;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronUp = LucideIcons.chevronUp;
  static const IconData returnToReading = LucideIcons.undo2;
  static const IconData arrowRight = LucideIcons.arrowRight;
  static const IconData arrowLeft = LucideIcons.arrowLeft;
  static const IconData arrowDown = LucideIcons.arrowDown;

  // ── Content ───────────────────────────────────────────────
  static const IconData book = LucideIcons.bookOpen;
  static const IconData article = LucideIcons.fileText;
  static const IconData comic = LucideIcons.bookImage;

  /// Items never opened: the Library's New collection.
  static const IconData newItems = LucideIcons.sparkles;
  static const IconData articleBadge = LucideIcons.newspaper;
  static const IconData bookmark = LucideIcons.bookmark;
  static const IconData bookmarkAdd = LucideIcons.bookmarkPlus;
  static const IconData bookmarkSaved = LucideIcons.bookmarkCheck;

  // ── Tabs ──────────────────────────────────────────────────
  static const IconData home = LucideIcons.house;
  // A fan of cards: the review deck. Lucide 4 (Lucide 1.56+).
  static const IconData practice = LucideIcons.playingCardsFan;
  static const IconData profile = LucideIcons.user;

  // ── Practice ──────────────────────────────────────────────
  static const IconData words = LucideIcons.spellCheck;
  static const IconData circle = LucideIcons.circle;
  static const IconData checkCircle = LucideIcons.circleCheck;
  static const IconData reviewAgain = LucideIcons.rotateCcw;
  static const IconData collection = LucideIcons.folder;
  static const IconData collectionAdd = LucideIcons.folderPlus;
  static const IconData collectionFavourites = LucideIcons.heart;

  static const IconData author = LucideIcons.user;
  static const IconData highlight = LucideIcons.highlighter;
  static const IconData quote = LucideIcons.quote;
  static const IconData check = LucideIcons.check;
  static const IconData clock = LucideIcons.clock;
  static const IconData global = LucideIcons.globe;
  static const IconData dictionary = LucideIcons.bookOpen;
  static const IconData translate = LucideIcons.languages;

  // ── Reader ────────────────────────────────────────────────
  static const IconData volumeUp = LucideIcons.volume2;
  // Mirrors in RTL: back points towards the previous screen.
  static const IconData back = LucideIcons.chevronLeftDir;
  static const IconData toc = LucideIcons.list;
  static const IconData font = LucideIcons.type;
  // PDF page appearance choices.
  static const IconData pageWhole = LucideIcons.file;
  static const IconData pageTrimmed = LucideIcons.crop;
  static const IconData pageColorsTheme = LucideIcons.palette;
  static const IconData pageColorsOriginal = LucideIcons.image;
  static const IconData pageTurnHorizontal = LucideIcons.arrowLeftRight;
  static const IconData pageTurnVertical = LucideIcons.arrowUpDown;
  // Reader text columns: chosen by the window, one page, or a spread.
  static const IconData columnsAuto = LucideIcons.sparkles;
  static const IconData columnsOne = LucideIcons.file;
  static const IconData columnsTwo = LucideIcons.bookOpen;
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

  // ── States ────────────────────────────────────────────────
  static const IconData error = LucideIcons.alertCircle;
  static const IconData celebration = LucideIcons.partyPopper;
  static const IconData offline = LucideIcons.wifiOff;
}
