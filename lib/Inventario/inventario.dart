import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Inventario/add_product_inventario.dart';
import 'package:flutter_project_product/Service/Cloudinary/image_upload_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Utils/Constans/app_constants.dart';

class Inventario extends StatefulWidget {
  final String inventarioId;
  final String nombreInventario;

  const Inventario({
    super.key,
    required this.inventarioId,
    required this.nombreInventario,
  });

  @override
  State<Inventario> createState() => _InventarioState();
}

class _InventarioState extends State<Inventario> {
  DocumentReference<Map<String, dynamic>> get _inventarioRef =>
      FirebaseFirestore.instance
          .collection('inventarios')
          .doc(widget.inventarioId);

  CollectionReference<Map<String, dynamic>> get _fechasRef =>
      _inventarioRef.collection('fechas');

  final String fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<DocumentSnapshot> productosSeleccionados = [];

  String? uid;
  String? adminId;
  String? _userRole;
  bool _cargando = true;
  String _textoBusqueda = '';
  Timer? _debounce;
  final Set<String> _fechasExpandidasCompletas = {};
  bool _mostrarPrecioEmpresa = false;
  final Map<String, bool> _modoSeleccionPorFecha = {};
  final Map<String, Set<String>> _seleccionadosPorFecha = {};

  @override
  void initState() {
    super.initState();
    _inicializarInventario();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _inicializarInventario() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    await _cargarDatosUsuario();
    await _crearInventarioDelDia();
    _precacheImagenes();
    await _aplicarPoliticaRetencionInventario();
    await _actualizarVentasYResiduos();
    await _cargarConfiguracionInventario();

    if (!mounted) return;
    setState(() => _cargando = false);
  }

