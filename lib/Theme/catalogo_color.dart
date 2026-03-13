import 'package:flutter/material.dart';

enum ColorCatalogo { azul, rojo, verde, amarillo }

class PaletasDeColores {
  // Seccion Azul
  static const azulPrimario = Color(0xFF0077B6);
  static const azulClaro = Color(0xFF90E0EF);
  static const azulFuerte = Color(0xFF03045E);
  static const celeste = Color(0xFF48CAE4);
  static const celesteClaro = Color(0xFFCAF0F8);
  static const celesteSuave = Color(0xFFADE8F4);
  static const azulMedio = Color(0xFF0096C7);
  static const azulVibrante = Color(0xFF00B4D8);
  static const azulOscuro = Color(0xFF023E8A);

  // Seccion Amarillo
  static const amarilloClaro = Color(0xFFFFFF00);
  static const amarilloMedio = Color(0xFFFFEE00);
  static const amarilloDorado = Color(0xFFFFD900);
  static const amarilloAnaranjado = Color(0xFFFFC300);
  static const naranjaSuave = Color(0xFFFFAD00);
  static const naranja = Color(0xFFFF9500);
  static const naranjaFuerte = Color(0xFFFF7D00);
  static const naranjaOscuro = Color(0xFFFF6500);
  static const naranjaProfundo = Color(0xFFFF4C00);
  static const rojoAnaranjado = Color(0xFFFF3300);
  static const rojoFuerte = Color(0xFFFF1A00);
  static const rojo = Color(0xFFFF0000);

  // Seccion Rojo
  static const rojoOscuro1 = Color(0xFF820000);
  static const rojoOscuro2 = Color(0xFF9A0000);
  static const rojoMedio1 = Color(0xFFB30000);
  static const rojoMedio2 = Color(0xFFCD0000);
  static const rojoBrillante = Color(0xFFE70000);
  static const rojoBase = Color(0xFFFF0000);
  static const rojoClaro1 = Color(0xFFFF1818);
  static const rojoClaro2 = Color(0xFFFF3232);
  static const rojoSuave = Color(0xFFF84848);

  // Seccion Verde
  static const verdeOscuro1 = Color(0xFF003E00);
  static const verdeOscuro2 = Color(0xFF005D00);
  static const verdeMedio1 = Color(0xFF007200);
  static const verdeBase = Color(0xFF008000);
  static const verdeMedio2 = Color(0xFF009100);
  static const verdeClaro1 = Color(0xFF00A600);
  static const verdeClaro2 = Color(0xFF47B947);

  // Sombreado
  static Color getShadowColor(ColorCatalogo catalogo, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final alpha = isDark ? 0.3 : 0.5;

    switch (catalogo) {
      case ColorCatalogo.azul:
        return azulPrimario.withValues(alpha: alpha);
      case ColorCatalogo.rojo:
        return rojoOscuro1.withValues(alpha: alpha);
      case ColorCatalogo.verde:
        return verdeOscuro1.withValues(alpha: alpha);
      case ColorCatalogo.amarillo:
        return naranjaOscuro.withValues(alpha: alpha);
    }
  }

  // Fondo de Container
  static Color getContainerColor(
    ColorCatalogo catalogo,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;

    switch (catalogo) {
      case ColorCatalogo.azul:
        return isDark ? azulOscuro : celesteClaro;
      case ColorCatalogo.rojo:
        return isDark ? rojoOscuro2 : rojoClaro2;
      case ColorCatalogo.verde:
        return isDark ? verdeOscuro2 : verdeClaro2;
      case ColorCatalogo.amarillo:
        return isDark ? naranjaOscuro : amarilloClaro;
    }
  }

  // Icono de usuario Admin - Asistente
  static Color getColorIconoUsuario({
    required bool esAdmin,
    required ThemeData theme,
    required Color backgroundReal,
  }) {
    final bool isDark = theme.brightness == Brightness.dark;

    if (esAdmin) {
      return isDark
          ? theme.colorScheme.primary.withValues(alpha: 0.95)
          : theme.colorScheme.onBackground.withValues(alpha: 0.85);
    } else {
      return isDark
          ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
          : theme.colorScheme.onBackground.withValues(alpha: 0.7);
    }
  }

