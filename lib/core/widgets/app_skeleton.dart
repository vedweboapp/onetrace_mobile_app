import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';

/// Skeleton / shimmer placeholders for loading states across the app.
///
/// Compose [AppSkeletonBox], [AppSkeletonLine], [AppSkeletonCircle],
/// [AppSkeletonListTile], etc., or wrap a custom shape in [AppSkeletonShimmer].
abstract final class AppSkeleton {
  const AppSkeleton._();

  /// Default corner radius for blocks and tiles.
  static const double radius = 8;

  /// Base fill behind the moving highlight (light gray track).
  static const Color trackColor = AppColors.borderLight;

  /// Bright band that sweeps across (subtle pulse on light backgrounds).
  static final Color shimmerMid = AppColors.surfaceHigh.withValues(alpha: 0.92);
}

/// Repeating horizontal shimmer clipped to [child]'s painted area (opaque pixels).
///
/// Prefer wrapping pre-sized widgets (e.g. [ColoredBox] + [SizedBox]).
final class AppSkeletonShimmer extends StatefulWidget {
  const AppSkeletonShimmer({
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final Duration duration;

  @override
  State<AppSkeletonShimmer> createState() => _AppSkeletonShimmerState();
}

final class _AppSkeletonShimmerState extends State<AppSkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant AppSkeletonShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final t = _controller.value;
              return LinearGradient(
                colors: [
                  AppSkeleton.trackColor,
                  AppSkeleton.shimmerMid,
                  AppSkeleton.trackColor,
                ],
                stops: const [0.25, 0.52, 0.78],
                begin: Alignment(-1.25 + t * 2.5, 0),
                end: Alignment(-0.25 + t * 2.5, 0),
                tileMode: TileMode.clamp,
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Rounded rectangle skeleton block.
final class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    required this.height,
    super.key,
    this.width,
    this.borderRadius = AppSkeleton.radius,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AppSkeletonShimmer(
        child: ColoredBox(
          color: AppColors.white,
          child: SizedBox(width: width, height: height),
        ),
      ),
    );
  }
}

/// Thin horizontal bar (titles, captions).
final class AppSkeletonLine extends StatelessWidget {
  const AppSkeletonLine({
    super.key,
    this.height = 14,
    this.widthFactor,
    this.width,
    this.borderRadius = AppSkeleton.radius,
  });

  final double height;

  /// If non-null and [width] is null, uses [FractionallySizedBox] (needs bounded width parent).
  final double? widthFactor;

  /// Fixed width when set (takes precedence over [widthFactor]).
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = AppSkeletonBox(
      height: height,
      width: width,
      borderRadius: borderRadius,
    );

    if (width != null) return child;

    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor ?? 1,
      child: child,
    );
  }
}

/// Circular skeleton (avatar / icon badges).
final class AppSkeletonCircle extends StatelessWidget {
  const AppSkeletonCircle({
    required this.size,
    super.key,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: AppSkeletonShimmer(
          child: const ColoredBox(color: AppColors.white),
        ),
      ),
    );
  }
}

/// Common list row placeholder: avatar + title + subtitle lines.
final class AppSkeletonListTile extends StatelessWidget {
  const AppSkeletonListTile({
    super.key,
    this.avatarSize = 44,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.lineSpacing = 8,
    this.titleWidthFactor = 0.55,
    this.subtitleWidthFactor = 0.38,
  });

  final double avatarSize;
  final EdgeInsets padding;
  final double lineSpacing;
  final double titleWidthFactor;
  final double subtitleWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppSkeletonCircle(size: avatarSize),
          SizedBox(width: lineSpacing + 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonLine(height: 16, widthFactor: titleWidthFactor),
                SizedBox(height: lineSpacing),
                AppSkeletonLine(height: 13, widthFactor: subtitleWidthFactor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows [count] [AppSkeletonListTile]s inside a vertical list with optional separators.
///
/// Intended for `[ListView.builder]` + `neverScrollable` scroll physics inside nested scroll views,
/// or as the main body of a screen while fetching.
final class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    required this.itemCount,
    super.key,
    this.padding = EdgeInsets.zero,
    this.separator,
    this.itemBuilder,
  });

  final int itemCount;
  final EdgeInsets padding;

  /// Optional divider between skeleton rows.
  final Widget? separator;

  /// Override tile; defaults to [AppSkeletonListTile].
  final Widget Function(BuildContext context, int index)? itemBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (context, index) =>
          separator ?? const SizedBox.shrink(),
      itemBuilder: (context, index) {
        return itemBuilder?.call(context, index) ??
            const AppSkeletonListTile();
      },
    );
  }
}

/// Placeholder grid cell (thumbnail + two lines): useful for dashboards / galleries.
final class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({
    super.key,
    this.imageHeight = 120,
    this.padding = const EdgeInsets.all(12),
  });

  final double imageHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSkeletonBox(
            height: imageHeight,
            borderRadius: AppSkeleton.radius + 4,
          ),
          const SizedBox(height: 12),
          AppSkeletonLine(height: 15, widthFactor: 0.75),
          const SizedBox(height: 10),
          AppSkeletonLine(height: 12, widthFactor: 0.45),
        ],
      ),
    );
  }
}
