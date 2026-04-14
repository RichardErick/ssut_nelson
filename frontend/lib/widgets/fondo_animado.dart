import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _animations;
  final int _blobCount = 5;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _blobCount,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(seconds: 10 + _random.nextInt(10)),
      )..repeat(reverse: true),
    );

    _animations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: Offset(_random.nextDouble() * 2 - 1, _random.nextDouble() * 2 - 1),
        end: Offset(_random.nextDouble() * 2 - 1, _random.nextDouble() * 2 - 1),
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOutSine));
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Base
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade700,
                const Color(0xFF0D47A1),
              ],
            ),
          ),
        ),
        // Animated Blobs
        ...List.generate(_blobCount, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Positioned(
                left: MediaQuery.of(context).size.width * 0.5 +
                    (_animations[index].value.dx * MediaQuery.of(context).size.width * 0.4),
                top: MediaQuery.of(context).size.height * 0.5 +
                    (_animations[index].value.dy * MediaQuery.of(context).size.height * 0.4),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.blue.shade400.withOpacity(0.3),
                        Colors.blue.shade900.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
        // Content
        widget.child,
      ],
    );
  }
}
