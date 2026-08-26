part of '../quote_project.dart';

class _BottomSelectTag extends StatelessWidget {
  const _BottomSelectTag({
    required this.label,
    required this.placeholder,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String placeholder;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final sel = selected?.trim();
    final hasSelection = sel != null && sel.isNotEmpty;
    final display = hasSelection ? sel : placeholder;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            final h = context.appScreenHeight;
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: const Color(0xFF1F2937),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx) => SafeArea(
                child: SizedBox(
                  height: h * 0.62,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check,
                              color: Color(0xFF9CA3AF),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                placeholder,
                                style:
                                    AppFonts.titleMedium(
                                  color:
                                      Colors.white.withValues(alpha: 0.9),
                                ).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF374151)),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: options.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: Color(0xFF374151),
                          ),
                          itemBuilder: (context, i) {
                            final o = options[i];
                            final isSel = hasSelection && o == sel;
                            return ListTile(
                              title: Text(
                                o,
                                style: AppFonts.bodyMedium(color: Colors.white)
                                    .copyWith(
                                  fontWeight: isSel
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: isSel
                                  ? const Icon(
                                      Icons.check,
                                      color: Color(0xFF34D399),
                                      size: 20,
                                    )
                                  : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                onChanged(o);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Text(
                  '$label ',
                  style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                ),
                Expanded(
                  child: Text(
                    display,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: AppFonts.labelSmall(
                          color: hasSelection
                              ? AppColors.ink
                              : AppColors.mutedLight,
                        ).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTag extends StatelessWidget {
  const _BottomTag({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Text(
              '$label ',
              style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
            ),
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.labelSmall(color: AppColors.ink).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
