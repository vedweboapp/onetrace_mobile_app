import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';

/// Same full-screen backdrop as [LoginPage]: network hero image + soft grey gradient.
class AppScreenBackground extends StatelessWidget {
  const AppScreenBackground({super.key});

  /// Shared with login — keep in one place for consistency.
  static const String imageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDcj0o20qoe3cp78Uiq1it0l0hvWRCdA-OCFGrmrl9SDy-2hQLIXF4lDrxpYbplC2y8fgtaQs9W0EHUVEBa6bqfywsPszcZg6axn4OXQfnV1VwUbpXo1JtI_-Lu5ZmAx7IkvSCBVdU5dwRgwtoOw2A1O5l7c1CKmO1be-HOZkTy5QRKtIWGfUGXCRhNS9JaOu_kqMgcHQXh6vEsV3cwib58AxOs3z5BGThU7pQEkYZ_7z7YdIpftyAwMQiQzoNJdnAT6KMC2gdKIE4d';

  static const BoxDecoration overlayGradient = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.overlayGradientLight, AppColors.overlayGradientDark],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          color: Colors.black.withValues(alpha: 0.15),
          colorBlendMode: BlendMode.darken,
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(color: AppColors.imageFallback);
          },
        ),
        Container(decoration: overlayGradient),
      ],
    );
  }
}
