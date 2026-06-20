import 'dart:async';
import 'dart:math';

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

enum TipoFiltroProducto { todos, precioBase, preciosEspeciales }

class _GestionProductClientState extends State<GestionProductClient> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _todosLosProductos = [];
  late Map<String, double> _preciosEspeciales = {};
  List<QueryDocumentSnapshot> _resultadoCompleto = [];
  List<QueryDocumentSnapshot> _productosFiltrados = [];

  TipoFiltroProducto _tipoFiltro = TipoFiltroProducto.todos;

  final int _pageSize = 10;
  int _paginaActual = 0;
  final ScrollController _scrollController = ScrollController();
  bool isLoadingMore = false;
  bool _hasMore = true;
  bool _cargandoInicial = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _preciosEspeciales = Map<String, double>.from(
      widget.preciosPersonalizados.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
    Future.microtask(() async {
      await _cargarTodosLosProductos();
      _aplicarFiltros();
      if (mounted) {
        setState(() {
          _cargandoInicial = false;
        });
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          _hayMasProductos) {
        _cargarMasSegunFiltro();
        // if (_tipoFiltro == TipoFiltroProducto.preciosEspeciales) {
        //   _cargarMasEspeciales();
        // } else if (_searchController.text.isNotEmpty) {
        //   _buscarProductos(_searchController.text);
        // } else {
        //   _loadProductos();
        // }
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

  Future<void> _cargarTodosLosProductos() async {
    if (_todosLosProductos.isNotEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    String adminId = currentUser.uid;

    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('productos')
        .where('adminId', isEqualTo: adminId)
        .orderBy('fecha_creacion', descending: true)
        .get();

    _todosLosProductos = snapshot.docs;
  }

  void _aplicarPaginacion() {
    final cantidadMostrar = (_paginaActual + 1) * _pageSize;

    final fin = min(cantidadMostrar, _resultadoCompleto.length);

    setState(() {
      _productosFiltrados = _resultadoCompleto.sublist(0, fin);

      _hasMore = fin < _resultadoCompleto.length;
    });
  }

  Future<void> _loadProductos() async {
    if (!_hasMore) return;

    _paginaActual++;

    _aplicarPaginacion();
  }

  Future<void> _buscarProductos(String query) async {
    final normalizedQuery = _normalizeText(query);

    // Si la búsqueda está vacía, mostramos la lista paginada normal
    if (normalizedQuery.isEmpty) {
      _aplicarFiltros();
      return;
    }

    // Filtrar aplicando normalización
    final resultados = _todosLosProductos.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final nombre = _normalizeText(data['nombre'] ?? '');

      return nombre.contains(normalizedQuery);
    }).toList();

    _aplicarFiltros(productosOrigen: resultados);
  }

  void _aplicarFiltros({List<QueryDocumentSnapshot>? productosOrigen}) async {
    final origen = productosOrigen ?? _todosLosProductos;

    List<QueryDocumentSnapshot> resultado = List.from(origen);

    switch (_tipoFiltro) {
      case TipoFiltroProducto.precioBase:
        resultado = resultado.where((doc) {
          return !_preciosEspeciales.containsKey(doc.id);
        }).toList();
        break;

      case TipoFiltroProducto.preciosEspeciales:
        resultado = resultado.where((doc) {
          return _preciosEspeciales.containsKey(doc.id);
        }).toList();
        break;

      case TipoFiltroProducto.todos:
        break;
    }

    _resultadoCompleto = resultado;

    _paginaActual = 0;

    _aplicarPaginacion();
  }

  void _aplicarFiltroActual() {
    if (_searchController.text.isNotEmpty) {
      _buscarProductos(_searchController.text);
    } else {
      _aplicarFiltros();
    }
  }

  void _cargarMasSegunFiltro() {
    _loadProductos();
  }

  bool get _hayMasProductos {
    return _hasMore;
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

                    _debounce = Timer(const Duration(milliseconds: 300), () {
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
                DropdownButtonFormField<TipoFiltroProducto>(
                  initialValue: _tipoFiltro,
                  decoration: InputDecoration(
                    labelText: 'Filtrar productos',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TipoFiltroProducto.todos,
                      child: Text('Todos'),
                    ),
                    DropdownMenuItem(
                      value: TipoFiltroProducto.precioBase,
                      child: Text('Precio Base'),
                    ),
                    DropdownMenuItem(
                      value: TipoFiltroProducto.preciosEspeciales,
                      child: Text('Precio Especial'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;

                    setState(() {
                      _tipoFiltro = value;
                    });

                    _aplicarFiltroActual();
                  },
                ),
                const SizedBox(height: 15),
                _cargandoInicial
                    ? const Center(child: CircularProgressIndicator())
                    : _productosFiltrados.isEmpty
                    ? const Center(child: Text('No hay productos disponibles'))
                    : ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount:
                            _productosFiltrados.length +
                            ((_hayMasProductos &&
                                    _searchController.text.isEmpty)
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
                                  onTap: !isLoadingMore
                                      ? _cargarMasSegunFiltro
                                      : null,
                                  child: Column(
                                    children: [
                                      if (isLoadingMore)
                                        const CircularProgressIndicator()
                                      else
                                        const Icon(Icons.download),
                                      const SizedBox(height: 10),
                                      Text(
                                        _hayMasProductos
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
                          final tienePrecioEspecial = _preciosEspeciales
                              .containsKey(productoId);

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
                                      cacheManager:
                                          CustomCacheManagerGPC.instance,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                    ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(nombre)),
                                  if (tienePrecioEspecial)
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                ],
                              ),
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

class CustomCacheManagerGPC {
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
