import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PrecioHistorial {
  static Future<List<Map<String, dynamic>>> obtenerHistorial(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);

    if (data == null) return [];

    List decoded = jsonDecode(data);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> guardarPrecio(String key, String valor) async {
    if (valor.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> historial = await obtenerHistorial(key);

    int index = historial.indexWhere((e) => e["valor"] == valor);

    if (index != -1) {
      historial[index]["count"] += 1;
    } else {
      historial.add({"valor": valor, "count": 1});
    }

    historial.sort((a, b) => b["count"].compareTo(a["count"]));

    if (historial.length > 50) {
      historial = historial.sublist(0, 50);
    }

    await prefs.setString(key, jsonEncode(historial));
  }
}
