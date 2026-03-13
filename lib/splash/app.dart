import 'package:flutter/material.dart';
import 'package:flutter_project_product/Service/auth_wrapper.dart';
import 'package:flutter_project_product/Theme/theme_provider.dart';
import 'package:flutter_project_product/splash/app_data.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({required this.data, super.key});

  final AppData data;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // ThemeMode themeMode = ThemeMode.system;

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      themeMode: themeProvider.modoOscuro ? ThemeMode.dark : ThemeMode.light,
      home: const AuthWrapper(),
    );
  }
}
