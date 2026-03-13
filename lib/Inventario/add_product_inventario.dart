import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Inventario/inventario.dart';
import 'package:intl/intl.dart';

class AddProductInventario extends StatefulWidget {
  const AddProductInventario({super.key});

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
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 15;
  DocumentSnapshot? _ultimoDocumento;
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _loadUserRole();
    // _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      setState(() {
        if (_debounce?.isActive ?? false) _debounce!.cancel();

        _debounce = Timer(const Duration(milliseconds: 500), () {
          _searchText = _searchController.text.trim();
          _productos.clear();
          _ultimoDocumento = null;
          _hasMore = true;
          _cargarProductos();
        });
      });
    });
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

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (reset) {
      _productos.clear();
      _ultimoDocumento = null;
      _hasMore = true;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String adminId = user.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    Query query = FirebaseFirestore.instance
        .collection('productos')
        .where('adminId', isEqualTo: adminId)
        .orderBy('nombre')
        .limit(_limit);

    if (_ultimoDocumento != null && !reset) {
      query = query.startAfterDocument(_ultimoDocumento!);
    }

    // Si hay texto de búsqueda, filtramos
    if (_searchText.isNotEmpty) {
      query = FirebaseFirestore.instance
          .collection('productos')
          .orderBy('nombre')
          .where('adminId', isEqualTo: adminId)
          .where('nombre', isGreaterThanOrEqualTo: _searchText)
          .where('nombre', isLessThanOrEqualTo: '$_searchText\uf8ff')
          .limit(_limit);
    }

    QuerySnapshot snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _ultimoDocumento = snapshot.docs.last;
      _productos.addAll(snapshot.docs);
    } else {
      _hasMore = false;
    }

    if (snapshot.docs.length < _limit) {
      _hasMore = false;
    }

    setState(() => _isLoading = false);
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
    setState(() => _isLoading = true);

    // Si ya todos están seleccionados, deseleccionamos
    if (_productosSeleccionados.length == _productos.length && !_hasMore) {
      setState(() {
        _productosSeleccionados.clear();
        _isLoading = false;
      });
      return;
    }

    // Cargar todos los productos de la colección (sin límite)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String adminId = user.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    final QuerySnapshot allProductsSnapshot = await FirebaseFirestore.instance
        .collection('productos')
        .where('adminId', isEqualTo: adminId)
        .orderBy('nombre')
        .get();

    setState(() {
      _productos = allProductsSnapshot.docs; // mostramos todos
      _productosSeleccionados = List.from(
        allProductsSnapshot.docs,
      ); // seleccionamos todos
      _hasMore = false; // ya no hay más por cargar
      _isLoading = false;
    });
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
      final fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final inventarioDocRef = firestore.collection('inventario').doc(fechaHoy);

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
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const Inventario()),
      );
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
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      // Mostramos un loader mientras se carga el rol del usuario
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar productos"),
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
                                    imageUrl: imageUrl,
                                    placeholder: (_, _) => const SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(),
                                    ),
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.broken_image,
                                          size: 60,
                                        ),
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
