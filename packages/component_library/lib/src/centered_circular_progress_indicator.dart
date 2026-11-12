import 'package:flutter/widgets.dart';

import 'app_progress_indicator.dart';

class CenteredCircularProgressIndicator extends StatelessWidget {
  const CenteredCircularProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: AppProgressIndicator());
}
