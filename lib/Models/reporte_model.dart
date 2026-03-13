import 'package:cloud_firestore/cloud_firestore.dart';

class ReporteModel {
  final List<DocumentSnapshot> pedidos;

  ReporteModel(this.pedidos);

  /// Productos más vendidos por cantidad
  Map<String, int> getTopProductosVendidos({int top = 5}) {
    final Map<String, int> productos = {};

    for (final doc in pedidos) {
      final data = doc.data() as Map<String, dynamic>;
      final productosPedido = List<Map<String, dynamic>>.from(
        data['productos'] ?? [],
      );

      for (final prod in productosPedido) {
        final nombre = prod['nombre'];
        final cantidad = prod['cantidad'];

        final cantidadInt = (cantidad is int)
            ? cantidad
            : (cantidad is double)
            ? cantidad.toInt()
            : int.tryParse(cantidad.toString()) ?? 0;

        productos[nombre] = (productos[nombre] ?? 0) + cantidadInt;
      }
    }

    final ordenado = productos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(ordenado.take(top));
  }

  /// Clientes que más compraron (por valor total)
  Map<String, double> getTopClientesConMayorCompra({int top = 5}) {
    final Map<String, double> clientes = {};

    for (final doc in pedidos) {
      final data = doc.data() as Map<String, dynamic>;
      final cliente = data['cliente'] ?? 'Desconocido';
      final total = (data['valor_total'] ?? 0);

      final totalDouble = (total is int)
          ? total.toDouble()
          : (total is double)
          ? total
          : double.tryParse(total.toString()) ?? 0.0;

      clientes[cliente] = (clientes[cliente] ?? 0) + totalDouble;
    }

    final ordenado = clientes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(ordenado.take(top));
  }

  /// Fechas con más pedidos
  Map<String, int> getFechasMasActivas({int top = 4}) {
    final Map<String, int> fechas = {};

    for (final doc in pedidos) {
      final data = doc.data() as Map<String, dynamic>;
      DateTime fechaPedido;

      if (data['fecha'] is Timestamp) {
        fechaPedido = (data['fecha'] as Timestamp).toDate();
      } else if (data['fecha'] is DateTime) {
        fechaPedido = data['fecha'] as DateTime;
      } else {
        // si está como String, intentar parsear
        fechaPedido =
            DateTime.tryParse(data['fecha'].toString()) ?? DateTime.now();
      }

      // Formatear fecha a string legible, mismo estilo que usas en Pedidos
      final clave =
          "${fechaPedido.day.toString().padLeft(2, '0')}/"
          "${fechaPedido.month.toString().padLeft(2, '0')}/"
          "${fechaPedido.year}";

      fechas[clave] = (fechas[clave] ?? 0) + 1;
    }

    final ordenado = fechas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(ordenado.take(top));
  }

  /// Categorías y sus productos más solicitados
  Future<Map<String, Map<String, int>>> getTopCategoriasConProductos({
    int topCategorias = 4,
    int topProductos = 3,
  }) async {
    final Map<String, Map<String, int>> categoriasMap = {};

    for (final doc in pedidos) {
      final data = doc.data() as Map<String, dynamic>;
      final productos = List<Map<String, dynamic>>.from(
        data['productos'] ?? [],
      );

      for (final p in productos) {
        final productId = p['id'];
        final cantidadRaw = p['cantidad'] ?? 0;

        final cantidadInt = (cantidadRaw is int)
            ? cantidadRaw
            : (cantidadRaw is double)
            ? cantidadRaw.toInt()
            : int.tryParse(cantidadRaw.toString()) ?? 0;

        // Buscar categoría del producto
        final productoSnap = await FirebaseFirestore.instance
            .collection('productos')
            .doc(productId)
            .get();
        final categoria = productoSnap.data()?['categoria'] ?? 'Sin categoría';
        final nombre = p['nombre'];

        categoriasMap.putIfAbsent(categoria, () => {});
        categoriasMap[categoria]![nombre] =
            (categoriasMap[categoria]![nombre] ?? 0) + cantidadInt;
      }
    }

    final categoriasOrdenadas = categoriasMap.entries.toList()
      ..sort((a, b) {
        final sumaA = a.value.values.fold<int>(0, (sumC, v) => sumC + v);
        final sumaB = b.value.values.fold<int>(0, (sumD, v) => sumD + v);
        return sumaB.compareTo(sumaA);
      });

    final resultado = <String, Map<String, int>>{};
    for (final cat in categoriasOrdenadas.take(topCategorias)) {
      final topProds = cat.value.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      resultado[cat.key] = Map.fromEntries(topProds.take(topProductos));
    }

    return resultado;
  }
}
