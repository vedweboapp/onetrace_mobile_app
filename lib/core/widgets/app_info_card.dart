import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_fonts.dart';

class AppInfoCard extends StatelessWidget {
  const AppInfoCard({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppFonts.titleMedium()),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
