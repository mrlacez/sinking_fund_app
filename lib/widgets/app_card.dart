import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Theme.of(context).cardColor;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _PressableCard(
          color: cardColor,
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;

  const _PressableCard({
    required this.child,
    required this.color,
    this.onTap,
  });

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;
  late final Animation<double> _scale;

  final _radius = BorderRadius.circular(16);
  bool _hovered = false; // ✅ moved here

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  void _onTapDown(TapDownDetails _) {
    if (_controller.isAnimating) _controller.stop();
    _controller.reverse();
  }

  void _onTapUp(TapUpDetails _) {
    if (mounted) _controller.forward();
  }

  void _onTapCancel() {
    if (mounted) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Material(
        clipBehavior: Clip.antiAlias, // 🔥 prevent ripple bleed
        color: widget.color,
        elevation: 2,
        borderRadius: _radius,
        child: InkWell(
          borderRadius: _radius,
          onTap: widget.onTap,
          onHover: (v) {
            if (_hovered != v) {
              setState(() => _hovered = v);
            }
          },
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: _radius,
              border: _hovered
                  ? Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(.2),
              )
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}