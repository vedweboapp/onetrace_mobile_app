import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

class EmployeeJobTimerBanner extends StatelessWidget {
  const EmployeeJobTimerBanner({super.key, required this.elapsed});

  final Duration elapsed;

  String get _formatted {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9D2FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.timer_outlined,
              size: 18,
              color: Color(0xFF5E4BFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JOB TIMER RUNNING',
                  style: AppFonts.labelSmall(
                    color: const Color(0xFF5E4BFF),
                  ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.4),
                ),
                const SizedBox(height: 2),
                Text(
                  'Time is being logged for this job.',
                  style: AppFonts.bodySmall(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            _formatted,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontFeatures: const []),
          ),
        ],
      ),
    );
  }
}
