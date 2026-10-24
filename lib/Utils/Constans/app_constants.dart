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

  static DateTime? parseFecha(String fechaStr) {
    try {
      final fecha = fechaStr.trim();
      final partes = fecha.contains('-') ? fecha.split('-') : fecha.split('/');

      if (partes.length != 3) return null;

      int dia;
      int mes;
      int anio;

      if (fecha.contains('-')) {
        // Formato: yyyy-MM-dd
        anio = int.parse(partes[0]);
        mes = int.parse(partes[1]);
        dia = int.parse(partes[2]);
      } else {
        // Formato: dd/MM/yyyy
        dia = int.parse(partes[0]);
        mes = int.parse(partes[1]);
        anio = int.parse(partes[2]);
      }

      // Evita aceptar fechas inexistentes, como 31/02/2026.
      final resultado = DateTime(anio, mes, dia);

      if (resultado.year != anio ||
          resultado.month != mes ||
          resultado.day != dia) {
        return null;
      }

      return resultado;
    } catch (_) {
      return null;
    }
  }

  static String formatFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year;

    return '$dia/$mes/$anio';
  }

  // Convierte DateTime a yyyy-MM-dd.
  static String formatFechaISO(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year;

    return '$anio-$mes-$dia';
  }

  // Comprueba si una fecha corresponde al día actual.
  static bool esHoy(String fecha) {
    final fechaDato = parseFecha(fecha);

    if (fechaDato == null) return false;

    final hoy = DateTime.now();

    return fechaDato.year == hoy.year &&
        fechaDato.month == hoy.month &&
        fechaDato.day == hoy.day;
  }

  static const formasPago = {
    'entrega': 'Pago por entrega',
    'bancario': 'Pago bancario',
    'cuotas': 'Cuotas',
    'fianza': 'Fianza / Credito',
  };

  static const bancos = ['nequi', 'bancolombia', 'davivienda', 'otro'];
}
