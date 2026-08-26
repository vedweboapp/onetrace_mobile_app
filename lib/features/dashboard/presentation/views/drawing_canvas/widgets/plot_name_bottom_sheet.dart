part of '../drawing_canvas.dart';

class _PlotNameBottomSheetBody extends StatefulWidget {
  const _PlotNameBottomSheetBody();

  @override
  State<_PlotNameBottomSheetBody> createState() =>
      _PlotNameBottomSheetBodyState();
}

class _PlotNameBottomSheetBodyState extends State<_PlotNameBottomSheetBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    scheduleDisposeTextControllers([_controller]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _controller.text.trim().isNotEmpty;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9DA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'New Plot Name',
                  style: AppFonts.headlineSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(
                  'PLOT LABEL',
                  style: AppFonts.labelMedium(
                    color: AppColors.muted,
                  ).copyWith(letterSpacing: 1.8, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _controller,
                  hintText: 'Enter plot name...',
                  autofocus: true,
                  fillColor: const Color(0xFFF4F4F5),
                  borderRadius: 12,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: canContinue
                        ? () =>
                              Navigator.of(context).pop(_controller.text.trim())
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF070A0E),
                      disabledBackgroundColor: const Color(0xFFB4B4B7),
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: AppFonts.titleMedium(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppFonts.titleMedium(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
