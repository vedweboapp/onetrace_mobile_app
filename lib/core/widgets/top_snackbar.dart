import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:red5/core/widgets/app_navigator_key.dart';

OverlayEntry? _messageOverlayEntry;

/// Toast style for [BuildContext.showAppTopToast] / [tryShowAppTopToast].
enum AppTopToastType {
  success,
  error,
  warning,
  info,
}

/// Shared leading visuals for [AppTopToastCard] and SnackBar-as-top-toast.
({Color bg, Color iconColor, IconData icon}) _appTopToastLeading(
  AppTopToastType type,
) {
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

AppTopToastType _toastTypeFromSnackBar(SnackBar snackBar, ThemeData theme) {
  final bg = snackBar.backgroundColor;
  if (bg == null) return AppTopToastType.info;
  if (bg == theme.colorScheme.error) return AppTopToastType.error;
  if (bg == theme.colorScheme.inverseSurface) return AppTopToastType.info;
  const successGreen = Color(0xFF34C759);
  if (bg == successGreen) return AppTopToastType.success;
  return AppTopToastType.info;
}

void _removeMessageOverlay() {
  final e = _messageOverlayEntry;
  _messageOverlayEntry = null;
  e?.remove();
}

/// Shows an animated top toast from code paths without a [BuildContext].
void tryShowAppTopToast({
  required String title,
  String? subtitle,
  AppTopToastType type = AppTopToastType.success,
  Duration duration = const Duration(seconds: 4),
}) {
  final nav = appRootNavigatorKey.currentState;
  // Prefer [NavigatorState.overlay] — [NavigatorState.context] sits *above*
  // the Overlay, so Overlay.maybeOf(nav.context) is always null and used to
  // fall back to a bottom SnackBar.
  final overlay = nav?.overlay;
  final ctx = overlay?.context ?? nav?.context;
  if (overlay == null || ctx == null) return;
  _showAppTopToastOnOverlay(
    context: ctx,
    overlay: overlay,
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

void _showAppTopToastOnOverlay({
  required BuildContext context,
  required OverlayState overlay,
  required String title,
  String? subtitle,
  AppTopToastType type = AppTopToastType.success,
  Duration duration = const Duration(seconds: 4),
}) {
  _removeMessageOverlay();

  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..clearMaterialBanners();

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

extension TopSnackbarX on BuildContext {
  /// Universal top toast: invite-style card, slide + fade in, auto-dismiss,
  /// close control, and swipe up/left/right to dismiss.
  void showAppTopToast({
    required String title,
    String? subtitle,
    AppTopToastType type = AppTopToastType.success,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.maybeOf(this, rootOverlay: true) ??
        appRootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      // Last resort — still prefer floating near the top over a bottom bar.
      final messenger = ScaffoldMessenger.maybeOf(this);
      messenger
        ?..hideCurrentSnackBar()
        ..clearMaterialBanners()
        ..showSnackBar(
          SnackBar(
            content: Text(
              (subtitle == null || subtitle.trim().isEmpty)
                  ? title
                  : '$title\n$subtitle',
            ),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: MediaQuery.paddingOf(this).top + 12,
              left: 16,
              right: 16,
              bottom: MediaQuery.sizeOf(this).height -
                  MediaQuery.paddingOf(this).top -
                  120,
            ),
            dismissDirection: DismissDirection.up,
          ),
        );
      return;
    }

    _showAppTopToastOnOverlay(
      context: this,
      overlay: overlay,
      title: title,
      subtitle: subtitle,
      type: type,
      duration: duration,
    );
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

  /// Same animated top card as [showSuccessTopPopup] / [showAppTopToast], using
  /// [SnackBar] content (universal for validation, errors, and short notices).
  void showTopSnackBar(SnackBar snackBar) {
    _removeMessageOverlay();

    final messenger = ScaffoldMessenger.maybeOf(this);
    messenger
      ?..hideCurrentSnackBar()
      ..clearMaterialBanners();

    final overlay = Overlay.maybeOf(this, rootOverlay: true) ??
        appRootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      messenger?.showSnackBar(snackBar);
      return;
    }

    final theme = Theme.of(this);
    final action = snackBar.action;
    final duration = snackBar.duration;
    final toastType = _toastTypeFromSnackBar(snackBar, theme);
    const titleStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1C1C1E),
      height: 1.35,
    );

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
                    builder: (dismiss) => _SnackBarTopToastCard(
                      toastType: toastType,
                      content: DefaultTextStyle.merge(
                        style: titleStyle,
                        child: snackBar.content,
                      ),
                      action: action,
                      onDismiss: dismiss,
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
}

/// SnackBar message in the same shell as [AppTopToastCard] (profile success).
class _SnackBarTopToastCard extends StatelessWidget {
  const _SnackBarTopToastCard({
    required this.toastType,
    required this.content,
    required this.onDismiss,
    this.action,
  });

  final AppTopToastType toastType;
  final Widget content;
  final VoidCallback onDismiss;
  final SnackBarAction? action;

  @override
  Widget build(BuildContext context) {
    final lead = _appTopToastLeading(toastType);
    final snackAction = action;
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
              child: content,
            ),
            if (snackAction != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () {
                  snackAction.onPressed();
                  onDismiss();
                },
                child: Text(snackAction.label),
              ),
            GestureDetector(
              onTap: onDismiss,
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

  @override
  Widget build(BuildContext context) {
    final lead = _appTopToastLeading(type);
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
  static const _dismissDistance = 56.0;
  static const _dismissVelocity = 420.0;

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
  Offset _dragOffset = Offset.zero;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _scheduleAutoHide();
  }

  void _scheduleAutoHide() {
    _autoHide?.cancel();
    _autoHide = Timer(widget.displayDuration, _dismissAnimated);
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismissAnimated() async {
    if (_isDismissing) return;
    _isDismissing = true;
    _autoHide?.cancel();
    _autoHide = null;
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onRemoved();
  }

  void _onPanStart(DragStartDetails details) {
    _autoHide?.cancel();
    _autoHide = null;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isDismissing) return;
    setState(() {
      var next = _dragOffset + details.delta;
      // Slight resistance when dragging down (toast sits at top).
      if (next.dy > 0) {
        next = Offset(next.dx, next.dy * 0.35);
      }
      _dragOffset = next;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDismissing) return;
    final velocity = details.velocity.pixelsPerSecond;
    final horizontal = _dragOffset.dx.abs();
    final upward = -_dragOffset.dy;
    final shouldDismiss = upward >= _dismissDistance ||
        horizontal >= _dismissDistance ||
        velocity.dy <= -_dismissVelocity ||
        velocity.dx.abs() >= _dismissVelocity;

    if (shouldDismiss) {
      unawaited(_dismissAnimated());
      return;
    }

    setState(() => _dragOffset = Offset.zero);
    _scheduleAutoHide();
  }

  void _onPanCancel() {
    if (_isDismissing) return;
    setState(() => _dragOffset = Offset.zero);
    _scheduleAutoHide();
  }

  double get _dragFade {
    final distance = math.max(_dragOffset.dy.abs(), _dragOffset.dx.abs());
    return (1 - (distance / 140)).clamp(0.55, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      behavior: HitTestBehavior.opaque,
      child: Transform.translate(
        offset: _dragOffset,
        child: Opacity(
          opacity: _dragFade,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: widget.builder(_dismissAnimated),
            ),
          ),
        ),
      ),
    );
  }
}
