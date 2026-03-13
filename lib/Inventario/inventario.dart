import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Inventario/add_product_inventario.dart';
import 'package:flutter_project_product/Service/Cloudinary/image_upload_service.dart';
import 'package:flutter_project_product/Layout/ini_layout.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Inventario extends StatefulWidget {
  const Inventario({super.key});

  @override
  State<Inventario> createState() => _InventarioState();
}

class _InventarioState extends State<Inventario> {
  final String fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<DocumentSnapshot> productosSeleccionados = [];

  String? _userRole;
  bool _cargando = true;

  final Set<String> _fechasExpandidasCompletas = {};

  Map<String, bool> _modoSeleccionPorFecha = {};
  Map<String, Set<String>> _seleccionadosPorFecha = {};

  @override
  void initState() {
    super.initState();
    _inicializarInventario();
  }

  Future<void> _inicializarInventario() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    await _loadUserRole();
    await _crearInventarioDelDia();
    _precacheImagenes();
    await _aplicarPoliticaRetencionInventario();
    await _actualizarVentasYResiduos();

    if (!mounted) return;
    setState(() => _cargando = false);
  }

  Future<void> _loadUserRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        setState(() {
          _userRole = doc['role'];
          _cargando = false;
        });
      } else {
        setState(() {
          _userRole = 'asistente'; // fallback
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        _userRole = 'asistente'; // fallback en caso de error
        _cargando = false;
      });
    }
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
    final firestore = FirebaseFirestore.instance;
    final fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final inventarioRef = firestore.collection('inventario').doc(fechaHoy);

    final doc = await inventarioRef.get();
    if (!doc.exists) {
      await inventarioRef.set({'fecha': fechaHoy}, SetOptions(merge: true));
      debugPrint("Inventario del día $fechaHoy creado correctamente.");
    } else {
      debugPrint("Inventario del día $fechaHoy ya existe.");
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

    final snapshot = await FirebaseFirestore.instance
        .collection('inventario')
        .get();

    for (var doc in snapshot.docs) {
      final fechaDoc = _parseFecha(doc.id);
      if (fechaDoc == null) continue;

      if (fechaDoc.isBefore(limite)) {
        await doc.reference.delete();
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

  Future<int> _obtenerVentasDelDia(String nombreProducto) async {
    final firestore = FirebaseFirestore.instance;

    // Rango de tiempo del día actual (00:00:00 - 23:59:59)
    final now = DateTime.now();
    final inicioDelDia = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final finDelDia = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Busca pedidos creados hoy (usando rango de fechas)
    final pedidosSnapshot = await firestore
        .collection('pedidos')
        .where('fecha', isGreaterThanOrEqualTo: inicioDelDia)
        .where('fecha', isLessThanOrEqualTo: finDelDia)
        .get();

    int totalVentas = 0;

    for (var pedido in pedidosSnapshot.docs) {
      final productos = List<Map<String, dynamic>>.from(pedido['productos']);
      for (var p in productos) {
        if (p['nombre'] == nombreProducto) {
          totalVentas += (p['cantidad'] ?? 0) as int;
        }
      }
    }

    return totalVentas;
  }

  /// Actualiza automáticamente los campos "venta" y "residuo"
  Future<void> _actualizarVentasYResiduos() async {
    final inventarioRef = FirebaseFirestore.instance
        .collection('inventario')
        .doc(fechaHoy)
        .collection('productos');

    final snapshot = await inventarioRef.get();

    for (var prod in snapshot.docs) {
      final data = prod.data();
      final cantidad = (data['cantidad'] ?? 0) as int;
      final nombre = data['nombre'] ?? '';

      final venta = await _obtenerVentasDelDia(nombre);
      final residuo = cantidad - venta;

      await prod.reference.update({
        'venta': venta,
        'residuo': residuo < 0 ? 0 : residuo,
      });
    }
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

    // Parseamos la fecha a DateTime para armar el rango del día
    final fechaBase = DateTime.tryParse(fecha);
    if (fechaBase == null) return;

    final inicioDelDia = DateTime(
      fechaBase.year,
      fechaBase.month,
      fechaBase.day,
      0,
      0,
      0,
    );
    final finDelDia = DateTime(
      fechaBase.year,
      fechaBase.month,
      fechaBase.day,
      23,
      59,
      59,
    );

    final pedidosSnapshot = await firestore
        .collection('pedidos')
        .where('fecha', isGreaterThanOrEqualTo: inicioDelDia)
        .where('fecha', isLessThanOrEqualTo: finDelDia)
        .get();

    double total = 0;
    int cantidadTotal = 0;

    for (var pedido in pedidosSnapshot.docs) {
      final productos = List<Map<String, dynamic>>.from(pedido['productos']);

      for (var p in productos) {
        if (p['nombre'] == nombreProducto) {
          final precio = (p['precio'] ?? 0).toDouble();
          final cantidad = (p['cantidad'] ?? 0) as int;
          total += precio * cantidad;
          cantidadTotal += cantidad;
        }
      }
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Total vendido de $nombreProducto"),
        content: Text(
          "Cantidad total vendida: $cantidadTotal\n"
          "Suma total: \$${total.toStringAsFixed(2)}",
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
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
    final snapshot = await FirebaseFirestore.instance
        .collection('inventario')
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
          futures.add(CustomCacheManager.instance.downloadFile(imageUrl));
          contador++;
        }
      }
    }
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventario"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const IniLayout()),
              (route) => false,
            );
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
                        builder: (context) => const AddProductInventario(),
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
                  ],
                ),
              )
            : Column(),
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
                  setState(() {}); // actualiza filtro en tiempo real
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
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('inventario')
                    .orderBy(FieldPath.documentId, descending: true)
                    .limit(7) // muestra solo los últimos 7 días
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
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

                      return StreamBuilder<QuerySnapshot>(
                        stream: inventarioDoc.reference
                            .collection('productos')
                            .snapshots(),
                        builder: (context, productoSnapshot) {
                          if (!productoSnapshot.hasData) {
                            return const SizedBox();
                          }

                          final productos = productoSnapshot.data!.docs;
                          final filtro = _searchController.text
                              .trim()
                              .toLowerCase();

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
                              key: PageStorageKey(fecha),
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
                                                              CustomCacheManager
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

class CustomCacheManager {
  static const key = 'customCacheKey';

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