  // Icono de Entrega (Entregado - No entregado)
  static Color getColorIconoEntrega({
    required bool entregado,
    required ThemeData theme,
  }) {
    final bool isDark = theme.brightness == Brightness.dark;

    if (entregado) {
      return isDark
          ? theme.colorScheme.primary.withValues(alpha: 0.95)
          : theme.colorScheme.onSurface.withValues(alpha: 0.75);
    } else {
      return isDark
          ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
          : theme.colorScheme.primary.withValues(alpha: 0.6);
    }
  }

  static ThemeData getLightTheme(ColorCatalogo catalogo) {
    if (catalogo == ColorCatalogo.azul) {
      const colorScheme = ColorScheme(
        brightness: Brightness.light,
        primary: azulPrimario,
        onPrimary: Colors.white,
        secondary: celeste,
        onSecondary: Colors.black,
        surface: celesteClaro,
        onSurface: azulFuerte,
        // surface: celesteSuave,
        // onSurface: azulFuerte,
        error: Colors.red,
        onError: Colors.white,
        // Nuevo
        scrim: azulFuerte,
        surfaceContainerHighest: azulOscuro,
      );

      return ThemeData(
        brightness: Brightness.light,
        primaryColor: colorScheme.primary,
        scaffoldBackgroundColor: colorScheme.background,
        colorScheme: colorScheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: azulPrimario,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: azulOscuro,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: azulFuerte),
        textTheme: Typography.blackMountainView,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: celeste,
          foregroundColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azulPrimario,
            foregroundColor: Colors.white,
          ),
        ),
      );
    } else if (catalogo == ColorCatalogo.amarillo) {
      const colorScheme = ColorScheme(
        brightness: Brightness.light,
        primary: amarilloDorado,
        onPrimary: Colors.black,
        secondary: naranja,
        onSecondary: Colors.black,
        background: amarilloClaro,
        onBackground: Colors.black,
        surface: amarilloMedio,
        onSurface: Colors.black,
        error: rojo,
        onError: Colors.white,
      );

      return ThemeData(
        brightness: Brightness.light,
        primaryColor: colorScheme.primary,
        scaffoldBackgroundColor: colorScheme.background,
        colorScheme: colorScheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: amarilloDorado,
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: naranjaProfundo,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: colorScheme.onBackground),
        textTheme: Typography.blackMountainView,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: naranja,
          foregroundColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: amarilloDorado,
            foregroundColor: Colors.black,
          ),
        ),
      );
    } else if (catalogo == ColorCatalogo.rojo) {
      const colorScheme = ColorScheme(
        brightness: Brightness.light,
        primary: rojoBase,
        onPrimary: Colors.white,
        secondary: rojoClaro1,
        onSecondary: Colors.white,
        background: rojoSuave,
        onBackground: Colors.white,
        surface: rojoClaro2,
        onSurface: Colors.white,
        error: Colors.deepOrange,
        onError: Colors.white,
      );
      return ThemeData(
        brightness: Brightness.light,
        primaryColor: colorScheme.primary,
        scaffoldBackgroundColor: colorScheme.background,
        colorScheme: colorScheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: rojoBase,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: rojoOscuro2,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: colorScheme.onBackground),
        textTheme: Typography.whiteMountainView,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: rojoClaro1,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: rojoBase,
            foregroundColor: Colors.white,
          ),
        ),
      );
    } else if (catalogo == ColorCatalogo.verde) {
      const colorScheme = ColorScheme(
        brightness: Brightness.light,
        primary: verdeBase,
        onPrimary: Colors.white,
        secondary: verdeClaro2,
        onSecondary: Colors.black,
        background: verdeClaro1,
        onBackground: Colors.black,
        surface: verdeMedio2,
        onSurface: Colors.black,
        error: Colors.red,
        onError: Colors.white,
      );
      return ThemeData(
        brightness: Brightness.light,
        primaryColor: colorScheme.primary,
        scaffoldBackgroundColor: colorScheme.background,
        colorScheme: colorScheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: verdeBase,
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: verdeOscuro2,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
        iconTheme: IconThemeData(color: colorScheme.onBackground),
        textTheme: Typography.blackMountainView,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: verdeClaro2,
          foregroundColor: Colors.black,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: verdeBase,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    return ThemeData.light();
  }

  static ThemeData getDarkTheme(ColorCatalogo catalogo) {
    if (catalogo == ColorCatalogo.azul) {
      const colorScheme = ColorScheme(
        brightness: Brightness.dark,
        primary: azulClaro,
        onPrimary: Colors.black,
        secondary: azulVibrante,
        onSecondary: Colors.black,
        background: azulFuerte,
        onBackground: Colors.white,
        surface: azulOscuro,
        onSurface: Colors.white,
        error: Colors.redAccent,
        onError: Colors.black,
      );

      return ThemeData(
        brightness: Brightness.dark,
        primaryColor: colorScheme.primary,
        scaffoldBackgroundColor: colorScheme.background,
        colorScheme: colorScheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: azulOscuro,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: azulFuerte,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        textTheme: Typography.whiteMountainView,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: azulVibrante,
          foregroundColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azulClaro,
            foregroundColor: Colors.black,
          ),
        ),
      );
    } else if (catalogo == ColorCatalogo.amarillo) {
      const colorScheme = ColorScheme(
        brightness: Brightness.dark,
        primary: amarilloMedio,
        onPrimary: Colors.black,
        secondary: naranjaFuerte,
        onSecondary: Colors.white,
        background: rojoAnaranjado,
        onBackground: Colors.white,
        surface: naranjaOscuro,
        onSurface: Colors.white,
        error: rojoFuerte,
        onError: Colors.black,
      );

      return ThemeData(
        brightness: Brightness.dark,
        primaryColor: colorScheme.primary,
        scaffoldBackgroundColor: colorScheme.background,
        colorScheme: colorScheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: naranjaOscuro,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: rojoFuerte,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        textTheme: Typography.whiteMountainView,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: naranjaFuerte,
          foregroundColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: amarilloMedio,
            foregroundColor: Colors.black,
          ),
        ),
      );
    } else if (catalogo == ColorCatalogo.rojo) {
      const colorScheme = ColorScheme(
        brightness: Brightness.dark,
        primary: rojoClaro1,
        onPrimary: Colors.white,
        secondary: rojoClaro2,
        onSecondary: Colors.black,
        background: rojoOscuro2,
        onBackground: Colors.white,
        surface: rojoOscuro1,
        onSurface: Colors.white,
        error: Colors.deepOrangeAccent,
        onError: Colors.white,
      );

      return ThemeData(
        brightness: Brightness.dark,
        primaryColor: colorScheme.primary,
        scaffoldBackgroundColor: colorScheme.background,
        colorScheme: colorScheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: rojoOscuro2,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: rojoOscuro1,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        textTheme: Typography.whiteMountainView,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: rojoClaro1,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: rojoClaro2,
            foregroundColor: Colors.white,
          ),
        ),
      );
    } else if (catalogo == ColorCatalogo.verde) {
      const colorScheme = ColorScheme(
        brightness: Brightness.dark,
        primary: verdeClaro1,
        onPrimary: Colors.black,
        secondary: verdeClaro2,
        onSecondary: Colors.black,
        background: verdeOscuro2,
        onBackground: Colors.white,
        surface: verdeOscuro1,
        onSurface: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
      );

      return ThemeData(
        brightness: Brightness.dark,
        primaryColor: colorScheme.primary,
        scaffoldBackgroundColor: colorScheme.background,
        colorScheme: colorScheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: verdeOscuro1,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: verdeOscuro2,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        textTheme: Typography.whiteMountainView,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: verdeClaro2,
          foregroundColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: verdeClaro1,
            foregroundColor: Colors.black,
          ),
        ),
      );
    }
    return ThemeData.dark();
  }
}
