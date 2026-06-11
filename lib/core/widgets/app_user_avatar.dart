import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// Avatar that shows initials and only attempts a network image when a URL
/// is provided. Failed loads fall back to initials without throwing.
class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 16,
    this.backgroundColor = const Color(0xFFE5E7EB),
    this.foregroundColor = const Color(0xFF6B7280),
    this.fontSize,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final double? fontSize;

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

  TextStyle get _initialStyle => AppFonts.labelMedium(color: foregroundColor)
      .copyWith(
        fontWeight: FontWeight.w700,
        fontSize: fontSize ?? (radius * 0.68),
      );

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _initialsAvatar();
    }

    final size = radius * 2;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsContent(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _initialsContent();
          },
        ),
      ),
    );
  }

  Widget _initialsAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: _initialsContent(),
    );
  }

  Widget _initialsContent() {
    return Text(_initial, style: _initialStyle);
  }
}
