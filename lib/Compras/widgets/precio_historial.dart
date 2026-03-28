import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PrecioHistorial {
  static const String keyHistorial = "historial_precios";

  static Future<List<Map<String, dynamic>>> obtenerHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(keyHistorial);

    if (data == null) return [];

    List decoded = jsonDecode(data);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> guardarPrecio(String valor) async {
    if (valor.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> historial = await obtenerHistorial();

    int index = historial.indexWhere((e) => e["valor"] == valor);

    if (index != -1) {
      historial[index]["count"] += 1;
    } else {
      historial.add({"valor": valor, "count": 1});
    }

    historial.sort((a, b) => b["count"].compareTo(a["count"]));

    if (historial.length > 15) {
      historial = historial.sublist(0, 15);
    }

    await prefs.setString(keyHistorial, jsonEncode(historial));
  }
}
