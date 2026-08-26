part of '../dynamic_form.dart';

class _ImageUploadPlaceholder extends StatelessWidget {
  const _ImageUploadPlaceholder({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 26,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Take a photo, pick several from gallery, or files',
              textAlign: TextAlign.center,
              style: AppFonts.bodySmall(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageUploadSelectionGrid extends StatelessWidget {
  const _ImageUploadSelectionGrid({
    required this.files,
    required this.readOnly,
    required this.onRemove,
    this.onAdd,
  });

  final List<_PickedFileValue> files;
  final bool readOnly;
  final ValueChanged<int> onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < files.length; i++)
            _ImageUploadThumb(
              picked: files[i],
              readOnly: readOnly,
              onRemove: () => onRemove(i),
            ),
          if (!readOnly && onAdd != null) _ImageUploadAddTile(onTap: onAdd!),
        ],
      ),
    );
  }
}

class _ImageUploadThumb extends StatelessWidget {
  const _ImageUploadThumb({
    required this.picked,
    required this.readOnly,
    required this.onRemove,
  });

  final _PickedFileValue picked;
  final bool readOnly;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasFile = picked.path != null && File(picked.path!).existsSync();

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasFile
                  ? Image.file(File(picked.path!), fit: BoxFit.cover)
                  : ColoredBox(
                      color: const Color(0xFFF3F4F6),
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 28,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
            ),
          ),
          if (!readOnly)
            Positioned(
              top: -6,
              right: -6,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.inkStrong,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageUploadAddTile extends StatelessWidget {
  const _ImageUploadAddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 88,
          height: 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppColors.inkStrong, size: 26),
              const SizedBox(height: 4),
              Text(
                'Add',
                style: AppFonts.bodySmall(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
