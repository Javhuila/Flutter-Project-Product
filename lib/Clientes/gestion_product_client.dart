import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_project_product/Service/Cloudinary/image_upload_service.dart';

class GestionProductClient extends StatefulWidget {
  final String clienteId;
  final Map<String, dynamic> preciosPersonalizados;

  const GestionProductClient({
    super.key,
    required this.clienteId,
    required this.preciosPersonalizados,
  });

  @override
  State<GestionProductClient> createState() => _GestionProductClientState();
}

class _GestionProductClientState extends State<GestionProductClient> {
  final TextEditingController _searchController = TextEditingController();
  final List<QueryDocumentSnapshot> _productos = [];
  late Map<String, double> _preciosEspeciales = {};
  List<QueryDocumentSnapshot> _productosFiltrados = [];

  final int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _preciosEspeciales = Map<String, double>.from(
      widget.preciosPersonalizados.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
    _loadProductos();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        if (_searchController.text.isNotEmpty) {
          _buscarProductos(_searchController.text);
        } else {
          _loadProductos();
        }
      }
    });
  }

  String _normalizeText(String text) {
    const withAccents = 'áàäâãéèëêíìïîóòöôõúùüûñÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuunAAAAAEEEEIIIIOOOOOUUUUN';

    String result = text;

    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }

    return result.toLowerCase().trim();
  }

  Future<void> _loadProductos({bool reset = false}) async {
    if (_isLoadingMore || (!_hasMore && !reset)) return;

    setState(() => _isLoadingMore = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (reset) {
      _productos.clear();
      _productosFiltrados.clear();
      _lastDocument = null;
      _hasMore = true;
    }

    // Obtener adminId (ya sea admin o asistente)
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    String adminId = currentUser.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    Query query = FirebaseFirestore.instance
        .collection('productos')
        .where('adminId', isEqualTo: adminId)
        .orderBy('fecha_creacion', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null && !reset) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
      _productos.addAll(snapshot.docs);
    } else {
      _hasMore = false;
    }

    if (snapshot.docs.length < _pageSize) {
      _hasMore = false;
    }

    setState(() {
      _isLoadingMore = false;
      _productos.addAll(snapshot.docs);
      _productosFiltrados = List.from(_productos);
    });
  }

  Future<void> _buscarProductos(String query) async {
    final normalizedQuery = _normalizeText(query);

    // Si la búsqueda está vacía, mostramos la lista paginada normal
    if (normalizedQuery.isEmpty) {
      setState(() {
        _productosFiltrados = List.from(_productos);
        _hasMore = true;
      });
      return;
    }

    // Si hay texto de búsqueda, traemos todos los productos y filtramos localmente
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Obtener adminId (igual que en _loadProductos)
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    String adminId = currentUser.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    // Traer *todos* los productos (sin límite)
    final snapshot = await FirebaseFirestore.instance
        .collection('productos')
        .where('adminId', isEqualTo: adminId)
        .get();

    // Filtrar aplicando normalización
    final resultados = snapshot.docs.where((doc) {
      final data = doc.data();
      final nombre = _normalizeText(data['nombre'] ?? '');
      return nombre.contains(normalizedQuery);
    }).toList();

    setState(() {
      _productosFiltrados = resultados;
      _hasMore = false; // desactivar "cargar más" mientras hay búsqueda activa
    });
  }

  void _editarPrecio(String productoId, double? precioActual) async {
    final controller = TextEditingController(
      text: precioActual?.toString() ?? '',
    );
    final navigator = Navigator.of(context);

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Precio Especial"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Nuevo precio especial",
            hintText: "Ej: 1200.0",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              final nuevoPrecio = double.tryParse(controller.text);
              if (nuevoPrecio != null) {
                setState(() {
                  _preciosEspeciales[productoId] = nuevoPrecio;
                });
                navigator.pop(true);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarPrecios() async {
    final navigator = Navigator.of(context);
    await FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.clienteId)
        .update({'precio_personalizado': _preciosEspeciales});

    navigator.pop(true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionando productos"),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _guardarPrecios),
        ],
      ),
      body: Builder(
        builder: (context) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
            child: Column(
              children: [
                const SizedBox(height: 20),
                TextFormField(
                  controller: _searchController,
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce?.cancel();

                    _debounce = Timer(const Duration(milliseconds: 600), () {
                      _buscarProductos(value); // Cada vez que se escribe, busca
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Buscar productos',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                _productos.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount:
                            _productosFiltrados.length +
                            ((_hasMore && _searchController.text.isEmpty)
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index == _productosFiltrados.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20.0,
                              ),
                              child: Center(
                                child: GestureDetector(
                                  onTap: _hasMore && !_isLoadingMore
                                      ? _loadProductos
                                      : null,
                                  child: Column(
                                    children: [
                                      if (_isLoadingMore)
                                        const CircularProgressIndicator()
                                      else
                                        const Icon(Icons.download),
                                      const SizedBox(height: 10),
                                      Text(
                                        _hasMore
                                            ? 'Toca para cargar más...'
                                            : 'No hay más productos.',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          final productoDoc = _productosFiltrados[index];
                          final producto =
                              productoDoc.data() as Map<String, dynamic>;
                          final productoId = productoDoc.id;
                          final nombre = producto['nombre'] ?? 'Sin nombre';
                          final imagenUrl = producto['imagen'] ?? '';
                          final precioBase = (producto['precio'] ?? 0)
                              .toDouble();
                          final precioEspecial = _preciosEspeciales[productoId];
                          final dpr = MediaQuery.of(context).devicePixelRatio;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: imagenUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      key: ValueKey(productoId),
                                      filterQuality: FilterQuality.low,
                                      imageUrl: getOptimizedCloudinaryUrl(
                                        producto['imagen'] ?? '',
                                      ),
                                      width: 50,
                                      height: 50,
                                      placeholder: (context, url) =>
                                          const SizedBox(
                                            width: 50,
                                            height: 50,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.broken_image),
                                      fadeInDuration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      fadeOutDuration: const Duration(
                                        milliseconds: 100,
                                      ),
                                      memCacheWidth: (60 * dpr).toInt(),
                                      memCacheHeight: (60 * dpr).toInt(),
                                      useOldImageOnUrlChange: true,
                                      cacheManager: CustomCacheManager.instance,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                    ),
                              title: Text(nombre),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Precio base: \$${precioBase.toStringAsFixed(2)}",
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 0,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            const Text("Precio especial: "),
                                            Text(
                                              precioEspecial != null
                                                  ? "\$${precioEspecial.toStringAsFixed(2)}"
                                                  : "---",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _editarPrecio(
                                                productoId,
                                                precioEspecial,
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          );
        },
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
