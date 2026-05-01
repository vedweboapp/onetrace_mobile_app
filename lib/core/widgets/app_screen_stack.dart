import 'package:flutter/material.dart';
import 'package:red5/core/widgets/app_screen_background.dart';

/// Full-screen [AppScreenBackground] with a foreground layer — use under transparent scaffolds.
class AppScreenStack extends StatelessWidget {
  const AppScreenStack({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: AppScreenBackground()),
        Positioned.fill(child: child),
      ],
    );
  }
}
