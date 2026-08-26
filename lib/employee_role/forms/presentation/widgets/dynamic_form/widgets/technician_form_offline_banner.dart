part of '../dynamic_form.dart';

final class TechnicianFormOfflineBanner extends StatelessWidget {
  const TechnicianFormOfflineBanner({
    super.key,
    required this.visible,
    this.isSyncing = false,
  });

  final bool visible;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final message = isSyncing
        ? 'Back online â€” refreshing formâ€¦'
        : 'Offline â€” showing saved form';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF2D38B)),
      ),
      child: Row(
        children: [
          Icon(
            isSyncing ? Icons.sync_rounded : Icons.cloud_off_rounded,
            size: 18,
            color: const Color(0xFF8A6D1D),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppFonts.bodySmall(
                color: const Color(0xFF8A6D1D),
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
