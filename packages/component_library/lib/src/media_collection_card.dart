import 'package:flutter/material.dart';

import 'theme/app_radius.dart';
import 'theme/spacing.dart';

/// A reusable collection card with a visual media area and compact metadata.
class MediaCollectionCard extends StatelessWidget {
  const MediaCollectionCard({
    required this.media,
    required this.title,
    this.subtitle,
    this.meta,
    this.onTap,
    this.topRight,
    this.mediaAspectRatio = 0.74,
    super.key,
  });

  final Widget media;
  final String title;
  final String? subtitle;
  final String? meta;
  final VoidCallback? onTap;
  final Widget? topRight;
  final double mediaAspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: mediaAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  media,
                  if (topRight != null)
                    Positioned(
                      top: Spacing.small,
                      right: Spacing.small,
                      child: topRight!,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.medium,
                Spacing.medium,
                Spacing.medium,
                Spacing.mediumLarge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: Spacing.xSmall),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (meta != null) ...[
                    const SizedBox(height: Spacing.small),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.small,
                          vertical: 6,
                        ),
                        child: Text(
                          meta!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
