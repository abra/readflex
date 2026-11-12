import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';

/// Bounds Practice navigation within the shared page measure.
class PracticePageHeader extends StatelessWidget {
  const PracticePageHeader({
    required this.title,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => AppContentFrame(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    child: Row(
      children: [
        const AppBackButton(),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
