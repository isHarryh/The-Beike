import 'dart:math' as math;
import 'package:flutter/material.dart';

class NetAnimatedWavyBar extends StatefulWidget {
  final double ratio;
  final Color color;
  final double maxWidth;
  final Widget? child;

  const NetAnimatedWavyBar({
    super.key,
    required this.ratio,
    required this.color,
    required this.maxWidth,
    this.child,
  });

  @override
  State<NetAnimatedWavyBar> createState() => _NetAnimatedWavyBarState();
}

class _NetAnimatedWavyBarState extends State<NetAnimatedWavyBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double waveHeight = 2.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // If ratio is 1.0, we pull the base width back slightly to ensure
        // the wave peaks (baseWidth + waveHeight) don't get cut by the container edge.
        final double baseWidth = widget.ratio >= 1.0
            ? (widget.maxWidth - waveHeight)
            : (widget.maxWidth * widget.ratio);

        return ClipPath(
          clipper: _NetWavyRightClipper(
            baseWidth: baseWidth,
            offset: _controller.value,
            waveHeight: waveHeight,
            waveCount: 0.618,
          ),
          child:
              widget.child ??
              Container(width: widget.maxWidth, color: widget.color),
        );
      },
    );
  }
}

class _NetWavyRightClipper extends CustomClipper<Path> {
  final double baseWidth;
  final double waveHeight;
  final double waveCount;
  final double offset;

  _NetWavyRightClipper({
    required this.baseWidth,
    required this.waveHeight,
    required this.waveCount,
    required this.offset,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(baseWidth, 0);

    const double step = 0.5;
    for (double y = 0; y <= size.height; y += step) {
      final double normalizedY = y / size.height;
      final double xOffset =
          math.sin((normalizedY * waveCount + offset) * 2 * math.pi) *
          waveHeight;
      path.lineTo(baseWidth + xOffset, y);
    }

    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_NetWavyRightClipper oldClipper) =>
      oldClipper.offset != offset ||
      oldClipper.baseWidth != baseWidth ||
      oldClipper.waveHeight != waveHeight ||
      oldClipper.waveCount != waveCount;
}
