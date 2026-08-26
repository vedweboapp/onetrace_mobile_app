part of '../quote_project.dart';

class _DocumentCarousel extends StatelessWidget {
  const _DocumentCarousel({
    required this.documents,
    required this.selectedIndex,
    required this.scrollController,
    required this.onSelect,
    required this.onRemove,
    required this.onReplace,
    required this.onPrev,
    required this.onNext,
  });

  final List<_UploadedDoc> documents;
  final int selectedIndex;
  final ScrollController scrollController;
  final void Function(int index) onSelect;
  final void Function(int index) onRemove;
  final void Function(int index) onReplace;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const double _card = 72;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final n = documents.length;
    final canPrev = selectedIndex > 0;
    final canNext = selectedIndex < n - 1;

    return Row(
      children: [
        _CarouselArrow(
          icon: Icons.chevron_left,
          isDark: false,
          enabled: canPrev,
          onTap: onPrev,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: _card + 6,
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 3),
              itemCount: n,
              separatorBuilder: (_, _) => const SizedBox(width: _gap),
              itemBuilder: (context, index) {
                final d = documents[index];
                final selected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => onSelect(index),
                  child: _DocThumbCard(
                    doc: d,
                    selected: selected,
                    size: _card,
                    onRemove: selected ? () => onRemove(index) : null,
                    onReplace: selected ? () => onReplace(index) : null,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        _CarouselArrow(
          icon: Icons.chevron_right,
          isDark: true,
          enabled: canNext,
          onTap: onNext,
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${selectedIndex + 1} / $n',
            style: AppFonts.labelMedium(color: Colors.white).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
          ),
        ),
      ],
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.icon,
    required this.isDark,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool isDark;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF111827) : const Color(0xFFE5E7EB);
    final fg = isDark ? Colors.white : const Color(0xFF6B7280);

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: fg, size: 22),
          ),
        ),
      ),
    );
  }
}

class _DocThumbCard extends StatelessWidget {
  const _DocThumbCard({
    required this.doc,
    required this.selected,
    required this.size,
    this.onRemove,
    this.onReplace,
  });

  final _UploadedDoc doc;
  final bool selected;
  final double size;
  final VoidCallback? onRemove;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD1D5DB), Color(0xFF1F2937)],
        ),
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
          width: selected ? 3 : 0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Text(
                    'Active',
                    style: AppFonts.labelSmall(
                          color: Colors.white.withValues(alpha: 0.65),
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                  ),
                ],
                if (selected) const SizedBox(height: 2),
                Text(
                  doc.levelName.isNotEmpty ? doc.levelName : 'No level',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.labelSmall(
                        color: Colors.white.withValues(alpha: 0.78),
                      ).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                      ),
                ),
              ],
            ),
          ),
          if (selected && onReplace != null)
            Positioned(
              top: 6,
              left: 6,
              child: Material(
                color: const Color(0xCC111827),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onReplace,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.swap_horiz,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
          if (selected && onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: const Color(0xCC111827),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
