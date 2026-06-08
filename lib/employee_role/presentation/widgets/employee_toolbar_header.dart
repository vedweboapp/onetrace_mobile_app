import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// Title row with notification, settings, and profile (technician screens).
class EmployeeToolbarHeader extends StatelessWidget {
  const EmployeeToolbarHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onSettingsPressed,
    this.onLogout,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack != null ? 6 : 18, 8, 10, 8),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: AppColors.inkStrong,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            title,
            style: AppFonts.headlineSmall(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 24),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.inkStrong,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onSettingsPressed,
            icon: const Icon(Icons.settings_rounded),
            color: AppColors.inkStrong,
          ),
          if (onLogout != null)
            PopupMenuButton<String>(
              tooltip: 'Profile',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'logout') onLogout!();
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFD8B48A),
                child: Icon(Icons.person, size: 20, color: AppColors.inkStrong),
              ),
            )
          else
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFD8B48A),
              child: Icon(Icons.person, size: 20, color: AppColors.inkStrong),
            ),
        ],
      ),
    );
  }
}
