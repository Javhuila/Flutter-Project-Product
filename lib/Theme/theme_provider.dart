import 'package:flutter/material.dart';
import 'package:flutter_project_product/Theme/catalogo_color.dart';
import 'package:flutter_project_product/Theme/tamano_fuente.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _modoOscuro = false;
  ColorCatalogo _catalogo = ColorCatalogo.azul;
  FontSizeOption _fontSize = FontSizeOption.medium;

  bool get modoOscuro => _modoOscuro;
  ColorCatalogo get catalogo => _catalogo;
  FontSizeOption get fontSize => _fontSize;

  ThemeData get currentTheme {
    ThemeData baseTheme = _modoOscuro
        ? PaletasDeColores.getDarkTheme(_catalogo)
        : PaletasDeColores.getLightTheme(_catalogo);

    final baseFontSize = _fontSize.baseSize;

    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.copyWith(
        titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
          fontSize: baseFontSize + 4,
        ),
        titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
          fontSize: baseFontSize + 2,
        ),
        bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
          fontSize: baseFontSize,
        ),
        bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
          fontSize: baseFontSize - 2,
        ),
      ),
    );
  }

  ThemeProvider() {
    _cargarPreferencias();
  }

  void toggleModoOscuro(bool value) async {
    _modoOscuro = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modoOscuro', value);
  }

  void setCatalogo(ColorCatalogo nuevoCatalogo) async {
    _catalogo = nuevoCatalogo;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('catalogoIndex', nuevoCatalogo.index);
  }

  void setFontSize(FontSizeOption newSize) async {
    _fontSize = newSize;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontSize', newSize.name);
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    _modoOscuro = prefs.getBool('modoOscuro') ?? false;
    int index = prefs.getInt('catalogoIndex') ?? 0;
    _catalogo = ColorCatalogo.values[index];

    final storedFontSize = prefs.getString('fontSize');
    if (storedFontSize != null) {
      _fontSize = FontSizeOption.values.firstWhere(
        (f) => f.name == storedFontSize,
        orElse: () => FontSizeOption.medium,
      );
    }

    notifyListeners();
  }
}
