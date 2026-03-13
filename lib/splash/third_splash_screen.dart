import 'package:flutter/material.dart';
import 'package:flutter_project_product/splash/logo_painter.dart';

class ThirdSplashScreen extends StatefulWidget {
  final AnimationController controller;
  const ThirdSplashScreen({super.key, required this.controller});

  @override
  State<ThirdSplashScreen> createState() => _ThirdSplashScreenState();
}

class _ThirdSplashScreenState extends State<ThirdSplashScreen>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (_, _) {
            return CustomPaint(
              size: const Size(300, 300),
              painter: LogoPainter(widget.controller.value),
            );
          },
        ),
      ),
    );
  }
}
// images/logo_android_3.svg