import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_project_product/Service/Cloudinary/image_upload_service.dart';

import '../Utils/Constans/app_constants.dart';

class AddProductInventario extends StatefulWidget {
  final String inventarioId;
  final String nombreInventario;

  const AddProductInventario({
    super.key,
    required this.inventarioId,
    required this.nombreInventario,
  });

  @override
  State<AddProductInventario> createState() => _AddProductInventarioState();
}

class _AddProductInventarioState extends State<AddProductInventario> {
  String? _userRole;
  bool _isLoadingRole = true;

  Timer? _debounce;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<DocumentSnapshot> _productos = [];
  List<DocumentSnapshot> _productosSeleccionados = [];
  Set<String> _productosAsignadosIds = {};
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 15;
  DocumentSnapshot? _ultimoDocumento;
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _inicializarProductos();
    _loadUserRole();
    // _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) {
        _debounce!.cancel();
      }

      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;

        _searchText = _searchController.text.trim();
        _cargarProductos(reset: true);
      });
    });
  }

  Future<void> _inicializarProductos() async {
    try {
      final asignacionesSnapshot = await FirebaseFirestore.instance
          .collection('inventarios')
          .doc(widget.inventarioId)
          .collection('productos_asignados')
          .get();

      _productosAsignadosIds = asignacionesSnapshot.docs
          .map((doc) => doc.id)
          .toSet();

      await _cargarProductos(reset: true);
    } catch (e) {
      debugPrint('Error al cargar las asignaciones: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al consultar los productos asignados: $e'),
        ),
      );
    }
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
          _isLoadingRole = false;
        });
      } else {
        setState(() {
          _userRole = 'asistente'; // fallback
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      setState(() {
        _userRole = 'asistente'; // fallback en caso de error
        _isLoadingRole = false;
      });
    }
  }

  // Carga inicial o paginada de productos desde Firestore
  Future<void> _cargarProductos({bool reset = false}) async {
    if (_isLoading || (!_hasMore && !reset)) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;

      if (reset) {
        _productos.clear();
        _ultimoDocumento = null;
        _hasMore = true;
      }
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No hay un usuario autenticado.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String adminId = user.uid;

      if (userDoc.exists && userDoc.data()?['adminId'] != null) {
        adminId = userDoc['adminId'].toString();
      }

      final objetivo = _productos.length + _limit;

      while (_productos.length < objetivo && _hasMore) {
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection('productos')
            .where('adminId', isEqualTo: adminId)
            .orderBy('nombre')
            .limit(_limit);

        if (_searchText.isNotEmpty) {
          query = FirebaseFirestore.instance
              .collection('productos')
              .where('adminId', isEqualTo: adminId)
              .where('nombre', isGreaterThanOrEqualTo: _searchText)
              .where('nombre', isLessThanOrEqualTo: '$_searchText\uf8ff')
              .orderBy('nombre')
              .limit(_limit);
        }

        if (_ultimoDocumento != null) {
          query = query.startAfterDocument(_ultimoDocumento!);
        }

        final snapshot = await query.get();

        if (snapshot.docs.isEmpty) {
          _hasMore = false;
          break;
        }

        _ultimoDocumento = snapshot.docs.last;

        if (snapshot.docs.length < _limit) {
          _hasMore = false;
        }

        for (final producto in snapshot.docs) {
          // Si existen asignaciones, solamente permitimos sus productos.
          // Si el conjunto está vacío, se muestran todos.
          if (_productosAsignadosIds.isEmpty ||
              _productosAsignadosIds.contains(producto.id)) {
            _productos.add(producto);
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar productos: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar productos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Detecta si llegamos al final del scroll
  // void _onScroll() {
  //   if (_scrollController.position.pixels ==
  //           _scrollController.position.maxScrollExtent &&
  //       !_isLoading) {
  //     _cargarProductos();
  //   }
  // }

  // Selección y deselección
  void _toggleSeleccion(DocumentSnapshot producto) {
    setState(() {
      if (_productosSeleccionados.contains(producto)) {
        _productosSeleccionados.remove(producto);
      } else {
        _productosSeleccionados.add(producto);
      }
    });
  }

  // Seleccionar o deseleccionar todos
  Future<void> _seleccionarTodos() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Si todos los productos disponibles ya están seleccionados,
      // limpiamos la selección.
      if (_productosSeleccionados.length == _productos.length && !_hasMore) {
        setState(() {
          _productosSeleccionados.clear();
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No hay un usuario autenticado.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String adminId = user.uid;

      if (userDoc.exists && userDoc.data()?['adminId'] != null) {
        adminId = userDoc['adminId'].toString();
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('productos')
          .where('adminId', isEqualTo: adminId)
          .orderBy('nombre')
          .get();

      // Aplicamos la restricción de asignaciones.
      final productosDisponibles = snapshot.docs.where((producto) {
        return _productosAsignadosIds.isEmpty ||
            _productosAsignadosIds.contains(producto.id);
      }).toList();

      if (!mounted) return;

      setState(() {
        _productos
          ..clear()
          ..addAll(productosDisponibles);

        _productosSeleccionados = List.from(productosDisponibles);

        _hasMore = false;
      });
    } catch (e) {
      debugPrint('Error al seleccionar todos los productos: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar productos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _guardarInventario(List<DocumentSnapshot> seleccionados) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (seleccionados.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text("No has seleccionado ningún producto")),
      );
      return;
    }

    // Paso 1: Confirmación del usuario
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar registro"),
        content: Text(
          "¿Deseas registrar ${seleccionados.length} productos en el inventario?",
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => navigator.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Confirmar"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (!mounted) return;

    // Paso 2: Mostrar indicador de carga
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      String adminId = user.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data()?['adminId'] != null) {
        adminId = userDoc['adminId']; // el usuario es asistente
      }

      final firestore = FirebaseFirestore.instance;
      final fechaHoy = AppConstants.formatFechaISO(DateTime.now());

      final inventarioDocRef = firestore
          .collection('inventarios')
          .doc(widget.inventarioId)
          .collection('fechas')
          .doc(fechaHoy);

      final inventarioDoc = await inventarioDocRef.get();

      // Si NO existe el inventario del día → lo creamos con fechas reales
      if (!inventarioDoc.exists) {
        final ahora = Timestamp.now();
        final fechaExpiracion = Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        );

        await inventarioDocRef.set({
          'fecha': fechaHoy,
          'adminId': adminId,
          'fechaCreacion': ahora,
          'fechaExpiracion': fechaExpiracion,
        });
      }

      final productosRef = inventarioDocRef.collection('productos');
      // Paso 3: Guardar productos seleccionados
      for (var prod in seleccionados) {
        final productoRef = productosRef.doc(prod.id);
        final existe = await productoRef.get();

        if (!existe.exists) {
          await productoRef.set({
            'nombre': prod['nombre'] ?? 'Sin nombre',
            'imagen': prod['imagen'] ?? '',
            'cantidad': 0,
            'venta': 0,
            'residuo': 0,
            'adminId': adminId,
          });
        }
      }

      // Paso 4: Cerrar el loader
      navigator.pop();

      // Paso 5: Mostrar SnackBar y redirigir
      messenger.showSnackBar(
        const SnackBar(content: Text("Productos registrados exitosamente")),
      );

      // Espera un poco antes de redirigir
      await Future.delayed(const Duration(milliseconds: 500));

      //  Navigator.pushReplacementNamed(context, '/inventario');
      // O si usas MaterialPageRoute:
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text("Error al guardar productos: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      // Mostramos un loader mientras se carga el rol del usuario
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreInventario),
        actions: _userRole == 'admin'
            ? [
                IconButton(
                  icon: const Icon(Icons.done_all),
                  tooltip: "Seleccionar todos",
                  onPressed: _seleccionarTodos,
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: "Confirmar selección",
                  onPressed: () async {
                    await _guardarInventario(_productosSeleccionados);
                  },
                ),
              ]
            : [],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Campo de búsqueda
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Buscar producto",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),

            // Lista de productos
            if (_isLoading && _productos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_productos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text("No hay productos disponibles")),
              )
            else
              Column(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _productos.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _productos.length) {
                        // Último elemento -> botón o loader
                        if (_isLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (_hasMore) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.expand_more),
                              label: const Text("Cargar más productos"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 14,
                                ),
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                              onPressed: _cargarProductos,
                            ),
                          );
                        } else {
                          return const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Center(child: Text("No hay más productos")),
                          );
                        }
                      }
                      final producto = _productos[index];
                      final nombre = producto['nombre'] ?? 'Sin nombre';
                      final imageUrl = producto['imagen'] as String?;
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final seleccionado = _productosSeleccionados.contains(
                        producto,
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: ListTile(
                          leading: imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: getOptimizedCloudinaryUrl(
                                      imageUrl,
                                    ),
                                    filterQuality: FilterQuality.low,
                                    placeholder: (_, _) => const SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(),
                                    ),
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    fadeInDuration: const Duration(
                                      milliseconds: 150,
                                    ),
                                    fadeOutDuration: const Duration(
                                      milliseconds: 100,
                                    ),
                                    memCacheHeight: (60 * dpr.toInt()),
                                    memCacheWidth: (60 * dpr.toInt()),
                                    useOldImageOnUrlChange: true,
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.broken_image,
                                          size: 60,
                                        ),
                                    cacheManager: CustomCacheManagerI.instance,
                                  ),
                                )
                              : const Icon(Icons.image_not_supported, size: 60),
                          title: Text(nombre),
                          trailing: Icon(
                            seleccionado
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: seleccionado ? Colors.green : Colors.grey,
                          ),
                          onTap: () => _toggleSeleccion(producto),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class CustomCacheManagerI {
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
