import 'package:material_ui/material_ui.dart';

class CenteredCircularProgressIndicator extends StatelessWidget {
  const CenteredCircularProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
