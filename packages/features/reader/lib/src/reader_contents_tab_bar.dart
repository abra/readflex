import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_contents_tabs.dart';
import 'reader_control_styles.dart';
import 'reader_drawer_layout.dart';

/// Contents tabs that fill the available width before scrolling is necessary.
class ReaderContentsTabBar extends StatelessWidget {
  const ReaderContentsTabBar({super.key, required this.tabs});

  final List<ReaderContentsTab> tabs;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final labels = [
      for (final tab in tabs)
        switch (tab) {
          ReaderContentsTab.chapters => l10n.readerChapters,
          ReaderContentsTab.pages => l10n.readerPages,
          ReaderContentsTab.bookmarks => l10n.readerBookmarks,
          ReaderContentsTab.highlights => l10n.readerHighlights,
        },
    ];
    if (context.isCupertino) {
      final controller = DefaultTabController.of(context);
      final hasFourTabs = tabs.length > 3;
      final useCompactLabels = hasFourTabs && !AppWindowSize.isMedium(context);
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: readerDrawerContentInset(context),
          vertical: AppSpacing.sm,
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => AppChoiceControl<int>(
            selected: controller.index,
            proportionalWidth: hasFourTabs,
            options: [
              for (var index = 0; index < labels.length; index++)
                AppChoiceOption(
                  value: index,
                  label: labels[index],
                  labelStyle: useCompactLabels ? context.text.labelSmall : null,
                ),
            ],
            onChanged: controller.animateTo,
          ),
        ),
      );
    }
    final labelStyle = readerControlCaptionStyle(context);
    final iconSize = readerControlIconSize(context);
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final minimumWidths = <double>[];
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
      )..layout();
      minimumWidths.add(
        math.max(
          AppSizes.buttonHeight,
          painter.width + iconSize + AppSpacing.xxs + 2 * AppSpacing.sm,
        ),
      );
      painter.dispose();
    }
    final minimumTotal = minimumWidths.fold(0.0, (sum, width) => sum + width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.max(
          0.0,
          constraints.maxWidth - 2 * AppSpacing.sm,
        );
        final overflows = minimumTotal > available;
        final equalWidth = available / tabs.length;
        final equalWidthsFit = minimumWidths.every(
          (width) => width <= equalWidth,
        );
        final extraWidth =
            math.max(0.0, available - minimumTotal) / tabs.length;

        return ScrollEdgeFadeStack(
          axis: Axis.horizontal,
          enabled: overflows,
          surfaceColor: context.appTheme.sheetColor,
          fadeInsets: EdgeInsets.only(
            bottom: TabBarTheme.of(context).dividerHeight ?? 1,
          ),
          // Explicit widths let shorter tabs share spare room with long ones;
          // Flutter's non-scrolling TabBar only supports equal-width cells.
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            physics: overflows ? null : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            labelPadding: EdgeInsets.zero,
            tabs: [
              for (final (index, tab) in tabs.indexed)
                Tab(
                  child: SizedBox(
                    width: equalWidthsFit
                        ? equalWidth
                        : minimumWidths[index] + extraWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: _ReaderContentsTabLabel(
                        icon: switch (tab) {
                          ReaderContentsTab.chapters => AppIcons.toc,
                          ReaderContentsTab.pages => AppIcons.viewGrid,
                          ReaderContentsTab.bookmarks => AppIcons.bookmark,
                          ReaderContentsTab.highlights => AppIcons.highlight,
                        },
                        label: labels[index],
                      ),
                    ),
                  ),
                ),
            ],
            labelColor: colors.selectedControlForeground,
            unselectedLabelColor: colors.onSurfaceVariant,
            labelStyle: labelStyle,
            unselectedLabelStyle: labelStyle,
            indicator: BoxDecoration(
              color: colors.selectedControlBackground,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(AppSpacing.xs),
            dividerHeight: 0,
          ),
        );
      },
    );
  }
}

class _ReaderContentsTabLabel extends StatelessWidget {
  const _ReaderContentsTabLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: readerControlIconSize(context)),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}
