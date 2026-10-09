import 'package:intl/intl.dart';

class AppConstants {
  AppConstants._();

  /// Normaliza texto eliminando acentos y mayúsculas.
  /// Ejemplo: "Café Molido" -> "cafe molido"
  static String normalizeText(String text) {
    const withAccents = 'áàäâãéèëêíìïîóòöôõúùüûñÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuunAAAAAEEEEIIIIOOOOOUUUUN';

    String result = text;
    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }

    return result.toLowerCase().trim();
  }

  static String formatearMoneda(num valor) {
    return NumberFormat('#,##0', 'es_CO').format(valor);
  }

  static String formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final fechaSinHora = DateTime(fecha.year, fecha.month, fecha.day);

    final diferencia = hoy.difference(fechaSinHora).inDays;

    if (diferencia == 0) return 'Hoy';
    if (diferencia == 1) return 'Ayer';

    // Ej: 01 de septiembre de 2025
    return "${fecha.day.toString().padLeft(2, '0')} de "
        "${nombreMes(fecha.month)} de ${fecha.year}";
  }

  static String nombreMes(int mes) {
    const meses = [
      '', // posición 0 vacía para que enero sea índice 1
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return meses[mes];
  }

  static DateTime parseFecha(String fechaStr) {
    final partes = fechaStr.split('/');
    final day = int.parse(partes[0]);
    final month = int.parse(partes[1]);
    final year = int.parse(partes[2]);
    return DateTime(year, month, day);
  }

  static String formatFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year;

    return '$dia/$mes/$anio';
  }

  static const formasPago = {
    'entrega': 'Pago por entrega',
    'bancario': 'Pago bancario',
    'cuotas': 'Cuotas',
    'fianza': 'Fianza / Credito',
  };

  static const bancos = ['nequi', 'bancolombia', 'davivienda', 'otro'];
}
