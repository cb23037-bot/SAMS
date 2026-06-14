import 'package:flutter/material.dart';

// ─── Easing curves ────────────────────────────────────────────────────────────
// Strong ease-out: starts fast, feels instantly responsive
const Curve kEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);
// Strong ease-in-out: natural for on-screen movement
const Curve kEaseInOut = Cubic(0.77, 0.0, 0.175, 1.0);
// iOS drawer feel
const Curve kEaseDrawer = Cubic(0.32, 0.72, 0.0, 1.0);

// ─── Durations ────────────────────────────────────────────────────────────────
const Duration kDurationPress    = Duration(milliseconds: 120);
const Duration kDurationFast     = Duration(milliseconds: 180);
const Duration kDurationMedium   = Duration(milliseconds: 250);
const Duration kDurationSlow     = Duration(milliseconds: 380);

// ─── Pressable — scale(0.97) on tap, like a real button ──────────────────────
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.borderRadius,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: kDurationPress);
    _scale = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: kEaseOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onTap?.call(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ─── FadeSlideIn — fades + slides up on entry ─────────────────────────────────
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offsetY;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 12.0,
    this.duration = kDurationSlow,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.7, curve: kEaseOut)),
    );
    _translateY = Tween<double>(begin: widget.offsetY, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: kEaseOut),
    );

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _translateY.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ─── StaggerList — wraps a list with cascading FadeSlideIn ────────────────────
class StaggerList extends StatelessWidget {
  final List<Widget> children;
  final int startIndex;
  final Duration staggerDelay;
  final Duration baseDelay;

  const StaggerList({
    super.key,
    required this.children,
    this.startIndex = 0,
    this.staggerDelay = const Duration(milliseconds: 55),
    this.baseDelay = const Duration(milliseconds: 80),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.asMap().entries.map((e) {
        final i = e.key + startIndex;
        return FadeSlideIn(
          delay: baseDelay + (staggerDelay * i),
          child: e.value,
        );
      }).toList(),
    );
  }
}

// ─── Shimmer skeleton ─────────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 10,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: Color.lerp(
            const Color(0xFFE8ECF2),
            const Color(0xFFF4F6F9),
            _anim.value,
          ),
        ),
      ),
    );
  }
}

// ─── Page route — slide up with ease-drawer ───────────────────────────────────
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpRoute({required this.page})
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: kDurationSlow,
          reverseTransitionDuration: kDurationMedium,
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: kEaseDrawer,
              reverseCurve: kEaseInOut,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        );
}
