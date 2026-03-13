import 'package:flutter/material.dart';
// import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_project_product/splash/app.dart';
import 'package:flutter_project_product/splash/app_data.dart';
import 'package:flutter_project_product/splash/second_splash_screen.dart';
import 'package:flutter_project_product/splash/third_splash_screen.dart';

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with TickerProviderStateMixin {
  final _data = ValueNotifier<AppData?>(null);

  // 0 = Third
  // 1 = Second
  // 2 = App
  int _stage = 0;

  late final AnimationController _logoController;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    _startFlow();
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _loader ??= _load(context);
  // }

  Future<void> _startFlow() async {
    // ---------- LOGO ----------
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 5500));

    setState(() => _stage = 1);

    // ---------- FLUTTER ----------
    await Future.delayed(const Duration(milliseconds: 3500));

    setState(() => _stage = 2);

    // ---------- APP ----------
    _data.value = const AppData();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _data.dispose();
    super.dispose();
  }

  // Future<void> _load(BuildContext context) async {
  //   await Future<void>.delayed(const Duration(milliseconds: 1850));

  //   _data.value = const AppData();

  //   SchedulerBinding.instance.addPostFrameCallback((_) {
  //     _controller.forward().ignore();
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          // clipBehavior: Clip.none,
          children: [
            // ---------- APP ----------
            if (_stage == 2 && _data.value != null) App(data: _data.value!),

            // ---------- SECOND SPLASH ----------
            if (_stage == 1) const SecondSplashScreen(),

            // ---------- THIRD SPLASH ----------
            if (_stage == 0) ThirdSplashScreen(controller: _logoController),
            // ValueListenableBuilder(
            //   valueListenable: _data,
            //   builder: (context, data, _) {
            //     if (data == null) {
            //       return const SizedBox.shrink();
            //     }
            //     return App(data: data);
            //   },
            // ),
            // ValueListenableBuilder(
            //   valueListenable: _isSplashScreenVisible,
            //   builder: (context, isSplashScreenVisible, splashScreen) {
            //     if (isSplashScreenVisible) {
            //       return splashScreen!;
            //     }

            //     return const SizedBox.shrink();
            //   },
            //   child: ThirdSplashScreen(controller: _controller),
            // ),
          ],
        ),
      ),
    );
  }
}
