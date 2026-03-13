import 'dart:async';

import 'package:flutter/material.dart';

class SecondSplashScreen extends StatefulWidget {
  const SecondSplashScreen({super.key});

  @override
  State<SecondSplashScreen> createState() => _SecondSplashScreenState();
}

class _SecondSplashScreenState extends State<SecondSplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _opacity = 0);
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() => _opacity = 1);
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _opacity = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 700),
          child: Image.asset('images/built_with_flutter.png', height: 100),
        ),
      ),
    );
  }
}
