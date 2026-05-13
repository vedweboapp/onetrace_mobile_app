import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:red5/core/widgets/app_navigator_key.dart';

OverlayEntry? _messageOverlayEntry;

void _removeMessageOverlay() {
  final e = _messageOverlayEntry;
  _messageOverlayEntry = null;
  e?.remove();
}

/// Toast style for [BuildContext.showAppTopToast] / [tryShowAppTopToast].
enum AppTopToastType {
  success,
  error,
  warning,
  info,
}

/// Shows an animated top toast from code paths without a [BuildContext].
void tryShowAppTopToast({
  required String title,
  String? subtitle,
  AppTopToastType type = AppTopToastType.success,
  Duration duration = const Duration(seconds: 4),
}) {
  final nav = appRootNavigatorKey.currentState;
  final ctx = nav?.context;
  if (ctx == null) return;
  ctx.showAppTopToast(
    title: title,
    subtitle: subtitle,
    type: type,
    duration: duration,
  );
}

/// Shows the success toast from any isolate of the app that has a [Navigator].
void tryShowSuccessTopPopup({
  required String title,
  String? subtitle,
  Duration duration = const Duration(seconds: 4),
}) {
  tryShowAppTopToast(
    title: title,
    subtitle: subtitle,
    type: AppTopToastType.success,
    duration: duration,
  );
}

extension TopSnackbarX on BuildContext {
  /// Universal top toast: invite-style card, slide + fade in, auto-dismiss and close control.
  void showAppTopToast({
    required String title,
    String? subtitle,
    AppTopToastType type = AppTopToastType.success,
    Duration duration = const Duration(seconds: 4),
  }) {
    _removeMessageOverlay();

    final messenger = ScaffoldMessenger.maybeOf(this);
    messenger
      ?..hideCurrentSnackBar()
      ..clearMaterialBanners();

    final overlay = Overlay.maybeOf(this, rootOverlay: true);
    if (overlay == null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            (subtitle == null || subtitle.trim().isEmpty)
                ? title
                : '$title\n$subtitle',
          ),
        ),
      );
      return;
    }

    late OverlayEntry entry;
    void removeEntry() {
      if (_messageOverlayEntry != entry) return;
      _messageOverlayEntry = null;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (ctx) {
        final topPad = MediaQuery.paddingOf(ctx).top + 10;
        final maxW = math.min(340.0, MediaQuery.sizeOf(ctx).width - 32);
        return Stack(
          children: [
            Positioned(
              top: topPad,
              left: 16,
              right: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: _TopToastAnimatedShell(
                    displayDuration: duration,
                    onRemoved: removeEntry,
                    builder: (dismiss) => AppTopToastCard(
                      title: title,
                      subtitle: subtitle,
                      type: type,
                      onClose: dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    _messageOverlayEntry = entry;
    overlay.insert(entry);
  }

  /// Success toast (same visual as invite success); prefer [showAppTopToast] for other types.
  void showSuccessTopPopup({
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 4),
  }) {
    showAppTopToast(
      title: title,
      subtitle: subtitle,
      type: AppTopToastType.success,
      duration: duration,
    );
  }

  /// Non-success messages as a floating card on the **root overlay**.
  void showTopSnackBar(SnackBar snackBar) {
    _removeMessageOverlay();

    final messenger = ScaffoldMessenger.maybeOf(this);
    messenger
      ?..hideCurrentSnackBar()
      ..clearMaterialBanners();

    final overlay = Overlay.maybeOf(this, rootOverlay: true);
    if (overlay == null) {
      messenger?.showSnackBar(snackBar);
      return;
    }

    final theme = Theme.of(this);
    final snackTheme = theme.snackBarTheme;
    final action = snackBar.action;
    final duration = snackBar.duration;
    final bg = snackBar.backgroundColor ??
        snackTheme.backgroundColor ??
        theme.colorScheme.inverseSurface;
    final onBg = snackTheme.contentTextStyle?.color ??
        theme.colorScheme.onInverseSurface;
    final bodyStyle = snackTheme.contentTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(color: onBg) ??
        TextStyle(fontSize: 14, height: 1.35, color: onBg);

    late OverlayEntry entry;
    void dismiss() {
      if (_messageOverlayEntry != entry) return;
      _messageOverlayEntry = null;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (ctx) {
        final topPad = MediaQuery.paddingOf(ctx).top + 8;
        return Stack(
          children: [
            Positioned(
              top: topPad,
              left: 16,
              right: 16,
              child: Material(
                elevation: 10,
                shadowColor: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                color: bg,
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: DefaultTextStyle(
                    style: bodyStyle,
                    child: IconTheme(
                      data: IconThemeData(color: onBg, size: 22),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (snackBar.showCloseIcon != true)
                            Padding(
                              padding: const EdgeInsets.only(right: 10, top: 1),
                              child: Icon(Icons.info_outline, color: onBg),
                            ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: snackBar.content,
                            ),
                          ),
                          if (action != null)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: onBg,
                              ),
                              onPressed: () {
                                action.onPressed();
                                dismiss();
                              },
                              child: Text(action.label),
                            ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: onBg,
                            ),
                            onPressed: dismiss,
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    _messageOverlayEntry = entry;
    overlay.insert(entry);

    Timer(duration, dismiss);
  }
}

/// Invite-style toast card (title + optional subtitle + leading icon + dismiss).
class AppTopToastCard extends StatelessWidget {
  const AppTopToastCard({
    required this.title,
    required this.type,
    required this.onClose,
    super.key,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final AppTopToastType type;
  final VoidCallback onClose;

  static const Color _titleColor = Color(0xFF1C1C1E);
  static const Color _subtitleColor = Color(0xFF8E8E93);

  ({Color bg, Color iconColor, IconData icon}) _leading() {
    switch (type) {
      case AppTopToastType.success:
        return (
          bg: const Color(0xFFEAF7EF),
          iconColor: const Color(0xFF34C759),
          icon: Icons.check,
        );
      case AppTopToastType.error:
        return (
          bg: const Color(0xFFFEECEC),
          iconColor: const Color(0xFFE53935),
          icon: Icons.close_rounded,
        );
      case AppTopToastType.warning:
        return (
          bg: const Color(0xFFFFF8E6),
          iconColor: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
        );
      case AppTopToastType.info:
        return (
          bg: const Color(0xFFE8F4FD),
          iconColor: const Color(0xFF1976D2),
          icon: Icons.info_outline_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = _leading();
    final sub = subtitle?.trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: lead.bg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  lead.icon,
                  color: lead.iconColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _titleColor,
                      height: 1.3,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _subtitleColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFFAAAAAA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopToastAnimatedShell extends StatefulWidget {
  const _TopToastAnimatedShell({
    required this.builder,
    required this.displayDuration,
    required this.onRemoved,
  });

  final Widget Function(VoidCallback dismiss) builder;
  final Duration displayDuration;
  final VoidCallback onRemoved;

  @override
  State<_TopToastAnimatedShell> createState() => _TopToastAnimatedShellState();
}

class _TopToastAnimatedShellState extends State<_TopToastAnimatedShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 240),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.22),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  ));

  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _autoHide = Timer(widget.displayDuration, _dismissAnimated);
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismissAnimated() async {
    _autoHide?.cancel();
    _autoHide = null;
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onRemoved();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.builder(_dismissAnimated),
      ),
    );
  }
}
