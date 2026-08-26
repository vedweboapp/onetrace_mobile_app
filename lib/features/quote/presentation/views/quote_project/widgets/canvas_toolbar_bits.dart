part of '../quote_project.dart';

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.icon, this.isActive = false, this.onTap});

  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF0F172A) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        color: isActive ? Colors.white : const Color(0xFF6B7280),
        size: 16,
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: child,
      ),
    );
  }
}

class _ZoomText extends StatelessWidget {
  const _ZoomText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: AppFonts.labelSmall(color: AppColors.paginationText).copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