  Future<void> _cargarDatosUsuario() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    uid = user.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      _userRole = 'asistente';
      adminId = user.uid;
      return;
    }

    final data = doc.data()!;

    _userRole = data['role'] ?? 'asistente';

    adminId = data['adminId'] ?? user.uid;
  }

  bool _esHoy(String fecha) {
    final hoy = DateTime.now();
    final partes = fecha.split('-'); // Ajusta al formato que uses
    final fechaDato = DateTime(
      int.parse(partes[0]),
      int.parse(partes[1]),
      int.parse(partes[2]),
    );

    return fechaDato.year == hoy.year &&
        fechaDato.month == hoy.month &&
        fechaDato.day == hoy.day;
  }

  Future<void> _crearInventarioDelDia() async {
    final fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fechaRef = _fechasRef.doc(fechaHoy);

    final doc = await fechaRef.get();
    if (!doc.exists) {
      await fechaRef.set({
        'fecha': fechaHoy,
        'adminId': adminId,
        'fechaCreacion': Timestamp.now(),
      });

      debugPrint(
        'Inventario "${widget.nombreInventario}" del día '
        '$fechaHoy creado correctamente.',
      );
    } else {
      debugPrint(
        'Inventario "${widget.nombreInventario}" del día '
        '$fechaHoy ya existe.',
      );
    }
  }

  DateTime? _parseFecha(String fecha) {
    try {
      final parts = fecha.split('-');

      if (parts.length != 3) return null;

      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _aplicarPoliticaRetencionInventario() async {
    final prefs = await SharedPreferences.getInstance();
    final dias = prefs.getInt('dias_retenidos_inventario') ?? 7;
    await _eliminarInventariosAntiguos(dias);
  }

  Future<void> _eliminarInventariosAntiguos(int dias) async {
    final ahora = DateTime.now();
    final limite = ahora.subtract(Duration(days: dias));
    final adminIdActual = adminId;

    if (adminIdActual == null || adminIdActual.isEmpty) {
      return;
    }
    final inventariosSnapshot = await FirebaseFirestore.instance
        .collection('inventarios')
        .where('adminId', isEqualTo: adminIdActual)
        .get();

    for (final inventarioDoc in inventariosSnapshot.docs) {
      final fechasSnapshot = await inventarioDoc.reference
          .collection('fechas')
          .get();

      for (final fechaDoc in fechasSnapshot.docs) {
        final fecha = _parseFecha(fechaDoc.id);

        if (fecha == null) continue;

        if (fecha.isBefore(limite)) {
          await fechaDoc.reference.delete();

          debugPrint(
            'Fecha antigua eliminada: '
            '${fechaDoc.id} '
            'del inventario ${inventarioDoc.id}',
          );
        }
      }
    }
  }

  void _mostrarDialogoRetencionInventario() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final prefs = await SharedPreferences.getInstance();
    int diasActuales = prefs.getInt('dias_retenidos_inventario') ?? 7;

    if (!mounted) return;

    int? nuevoValor = await showDialog<int>(
      context: context,
      builder: (context) {
        int valorTemp = diasActuales;

        return AlertDialog(
          title: const Text("Días de retención de Inventario"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    min: 1,
                    max: 7,
                    divisions: 6,
                    value: valorTemp.toDouble(),
                    label: "$valorTemp días",
                    onChanged: (double newVal) {
                      setState(() {
                        valorTemp = newVal.toInt();
                      });
                    },
                  ),
                  Text("Mantener datos de inventario por $valorTemp días"),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => navigator.pop(),
            ),
            ElevatedButton(
              child: const Text("Guardar"),
              onPressed: () => navigator.pop(valorTemp),
            ),
          ],
        );
      },
    );

    if (nuevoValor != null) {
      await prefs.setInt('dias_retenidos_inventario', nuevoValor);

      messenger.showSnackBar(
        SnackBar(content: Text("Inventario se mantendrá por $nuevoValor días")),
      );

      await _eliminarInventariosAntiguos(nuevoValor);
      setState(() {});
    }
  }

  Future<void> _cargarConfiguracionInventario() async {
    final doc = await FirebaseFirestore.instance
        .collection('inventarios')
        .doc(widget.inventarioId)
        .get();

    if (!doc.exists) return;

    final data = doc.data();

    if (!mounted) return;

    setState(() {
      _mostrarPrecioEmpresa = data?['mostrarPrecioEmpresa'] == true;
    });
  }

  Future<void> _actualizarMostrarPrecioEmpresa(bool valor) async {
    setState(() {
      _mostrarPrecioEmpresa = valor;
    });

    try {
      await FirebaseFirestore.instance
          .collection('inventarios')
          .doc(widget.inventarioId)
          .update({'mostrarPrecioEmpresa': valor});
    } catch (e) {
      debugPrint('Error al actualizar mostrarPrecioEmpresa: $e');

      if (!mounted) return;

      // Si falla la actualización en Firestore,
      // restauramos el valor anterior.
      setState(() {
        _mostrarPrecioEmpresa = !valor;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar la configuración del inventario.',
          ),
        ),
      );
    }
  }

  /// Actualiza automáticamente los campos "venta" y "residuo"
  Future<void> _actualizarVentasYResiduos() async {
    final firestore = FirebaseFirestore.instance;

    final inventarioRef = _fechasRef.doc(fechaHoy).collection('productos');

    // Obtenemos las ventas y los productos en paralelo.
    final ventasFuture = _obtenerVentasAgrupadas();
    final productosFuture = inventarioRef.get();

    final resultados = await Future.wait([ventasFuture, productosFuture]);

    final ventas = resultados[0] as Map<String, int>;
    final snapshot = resultados[1] as QuerySnapshot<Map<String, dynamic>>;

    if (snapshot.docs.isEmpty) return;

    // Preparamos únicamente los documentos que necesitan cambios.
    final productosPorActualizar =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    final valoresActualizados = <String, Map<String, int>>{};

    for (final producto in snapshot.docs) {
      final data = producto.data();

      final cantidad = (data['cantidad'] as num?)?.toInt() ?? 0;
      final nombre = data['nombre']?.toString() ?? '';

      final venta = ventas[nombre] ?? 0;

      final residuoCalculado = cantidad - venta;
      final residuo = residuoCalculado < 0 ? 0 : residuoCalculado;

      // Comprobamos si los valores guardados ya son correctos.
      final ventaActual = (data['venta'] as num?)?.toInt();
      final residuoActual = (data['residuo'] as num?)?.toInt();

      // Si no hay cambios, evitamos una escritura innecesaria.
      if (ventaActual == venta && residuoActual == residuo) {
        continue;
      }

      productosPorActualizar.add(producto);

      valoresActualizados[producto.id] = {'venta': venta, 'residuo': residuo};
    }

    // Si todos los documentos están actualizados, terminamos.
    if (productosPorActualizar.isEmpty) return;

    // Firestore permite hasta 500 operaciones de escritura
    // por lote. Procesamos los productos en grupos de 500.
    const limitePorLote = 500;

    for (
      var inicio = 0;
      inicio < productosPorActualizar.length;
      inicio += limitePorLote
    ) {
      final fin = (inicio + limitePorLote).clamp(
        0,
        productosPorActualizar.length,
      );

      final batch = firestore.batch();

      for (var i = inicio; i < fin; i++) {
        final producto = productosPorActualizar[i];
        final valores = valoresActualizados[producto.id]!;

        batch.update(producto.reference, valores);
      }

      await batch.commit();
    }

    debugPrint(
      'Inventario actualizado: '
      '${productosPorActualizar.length} productos modificados.',
    );
  }

  Future<void> _editarCantidad(
    DocumentSnapshot producto,
    String idProducto,
  ) async {
    final controller = TextEditingController(
      text: producto['cantidad'].toString(),
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Editar cantidad"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Nueva cantidad"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevaCantidad = int.tryParse(controller.text.trim()) ?? 0;
              final navigator = Navigator.of(context);
              await producto.reference.update({'cantidad': nuevaCantidad});
              await _actualizarVentasYResiduos();

              navigator.pop();
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarTotalVentas(
    String nombreProducto, {
    String? fechaSeleccionada,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final fecha = fechaSeleccionada ?? fechaHoy;
    final mostrarPrecioEmpresa = _mostrarPrecioEmpresa;
    // Parseamos la fecha a DateTime para armar el rango del día
    final fechaBase = DateTime.tryParse(fecha);
    if (fechaBase == null) return;

    final inicioDelDia = DateTime(
      fechaBase.year,
      fechaBase.month,
      fechaBase.day,
    );
    final inicioDelDiaSiguiente = DateTime(
      fechaBase.year,
      fechaBase.month,
      fechaBase.day + 1,
    );

    try {
      // Consultamos todos los pedidos del día seleccionado.
      final pedidosSnapshot = await firestore
          .collection('pedidos')
          .where('fecha', isGreaterThanOrEqualTo: inicioDelDia)
          .where('fecha', isLessThan: inicioDelDiaSiguiente)
          .get();

      double total = 0;
      double totalPE = 0;
      int cantidadTotal = 0;

      // Acumulamos las cantidades vendidas por ID de producto.
      // Así evitamos consultar varias veces el mismo documento.
      final cantidadesPorProductoId = <String, int>{};

      for (final pedido in pedidosSnapshot.docs) {
        final productosPedido = pedido.data()['productos'];

        if (productosPedido is! List) continue;

        for (final elemento in productosPedido) {
          if (elemento is! Map) continue;

          final producto = Map<String, dynamic>.from(elemento);

          if (producto['nombre'] != nombreProducto) {
            continue;
          }

          final precio = (producto['precio'] as num?)?.toDouble() ?? 0.0;

          final cantidad = (producto['cantidad'] as num?)?.toInt() ?? 0;

          total += precio * cantidad;
          cantidadTotal += cantidad;

          // Solo necesitamos los documentos de productos cuando
          // está activado el cálculo del precio de empresa.
          if (!mostrarPrecioEmpresa) continue;

          final productoId = producto['id']?.toString();

          if (productoId == null || productoId.isEmpty) {
            continue;
          }

          cantidadesPorProductoId.update(
            productoId,
            (cantidadAnterior) => cantidadAnterior + cantidad,
            ifAbsent: () => cantidad,
          );
        }
      }

      if (mostrarPrecioEmpresa && cantidadesPorProductoId.isNotEmpty) {
        // Consultamos en paralelo cada ID único de producto.
        final productosSnapshots = await Future.wait(
          cantidadesPorProductoId.keys.map(
            (productoId) =>
                firestore.collection('productos').doc(productoId).get(),
          ),
        );

        // Guardamos los precios obtenidos para reutilizarlos
        // durante el cálculo, sin volver a leer los documentos.
        final preciosEmpresa = <String, double>{};

        for (final productoSnapshot in productosSnapshots) {
          if (!productoSnapshot.exists) continue;

          final data = productoSnapshot.data();
          if (data == null) continue;

          final precioEmpresa =
              (data['precio_empresa'] as num?)?.toDouble() ?? 0.0;

          preciosEmpresa[productoSnapshot.id] = precioEmpresa;
        }

        for (final entrada in cantidadesPorProductoId.entries) {
          final precioEmpresa = preciosEmpresa[entrada.key];

          if (precioEmpresa == null) continue;

          totalPE += precioEmpresa * entrada.value;
        }
      }

      if (!mounted) return;

      final texto = StringBuffer();

      if (mostrarPrecioEmpresa) {
        texto.writeln(
          'Cantidad total vendida de la empresa: '
          '\$${AppConstants.formatearMoneda(totalPE)}',
        );
      }

      texto.writeln('Cantidad total vendida: $cantidadTotal');

      texto.writeln('Suma total: \$${AppConstants.formatearMoneda(total)}');

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Total vendido de $nombreProducto'),
          content: Text(texto.toString(), style: const TextStyle(fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error al calcular las ventas de $nombreProducto: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron calcular las ventas del producto.'),
        ),
      );
    }
  }

  Future<void> _mostrarResumenFecha(String fecha) async {
    final firestore = FirebaseFirestore.instance;

    final fechaBase = DateTime.tryParse(fecha);
    if (fechaBase == null) return;

    final mostrarPrecioEmpresa = _mostrarPrecioEmpresa;

    final inicioDelDia = DateTime(
      fechaBase.year,
      fechaBase.month,
      fechaBase.day,
    );

    final inicioDelDiaSiguiente = DateTime(
      fechaBase.year,
      fechaBase.month,
      fechaBase.day + 1,
    );

    try {
      // Iniciamos ambas consultas al mismo tiempo.
      final productosInventarioFuture = _fechasRef
          .doc(fecha)
          .collection('productos')
          .get();

      final pedidosFuture = firestore
          .collection('pedidos')
          .where('fecha', isGreaterThanOrEqualTo: inicioDelDia)
          .where('fecha', isLessThan: inicioDelDiaSiguiente)
          .get();

      // Esperamos a que ambas consultas terminen.
      final resultados = await Future.wait([
        productosInventarioFuture,
        pedidosFuture,
      ]);

      final productosSnapshot = resultados[0];

      final pedidosSnapshot = resultados[1];

      final productosInventario = productosSnapshot.docs;

      // Nombres de los productos pertenecientes al inventario
      // y a la fecha seleccionada.
      final nombresProductos = <String>{};

      for (final producto in productosInventario) {
        final nombre = producto.data()['nombre']?.toString();

        if (nombre != null && nombre.isNotEmpty) {
          nombresProductos.add(nombre);
        }
      }

      double totalVenta = 0;

      // Acumulamos las cantidades por ID de producto.
      // Esto permite consultar cada documento una sola vez,
      // aunque el producto aparezca en varios pedidos.
      final cantidadesPorProductoId = <String, int>{};

      for (final pedido in pedidosSnapshot.docs) {
        final productosPedido = pedido.data()['productos'];

        if (productosPedido is! List) continue;

        for (final elemento in productosPedido) {
          if (elemento is! Map) continue;

          final producto = Map<String, dynamic>.from(elemento);

          final nombre = producto['nombre']?.toString();

          // Solo contamos productos que pertenecen al inventario
          // de la fecha seleccionada.
          if (nombre == null || !nombresProductos.contains(nombre)) {
            continue;
          }

          final precio = (producto['precio'] as num?)?.toDouble() ?? 0.0;

          final cantidad = (producto['cantidad'] as num?)?.toInt() ?? 0;

          totalVenta += precio * cantidad;

          // Si el cálculo del precio de empresa está desactivado,
          // no necesitamos consultar los documentos de productos.
          if (!mostrarPrecioEmpresa) continue;

          final productoId = producto['id']?.toString();

          if (productoId == null || productoId.isEmpty) {
            continue;
          }

          cantidadesPorProductoId.update(
            productoId,
            (cantidadAnterior) => cantidadAnterior + cantidad,
            ifAbsent: () => cantidad,
          );
        }
      }

      double totalEmpresa = 0;

      if (mostrarPrecioEmpresa && cantidadesPorProductoId.isNotEmpty) {
        // Consultamos en paralelo cada documento único de producto.
        final productosEmpresaSnapshots = await Future.wait(
          cantidadesPorProductoId.keys.map(
            (productoId) =>
                firestore.collection('productos').doc(productoId).get(),
          ),
        );

        // Reutilizamos los resultados obtenidos para calcular
        // el total de empresa sin volver a consultar documentos.
        final preciosEmpresa = <String, double>{};

        for (final productoSnapshot in productosEmpresaSnapshots) {
          if (!productoSnapshot.exists) continue;

          final data = productoSnapshot.data();
          if (data == null) continue;

          final precioEmpresa =
              (data['precio_empresa'] as num?)?.toDouble() ?? 0.0;

          preciosEmpresa[productoSnapshot.id] = precioEmpresa;
        }

        for (final entrada in cantidadesPorProductoId.entries) {
          final precioEmpresa = preciosEmpresa[entrada.key];

          if (precioEmpresa == null) continue;

          totalEmpresa += precioEmpresa * entrada.value;
        }
      }

      if (!mounted) return;

      final fechaFormateada = DateFormat('dd/MM/yyyy').format(fechaBase);

      final texto = StringBuffer();

      texto.writeln('Fecha: $fechaFormateada');
      texto.writeln('Cantidad de productos: ${productosInventario.length}');
      texto.writeln();

      texto.writeln(
        'Suma total de venta: '
        '\$${AppConstants.formatearMoneda(totalVenta)}',
      );

      if (mostrarPrecioEmpresa) {
        texto.writeln(
          'Suma total de empresa: '
          '\$${AppConstants.formatearMoneda(totalEmpresa)}',
        );
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Resumen'),
          content: Text(texto.toString(), style: const TextStyle(fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error al mostrar el resumen de fecha: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cargar el resumen de la fecha seleccionada.',
          ),
        ),
      );
    }
  }

  Future<void> _seleccionarFechaResumen() async {
    final snapshot = await _fechasRef
        .orderBy(FieldPath.documentId, descending: true)
        .get();

    if (!mounted) return;

    final fechas = snapshot.docs.map((doc) => doc.id).toList();

    if (fechas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay fechas de inventario disponibles.'),
        ),
      );
      return;
    }

    final fechaSeleccionada = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Seleccionar fecha'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fechas.length,
              itemBuilder: (context, index) {
                final fecha = fechas[index];
                final fechaDateTime = DateTime.tryParse(fecha);

                final fechaTexto = fechaDateTime != null
                    ? DateFormat('dd/MM/yyyy').format(fechaDateTime)
                    : fecha;

                return ListTile(
                  leading: Icon(
                    fecha == fechaHoy
                        ? Icons.calendar_today
                        : Icons.calendar_month,
                  ),
                  title: Text(fechaTexto),
                  subtitle: fecha == fechaHoy ? const Text('Hoy') : null,
                  onTap: () {
                    Navigator.pop(dialogContext, fecha);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (fechaSeleccionada == null || !mounted) return;

    await _mostrarResumenFecha(fechaSeleccionada);
  }

  Future<void> _eliminarSeleccionados(
    String fecha,
    DocumentReference inventarioRef,
  ) async {
    final seleccionados = _seleccionadosPorFecha[fecha];

    if (seleccionados == null || seleccionados.isEmpty) return;

    for (var id in seleccionados) {
      await inventarioRef.collection('productos').doc(id).delete();
    }

    setState(() {
      _seleccionadosPorFecha[fecha]?.clear();
      _modoSeleccionPorFecha[fecha] = false;
    });
  }

  Future<void> _eliminarTodos(
    DocumentReference inventarioRef,
    String fecha,
  ) async {
    final snapshot = await inventarioRef.collection('productos').get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    setState(() {
      _seleccionadosPorFecha[fecha]?.clear();
      _modoSeleccionPorFecha[fecha] = false;
    });
  }

  void _mostrarDialogoEliminar(
    BuildContext context,
    DocumentReference inventarioRef,
    String fecha,
    bool eliminarTodo,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmar eliminación"),
        content: Text(
          eliminarTodo
              ? "¿Seguro que deseas eliminar TODOS los productos de esta fecha?"
              : "¿Seguro que deseas eliminar los productos seleccionados?",
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.pop(context);

              if (eliminarTodo) {
                await _eliminarTodos(inventarioRef, fecha);
              } else {
                await _eliminarSeleccionados(fecha, inventarioRef);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _precacheImagenes() async {
    final snapshot = await _fechasRef
        .orderBy(FieldPath.documentId, descending: true)
        .limit(7)
        .get();

    final futures = <Future>[];

    for (var doc in snapshot.docs) {
      final productos = await doc.reference.collection('productos').get();

      int contador = 0;
      for (var producto in productos.docs) {
        if (contador >= 30) break;

        final imageUrl = producto['imagen'];

        if (imageUrl != null && imageUrl.isNotEmpty) {
          futures.add(CustomCacheManagerInv.instance.downloadFile(imageUrl));
          contador++;
        }
      }
    }
    await Future.wait(futures);
  }

  Future<Map<String, int>> _obtenerVentasAgrupadas() async {
    final firestore = FirebaseFirestore.instance;

    // Rango de tiempo del día actual (00:00:00 - 23:59:59)
    final now = DateTime.now();

    final inicioDelDia = DateTime(now.year, now.month, now.day);

    final finDelDia = DateTime(now.year, now.month, now.day, 23, 59, 59);
    // Busca pedidos creados hoy (usando rango de fechas)
    final pedidosSnapshot = await firestore
        .collection('pedidos')
        .where('fecha', isGreaterThanOrEqualTo: inicioDelDia)
        .where('fecha', isLessThanOrEqualTo: finDelDia)
        .get();

    final Map<String, int> ventas = {};

    for (var pedido in pedidosSnapshot.docs) {
      final productos = List<Map<String, dynamic>>.from(pedido['productos']);

      for (var p in productos) {
        final nombre = p['nombre'];

        ventas[nombre] = (ventas[nombre] ?? 0) + ((p['cantidad'] ?? 0) as int);
      }
    }

    return ventas;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreInventario),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: _userRole == 'admin'
            ? [
                IconButton(
                  icon: const Icon(Icons.checklist_rtl_sharp),
                  tooltip: "Agregar productos",
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddProductInventario(
                          inventarioId: widget.inventarioId,
                          nombreInventario: widget.nombreInventario,
                        ),
                      ),
                    );
                    setState(() {});
                  },
                ),
              ]
            : [],
      ),
      drawer: Drawer(
        child: _userRole == 'admin'
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Column(
                  children: [
                    Text("CONFIGURACIONES"),
                    SizedBox(height: 10),
                    Divider(),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _mostrarDialogoRetencionInventario,
                          label: Text("Configurar retencion"),
                          icon: Icon(Icons.settings),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text('Mostrar precio empresa'),
                      value: _mostrarPrecioEmpresa,
                      onChanged: _actualizarMostrarPrecioEmpresa,
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _seleccionarFechaResumen,
                      icon: const Icon(Icons.summarize_outlined),
                      label: const Text('Resumen de ventas por fecha'),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: Column(
                  children: [
                    Text("Inventario", style: TextStyle(fontSize: 40)),
                  ],
                ),
              ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(vertical: 10, horizontal: 25),
          child: Column(
            children: [
              SizedBox(height: 20),
              TextFormField(
                controller: _searchController,
                keyboardType: TextInputType.name,
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    if (!mounted) return;

                    setState(() {
                      _textoBusqueda = value;
                    });
                  });
                },
                style: const TextStyle(
                  fontSize: 20,
                  overflow: TextOverflow.ellipsis,
                ),
                decoration: InputDecoration(
                  labelText: "Buscar",
                  hintText: "Buscar productos",
                  suffixIcon: const Icon(Icons.search_outlined, size: 40),
                  suffixIconColor: Colors.grey,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Colors.grey),
                    gapPadding: 10,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Colors.grey),
                    gapPadding: 10,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Colors.red, width: 2.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: Colors.deepOrange,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _fechasRef
                    .orderBy(FieldPath.documentId, descending: true)
                    .limit(7) // muestra solo los últimos 7 días
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error al cargar inventarios:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final inventarios = snapshot.data!.docs;

                  return ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: inventarios.length,
                    itemBuilder: (context, index) {
                      final inventarioDoc = inventarios[index];
                      final fecha =
                          inventarioDoc.id; // nombre del documento = fecha
                      final bool abierto = fecha == hoy;

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: inventarioDoc.reference
                            .collection('productos')
                            .snapshots(),
                        builder: (context, productoSnapshot) {
                          if (!productoSnapshot.hasData) {
                            return const SizedBox();
                          }

                          final productos = productoSnapshot.data!.docs;
                          final filtro = _textoBusqueda.trim().toLowerCase();

                          final filtrados = productos.where((p) {
                            final nombre = (p['nombre'] ?? '')
                                .toString()
                                .toLowerCase();
                            return filtro.isEmpty || nombre.contains(filtro);
                          }).toList();

                          if (filtrados.isEmpty) {
                            return const SizedBox();
                          }

                          final bool mostrarTodos = _fechasExpandidasCompletas
                              .contains(fecha);

                          final List productosAMostrar =
                              (filtrados.length > 9 && !mostrarTodos)
                              ? filtrados.take(9).toList()
                              : filtrados;

                          final bool necesitaBoton =
                              filtrados.length > 9 && !mostrarTodos;

                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ExpansionTile(
                              key: PageStorageKey(
                                '${widget.inventarioId}_$fecha',
                              ),
                              initiallyExpanded: abierto,
                              leading: Icon(
                                _esHoy(fecha)
                                    ? Icons.calendar_today
                                    : Icons.calendar_month,
                                size: 20,
                              ),
                              title: Row(
                                children: [
                                  // FECHA (izquierda)
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      fecha,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // ICONO (centro)
                                  _userRole == 'admin'
                                      ? Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: IconButton(
                                              icon: Icon(
                                                _modoSeleccionPorFecha[fecha] ==
                                                        true
                                                    ? Icons.close
                                                    : Icons
                                                          .check_circle_outline,
                                                color:
                                                    _modoSeleccionPorFecha[fecha] ==
                                                        true
                                                    ? Colors.red
                                                    : Theme.of(
                                                        context,
                                                      ).primaryColor,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _modoSeleccionPorFecha[fecha] =
                                                      !(_modoSeleccionPorFecha[fecha] ??
                                                          false);

                                                  _seleccionadosPorFecha
                                                      .putIfAbsent(
                                                        fecha,
                                                        () => <String>{},
                                                      );
                                                });
                                              },
                                            ),
                                          ),
                                        )
                                      : Container(),

                                  // CONTADOR (derecha)
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          filtrados.isEmpty
                                              ? "Sin productos"
                                              : "${filtrados.length}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              children: [
                                ...productosAMostrar.map((producto) {
                                  final nombre =
                                      producto['nombre'] ?? 'Sin nombre';
                                  final imageUrl =
                                      producto['imagen'] as String?;
                                  final cantidad = producto['cantidad'] ?? 0;
                                  final venta = producto['venta'] ?? 0;
                                  final residuo = producto['residuo'] ?? 0;

                                  final bool modoSeleccion =
                                      _modoSeleccionPorFecha[fecha] == true;

                                  final bool estaSeleccionado =
                                      _seleccionadosPorFecha[fecha]?.contains(
                                        producto.id,
                                      ) ??
                                      false;

                                  final dpr = MediaQuery.of(
                                    context,
                                  ).devicePixelRatio;

                                  return GestureDetector(
                                    onTap: () {
                                      if (modoSeleccion) {
                                        setState(() {
                                          final seleccionados =
                                              _seleccionadosPorFecha
                                                  .putIfAbsent(
                                                    fecha,
                                                    () => <String>{},
                                                  );

                                          if (estaSeleccionado) {
                                            seleccionados.remove(producto.id);
                                          } else {
                                            seleccionados.add(producto.id);
                                          }
                                        });
                                      } else if (_userRole == 'admin') {
                                        _editarCantidad(producto, producto.id);
                                      }
                                    },
                                    child: Card(
                                      color: estaSeleccionado
                                          ? Colors.red.withValues(alpha: 0.2)
                                          : null,

                                      margin: const EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 10,
                                      ),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                imageUrl != null &&
                                                        imageUrl.isNotEmpty
                                                    ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        child: CachedNetworkImage(
                                                          key: ValueKey(
                                                            producto.id,
                                                          ),
                                                          cacheKey:
                                                              'producto_${producto.id}',
                                                          filterQuality:
                                                              FilterQuality.low,
                                                          imageUrl:
                                                              getOptimizedCloudinaryUrl(
                                                                imageUrl,
                                                              ),
                                                          placeholder: (_, _) =>
                                                              const SizedBox(
                                                                width: 60,
                                                                height: 60,
                                                                child: Center(
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                                ),
                                                              ),
                                                          errorWidget:
                                                              (
                                                                _,
                                                                _,
                                                                _,
                                                              ) => const Icon(
                                                                Icons
                                                                    .broken_image,
                                                                size: 60,
                                                              ),
                                                          width: 60,
                                                          height: 60,
                                                          fadeInDuration:
                                                              const Duration(
                                                                milliseconds:
                                                                    150,
                                                              ),
                                                          fadeOutDuration:
                                                              const Duration(
                                                                milliseconds:
                                                                    100,
                                                              ),
                                                          memCacheWidth:
                                                              (60 * dpr)
                                                                  .toInt(),
                                                          memCacheHeight:
                                                              (60 * dpr)
                                                                  .toInt(),
                                                          useOldImageOnUrlChange:
                                                              true,
                                                          cacheManager:
                                                              CustomCacheManagerInv
                                                                  .instance,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        size: 60,
                                                      ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          nombre,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16,
                                                              ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons
                                                              .price_check_rounded,
                                                          size: 34,
                                                        ),
                                                        onPressed: () =>
                                                            _mostrarTotalVentas(
                                                              nombre,
                                                              fechaSeleccionada:
                                                                  fecha,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 15,
                                              children: [
                                                Text("Cantidad: $cantidad"),
                                                Text("Venta: $venta"),
                                                Text("Residuo: $residuo"),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                if (necesitaBoton)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Center(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _fechasExpandidasCompletas.add(
                                              fecha,
                                            );
                                          });
                                        },
                                        icon: const Icon(Icons.expand_more),
                                        label: Text(
                                          "Cargar ${filtrados.length - 9} más",
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_modoSeleccionPorFecha[fecha] == true)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 15,
                                    ),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            _mostrarDialogoEliminar(
                                              context,
                                              inventarioDoc.reference,
                                              fecha,
                                              false,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text(
                                            "Eliminar seleccionados",
                                          ),
                                        ),

                                        OutlinedButton.icon(
                                          onPressed: () {
                                            _mostrarDialogoEliminar(
                                              context,
                                              inventarioDoc.reference,
                                              fecha,
                                              true,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.delete_forever,
                                            color: Colors.red,
                                          ),
                                          label: const Text(
                                            "Eliminar todos",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomCacheManagerInv {
  static const key = 'customCacheKey8';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
