import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';

/// Skeleton / shimmer placeholders for loading states across the app.
///
/// Compose [AppSkeletonBox], [AppSkeletonLine], [AppSkeletonCircle],
/// [AppSkeletonListTile], [AppSkeletonGradientBox], [AppSkeletonToastBlock],
/// [AppSkeletonScreenBody], etc., or wrap a custom shape in [AppSkeletonShimmer].
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

// --- Gradient shimmer (LinearGradient sweep) + universal screen placeholders ---

/// Animated rounded rectangle using a soft horizontal gradient sweep (Material-style shimmer).
///
/// Matches the common “pill + card” loading pattern; use inside bounded width when
/// [width] is [double.infinity].
final class AppSkeletonGradientBox extends StatefulWidget {
  const AppSkeletonGradientBox({
    required this.width,
    required this.height,
    required this.borderRadius,
    super.key,
    this.duration = const Duration(milliseconds: 1400),
  });

  final double width;
  final double height;
  final double borderRadius;
  final Duration duration;

  @override
  State<AppSkeletonGradientBox> createState() => _AppSkeletonGradientBoxState();
}

final class _AppSkeletonGradientBoxState extends State<AppSkeletonGradientBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  late final Animation<double> _animation = Tween<double>(begin: -1.5, end: 2.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void didUpdateWidget(covariant AppSkeletonGradientBox oldWidget) {
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

  static const List<Color> _colors = [
    Color(0xFFEEEEEE),
    Color(0xFFF8F8F8),
    Color(0xFFEEEEEE),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final v = _animation.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (v - 0.4).clamp(0.0, 1.0),
                v.clamp(0.0, 1.0),
                (v + 0.4).clamp(0.0, 1.0),
              ],
              colors: _colors,
            ),
          ),
        );
      },
    );
  }
}

/// One “label pill + tall card” block (toast-style skeleton row).
final class AppSkeletonToastBlock extends StatelessWidget {
  const AppSkeletonToastBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSkeletonGradientBox(width: 120, height: 14, borderRadius: 8),
        const SizedBox(height: 10),
        const AppSkeletonGradientBox(
          width: double.infinity,
          height: 72,
          borderRadius: 14,
        ),
      ],
    );
  }
}

/// List-row placeholder: leading square + two lines (gradient shimmer).
final class AppSkeletonListRowGradient extends StatelessWidget {
  const AppSkeletonListRowGradient({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppSkeletonGradientBox(
            width: 48,
            height: 48,
            borderRadius: 12,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppSkeletonGradientBox(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 8,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.58,
                    child: const AppSkeletonGradientBox(
                      width: double.infinity,
                      height: 13,
                      borderRadius: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layout preset for [AppSkeletonScreenBody].
enum AppSkeletonScreenBodyStyle {
  /// Stacked “pill + card” blocks (generic detail / form loading).
  toastBlocks,

  /// Repeated list rows (lists, directories, CRM tables).
  listRows,
}

/// Default full-screen (or scroll-region) loading placeholder using gradient shimmer.
///
/// Use while fetching initial data: `body: loading ? AppSkeletonScreenBody(...) : content`.
/// Set [scrollable] to `false` for simple `Scaffold` bodies that are not inside a scroll view.
final class AppSkeletonScreenBody extends StatelessWidget {
  const AppSkeletonScreenBody({
    super.key,
    this.style = AppSkeletonScreenBodyStyle.toastBlocks,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
    this.scrollable = true,
    this.physics,
    this.toastBlockCount = 3,
    this.listRowCount = 8,
    this.spacing = 24,
  });

  final AppSkeletonScreenBodyStyle style;
  final EdgeInsets padding;
  final bool scrollable;
  final ScrollPhysics? physics;
  final int toastBlockCount;
  final int listRowCount;
  final double spacing;

  List<Widget> _children() {
    switch (style) {
      case AppSkeletonScreenBodyStyle.toastBlocks:
        final n = toastBlockCount.clamp(1, 12);
        return [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            const AppSkeletonToastBlock(),
          ],
        ];
      case AppSkeletonScreenBodyStyle.listRows:
        final n = listRowCount.clamp(1, 24);
        return [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            const AppSkeletonListRowGradient(),
          ],
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: _children(),
    );

    final padded = Padding(padding: padding, child: column);

    if (!scrollable) {
      return padded;
    }

    return SingleChildScrollView(
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      child: padded,
    );
  }
}

/// Project / job card placeholder matching technician list cards.
final class AppSkeletonProjectCard extends StatelessWidget {
  const AppSkeletonProjectCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppSkeletonGradientBox(
                  width: double.infinity,
                  height: 22,
                  borderRadius: 8,
                ),
              ),
              SizedBox(width: 10),
              AppSkeletonGradientBox(width: 72, height: 22, borderRadius: 6),
            ],
          ),
          SizedBox(height: 12),
          AppSkeletonGradientBox(width: 200, height: 14, borderRadius: 8),
          SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: AppSkeletonGradientBox(width: 88, height: 16, borderRadius: 8),
          ),
        ],
      ),
    );
  }
}

/// Search + filter chips + stacked project cards (technician projects tab).
final class AppSkeletonProjectsListBody extends StatelessWidget {
  const AppSkeletonProjectsListBody({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(18, 8, 18, 20),
    this.cardCount = 4,
    this.includeSearchAndFilters = true,
  });

  final EdgeInsets padding;
  final int cardCount;
  final bool includeSearchAndFilters;

  @override
  Widget build(BuildContext context) {
    final n = cardCount.clamp(1, 8);
    return ListView(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        if (includeSearchAndFilters) ...[
          const AppSkeletonGradientBox(
            width: double.infinity,
            height: 48,
            borderRadius: 13,
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              AppSkeletonGradientBox(width: 56, height: 38, borderRadius: 999),
              SizedBox(width: 10),
              AppSkeletonGradientBox(width: 72, height: 38, borderRadius: 999),
              SizedBox(width: 10),
              AppSkeletonGradientBox(width: 96, height: 38, borderRadius: 999),
            ],
          ),
          const SizedBox(height: 18),
        ],
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          const AppSkeletonProjectCard(),
        ],
      ],
    );
  }
}
