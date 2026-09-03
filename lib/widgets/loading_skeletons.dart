import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const <Color>[
            Color(0xFF2D2E30),
            Color(0xFF3E4042),
            Color(0xFF2D2E30),
          ]
        : const <Color>[
            Color(0xFFE6EBF2),
            Color(0xFFF9FAFB),
            Color(0xFFE6EBF2),
          ];

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final width = bounds.width <= 0 ? 1.0 : bounds.width;
            return LinearGradient(
              colors: gradientColors,
              stops: const <double>[0.22, 0.5, 0.78],
              begin: const Alignment(-1.0, -1.0),
              end: const Alignment(1.0, 1.0),
              transform: _SlidingGradientTransform(_controller.value),
            ).createShader(
              Rect.fromLTWH(0, 0, width, bounds.height <= 0 ? 1.0 : bounds.height),
            );
          },
          child: child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final double xTranslation = bounds.width * (slidePercent * 2 - 1);
    final double yTranslation = bounds.width * (slidePercent * 2 - 1) * 0.45;
    return Matrix4.translationValues(xTranslation, yTranslation, 0);
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 12,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2E30) : const Color(0xFFE6EBF2),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class PostSkeletonCard extends StatelessWidget {
  const PostSkeletonCard({
    this.variant = 0,
    super.key,
  });

  final int variant;

  @override
  Widget build(BuildContext context) {
    final normalizedVariant = variant % 4;
    final nameWidth = switch (normalizedVariant) {
      0 => 132.0,
      1 => 104.0,
      2 => 148.0,
      _ => 118.0,
    };
    final metaWidth = switch (normalizedVariant) {
      0 => 84.0,
      1 => 62.0,
      2 => 96.0,
      _ => 74.0,
    };
    final lineTwoWidth = switch (normalizedVariant) {
      0 => 248.0,
      1 => 212.0,
      2 => 272.0,
      _ => 186.0,
    };
    final lineThreeWidth = switch (normalizedVariant) {
      0 => 158.0,
      1 => 136.0,
      2 => 192.0,
      _ => 124.0,
    };
    final mediaHeight = switch (normalizedVariant) {
      0 => 220.0,
      1 => 248.0,
      2 => 192.0,
      _ => 234.0,
    };
    final topRightChipWidth = switch (normalizedVariant) {
      0 => 56.0,
      1 => 72.0,
      2 => 48.0,
      _ => 64.0,
    };
    final actionOneWidth = switch (normalizedVariant) {
      0 => 68.0,
      1 => 76.0,
      2 => 60.0,
      _ => 84.0,
    };
    final actionTwoWidth = switch (normalizedVariant) {
      0 => 78.0,
      1 => 66.0,
      2 => 88.0,
      _ => 72.0,
    };
    final actionThreeWidth = switch (normalizedVariant) {
      0 => 64.0,
      1 => 54.0,
      2 => 70.0,
      _ => 62.0,
    };

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SkeletonPulse(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  SkeletonBox(
                    width: normalizedVariant == 2 ? 42 : 44,
                    height: normalizedVariant == 2 ? 42 : 44,
                    radius: normalizedVariant == 2 ? 21 : 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: nameWidth, height: 14, radius: 7),
                        const SizedBox(height: 8),
                        SkeletonBox(width: metaWidth, height: 11, radius: 6),
                      ],
                    ),
                  ),
                  SkeletonBox(
                    width: normalizedVariant == 1 ? 18 : 22,
                    height: normalizedVariant == 1 ? 18 : 22,
                    radius: normalizedVariant == 1 ? 9 : 11,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SkeletonBox(width: double.infinity, height: 13, radius: 7),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SkeletonBox(width: lineTwoWidth, height: 12, radius: 7),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SkeletonBox(width: lineThreeWidth, height: 12, radius: 7),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: mediaHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2D2E30)
                    : const Color(0xFFE6EBF2),
                borderRadius: BorderRadius.zero,
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 12),
                  child: SkeletonBox(
                    width: topRightChipWidth,
                    height: 18,
                    radius: 9,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Row(
                children: [
                  SkeletonBox(width: actionOneWidth, height: 18, radius: 9),
                  const SizedBox(width: 12),
                  SkeletonBox(width: actionTwoWidth, height: 18, radius: 9),
                  const SizedBox(width: 12),
                  SkeletonBox(width: actionThreeWidth, height: 18, radius: 9),
                  const Spacer(),
                  SkeletonBox(
                    width: normalizedVariant == 3 ? 22 : 24,
                    height: normalizedVariant == 3 ? 22 : 24,
                    radius: normalizedVariant == 3 ? 11 : 12,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(
              height: 1,
              thickness: 0.5,
              color: Color(0x14111827),
            ),
          ],
        ),
      ),
    );
  }
}

class StorySkeletonRow extends StatelessWidget {
  const StorySkeletonRow({
    this.count = 5,
    super.key,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 102.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) => SizedBox(width: 4.w),
        itemBuilder: (context, index) {
          final avatarSize = 72.w;
          final labelWidth = switch (index % 4) {
            0 => 62.w,
            1 => 50.w,
            2 => 56.w,
            _ => 44.w,
          };

          return SkeletonPulse(
            child: SizedBox(
              width: 82.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    padding: EdgeInsets.all(2.5.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3E4042)
                            : const Color(0xFFE5E7EB),
                        width: 2.w,
                      ),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(2.r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: ClipOval(
                        child: SkeletonBox(
                          width: avatarSize,
                          height: avatarSize,
                          radius: avatarSize / 2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  SkeletonBox(width: labelWidth, height: 10.h, radius: 5.r),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({
    this.hasBackButton = true,
    this.hasActions = true,
    super.key,
  });

  final bool hasBackButton;
  final bool hasActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SkeletonPulse(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mock App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      if (hasBackButton) ...[
                        const SkeletonBox(width: 32, height: 32, radius: 8),
                        const SizedBox(width: 12),
                      ],
                      const SkeletonBox(width: 120, height: 20, radius: 10),
                      const Spacer(),
                      const SkeletonBox(width: 32, height: 32, radius: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Profile Header (Avatar + Stats)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const SkeletonBox(width: 86, height: 86, radius: 43),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(3, (index) => const Column(
                            children: [
                              SkeletonBox(width: 38, height: 16, radius: 8),
                              SizedBox(height: 6),
                              SkeletonBox(width: 54, height: 10, radius: 5),
                            ],
                          )),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Display Name
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SkeletonBox(width: 140, height: 16, radius: 8),
                ),
                const SizedBox(height: 8),
                // Bio lines
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 260, height: 12, radius: 6),
                      SizedBox(height: 6),
                      SkeletonBox(width: 180, height: 12, radius: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Metadata
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      SkeletonBox(width: 16, height: 16, radius: 8),
                      SizedBox(width: 8),
                      SkeletonBox(width: 100, height: 12, radius: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Action Buttons (Follow / Message)
                if (hasActions) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: const SkeletonBox(width: double.infinity, height: 38, radius: 8)),
                        const SizedBox(width: 8),
                        Expanded(child: const SkeletonBox(width: double.infinity, height: 38, radius: 8)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Tab Bar Mock
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (index) => SkeletonBox(
                      width: index == 0 ? 56 : 48,
                      height: 18,
                      radius: 9,
                    )),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.5, color: Color(0x14111827)),
                const SizedBox(height: 16),
                // Mock Posts List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 2,
                  itemBuilder: (context, index) => PostSkeletonCard(variant: index),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

