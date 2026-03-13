import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_project_product/Models/productos_pdf.dart';
import 'package:flutter_project_product/Productos/add_productos.dart';
import 'package:flutter_project_product/Productos/edit_productos.dart';
import 'package:flutter_project_product/Productos/info_productos.dart';
import 'package:flutter_project_product/Service/Cloudinary/image_upload_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';

class Productos extends StatefulWidget {
  const Productos({super.key});

  @override
  State<Productos> createState() => _ProductosState();
}

class _ProductosState extends State<Productos> {
  final TextEditingController _searchController = TextEditingController();

  String? _userRole;
  bool _isLoadingRole = true;

  Timer? _debounce;

  final bool _isGeneratingPdf = false;

  final int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  final List<QueryDocumentSnapshot> _allProductos = [];
  List<QueryDocumentSnapshot> _filteredProductos = [];

  String _filtroCategoria = 'Todos';
  String _filtroClasificacion = 'Todos';

  List<String> _categoriasDisponibles = ['Todos'];
  List<String> _clasificacionesDisponibles = ['Todos'];

  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadCategoriasYClasificaciones();
    _loadProductos();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadProductos();
      }
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

  Future<void> _loadCategoriasYClasificaciones() async {
    // Verificamos si el adminId está definido
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String adminId = user.uid; // valor por defecto
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    final categoriasSnap = await FirebaseFirestore.instance
        .collection('categorias')
        .where('adminId', isEqualTo: adminId)
        .get();
    final clasificacionesSnap = await FirebaseFirestore.instance
        .collection('clasificacion')
        .where('adminId', isEqualTo: adminId)
        .get();

    setState(() {
      _categoriasDisponibles =
          ['Todos'] +
          categoriasSnap.docs.map((d) => d['nombre'].toString()).toList();
      _clasificacionesDisponibles =
          ['Todos'] +
          clasificacionesSnap.docs.map((d) => d['nombre'].toString()).toList();
    });
  }

  Future<void> _loadProductos({bool reset = false}) async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (reset) {
      _allProductos.clear();
      _filteredProductos.clear();
      _lastDocument = null;
      _hasMore = true;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String adminId = userDoc.data()?['adminId'] ?? user.uid;

    Query queryRef = FirebaseFirestore.instance
        .collection('productos')
        .where('adminId', isEqualTo: adminId)
        .orderBy('fecha_creacion', descending: true)
        .limit(_pageSize);

    // Filtros
    if (_filtroCategoria != 'Todos') {
      queryRef = queryRef.where('categoria', isEqualTo: _filtroCategoria);
    }
    if (_filtroClasificacion != 'Todos') {
      queryRef = queryRef.where(
        'clasificacion',
        isEqualTo: _filtroClasificacion,
      );
    }

    // Paginación
    if (_lastDocument != null && !reset) {
      queryRef = queryRef.startAfterDocument(_lastDocument!);
    }

    final snapshot = await queryRef.get();

    if (snapshot.docs.isNotEmpty) {
      _precacheImagenesPagina(snapshot.docs);
      _lastDocument = snapshot.docs.last;

      // Agregar solo los nuevos documentos
      for (var doc in snapshot.docs) {
        if (!_allProductos.any((d) => d.id == doc.id)) {
          _allProductos.add(doc);
        }
      }

      if (snapshot.docs.length < _pageSize) {
        _hasMore = false;
      }
    } else {
      _hasMore = false;
    }

    setState(() {
      _filteredProductos = List.from(_allProductos);
      _isLoadingMore = false;
    });
  }

  Future<void> _searchProductos(String query, {bool reset = true}) async {
    setState(() {
      if (reset) {
        _filteredProductos.clear();
        _lastDocument = null;
        _hasMore = true;
      }
      _isLoadingMore = true;
    });

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

    Query queryRef = FirebaseFirestore.instance
        .collection('productos')
        .where('adminId', isEqualTo: adminId);

    // Filtros activos
    if (_filtroCategoria != 'Todos') {
      queryRef = queryRef.where('categoria', isEqualTo: _filtroCategoria);
    }
    if (_filtroClasificacion != 'Todos') {
      queryRef = queryRef.where(
        'clasificacion',
        isEqualTo: _filtroClasificacion,
      );
    }

    // Si hay texto de búsqueda
    if (query.isNotEmpty) {
      final snapshot = await queryRef
          .orderBy('fecha_creacion', descending: true)
          .limit(500)
          .get();

      final normalizedQuery = _normalizeText(query);
      final List<QueryDocumentSnapshot> resultados = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final nombre = _normalizeText(data['nombre'] ?? '');
        final marca = _normalizeText(data['marca'] ?? '');

        if (nombre.contains(normalizedQuery) ||
            marca.contains(normalizedQuery)) {
          resultados.add(doc);
        }
      }

      setState(() {
        _filteredProductos = resultados;
        _isLoadingMore = false;
        _hasMore = false; // desactiva paginación durante búsqueda
      });
      return;
    }

    // Caso 2: No hay búsqueda → paginación normal
    if (_lastDocument != null && !reset) {
      queryRef = queryRef.startAfterDocument(_lastDocument!);
    }

    queryRef = queryRef
        .orderBy('fecha_creacion', descending: true)
        .limit(_pageSize);

    final snapshot = await queryRef.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;

      for (var doc in snapshot.docs) {
        if (!_filteredProductos.any((d) => d.id == doc.id)) {
          _filteredProductos.add(doc);
        }
      }

      if (snapshot.docs.length < _pageSize) {
        _hasMore = false;
      }
    } else {
      _hasMore = false;
    }

    setState(() {
      _isLoadingMore = false;
    });
  }

  /// Normaliza texto eliminando acentos y mayúsculas.
  /// Ejemplo: "Café Molido" -> "cafe molido"
  String _normalizeText(String text) {
    const withAccents = 'áàäâãéèëêíìïîóòöôõúùüûñÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuunAAAAAEEEEIIIIOOOOOUUUUN';

    String result = text;
    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }

    return result.toLowerCase().trim();
  }

  Future<void> _eliminarProducto(String docId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('productos')
          .doc(docId)
          .delete();
      await _loadProductos(reset: true);

      messenger.showSnackBar(
        const SnackBar(content: Text('Producto eliminado')),
      );

      setState(() {});
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error eliminando producto: $e')),
      );
    }
  }

  Future<Directory?> getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // En Android, el directorio Downloads está en External Storage Public Directory
      final downloadsPath = Directory('/storage/emulated/0/Download');
      if (await downloadsPath.exists()) {
        return downloadsPath;
      }
    } else if (Platform.isIOS) {
      // iOS no tiene una carpeta Downloads pública, usa Documents
      return await getApplicationDocumentsDirectory();
    }
    return null;
  }

  Future<void> _generarYGuardarPDFConImagenes() async {
    final messenger = ScaffoldMessenger.of(context);
    // Solicitar permiso de almacenamiento (solo Android)
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();

      if (!status.isGranted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Permiso de almacenamiento denegado')),
        );
        return;
      }

      // if (!status.isGranted) {
      //   if (!mounted) return;
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Permiso de almacenamiento denegado')),
      //   );
      //   return;
      // }
    }

    final pdf = pw.Document();

    // 1. Agrupar productos por categoría
    final Map<String, List<ProductosPdf>> productosPorCategoria = {};
    for (var doc in _filteredProductos) {
      final data = doc.data() as Map<String, dynamic>;
      final categoria = data['categoria'] ?? 'Sin categoría';
      final nombre = data['nombre'] ?? 'Sin nombre';
      final marca = data['marca'] ?? 'Sin marca';
      final precio = data['precio'] != null
          ? '\$${(data['precio'] as num).toStringAsFixed(2)}'
          : 'Sin precio';
      final clasificacion = data['clasificacion'] ?? 'N/A';
      final imageUrl = data['imagen'] ?? '';

      pw.ImageProvider? imagen;

      if (imageUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            imagen = pw.MemoryImage(response.bodyBytes);
          }
        } catch (_) {
          imagen = null;
        }
      }

      final producto = ProductosPdf(
        nombre: nombre,
        marca: marca,
        precio: precio,
        clasificacion: clasificacion,
        imagen: imagen,
      );

      productosPorCategoria.putIfAbsent(categoria, () => []).add(producto);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Catálogo de Productos',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Fecha de generación: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
              ),
              pw.SizedBox(height: 40),
              // pw.Text('Empresa XYZ'),
              // Puedes incluir una imagen de logo si quieres también.
            ],
          ),
        ),
      ),
    );

    // 2. Recorrer categorías y generar secciones
    for (final entry in productosPorCategoria.entries) {
      final categoria = entry.key;
      final productos = entry.value;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            List<pw.Widget> content = [
              pw.Header(level: 1, child: pw.Text('Categoría: $categoria')),
            ];

            for (int i = 0; i < productos.length; i += 2) {
              final rowChildren = <pw.Widget>[];

              for (int j = i; j < i + 2 && j < productos.length; j++) {
                final producto = productos[j];

                final imageWidget = producto.imagen != null
                    ? pw.Image(producto.imagen!, width: 100, height: 100)
                    : pw.Text('Sin imagen');

                rowChildren.add(
                  pw.Container(
                    width: (PdfPageFormat.a4.availableWidth / 2) - 10,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          producto.nombre,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Marca: ${producto.marca}'),
                        pw.Text('Precio: ${producto.precio}'),
                        pw.Text('Clasificación: ${producto.clasificacion}'),
                        pw.SizedBox(height: 5),
                        imageWidget,
                      ],
                    ),
                  ),
                );
              }

              content.add(
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: rowChildren,
                ),
              );

              content.add(pw.SizedBox(height: 10));
            }

            return content;
          },
        ),
      );
    }

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo acceder a la carpeta Downloads'),
        ),
      );
      return;
    }

    final file = File('${downloadsDir.path}/catalogo_productos.pdf');
    await file.writeAsBytes(await pdf.save());

    messenger.showSnackBar(
      SnackBar(content: Text('PDF guardado en: ${file.path}')),
    );
  }

  Future<void> _mostrarDialogoCarga() async {
    final navigator = Navigator.of(context);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar"),
        content: Text("¿Deseas generar el catalogo?"),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => navigator.pop(true),
            child: const Text("Confirmar"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // No permitir cerrar tocando fuera
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Flexible(child: Text("Generando catálogo...", softWrap: true)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _precacheImagenesPagina(List<QueryDocumentSnapshot> docs) async {
    final futures = <Future>[];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final imageUrl = data['imagen'] as String?;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        futures.add(CustomCacheManager.instance.downloadFile(imageUrl));
      }
    }

    await Future.wait(futures);
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      // Mostramos un loader mientras se carga el rol del usuario
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Productos"),
          actions: [
            IconButton(
              //Función de descargar pdf para descargar el catalogo
              onPressed: () async {
                if (_filteredProductos.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('No hay productos para exportar.'),
                    ),
                  );
                  return;
                }

                await _mostrarDialogoCarga();

                // Mostrar el indicador por 6 segundos
                await Future.delayed(const Duration(seconds: 6));

                await _generarYGuardarPDFConImagenes();

                navigator.pop();
              },
              icon: const Icon(Icons.ballot),
            ),
            if (_userRole == 'admin')
              IconButton(
                onPressed: () async {
                  _searchFocusNode.unfocus();
                  final result = await navigator.push(
                    MaterialPageRoute(builder: (_) => const AddProductos()),
                  );

                  if (result == true) {
                    _loadProductos(reset: true);
                  }
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 30),
              ),
          ],
        ),
        body: _isGeneratingPdf
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 25,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _searchController,
                        onChanged: (value) {
                          // Cancelar el temporizador anterior si el usuario sigue escribiendo
                          if (_debounce?.isActive ?? false) _debounce!.cancel();

                          // Esperar 500 ms antes de ejecutar la búsqueda
                          _debounce = Timer(
                            const Duration(milliseconds: 500),
                            () {
                              _searchProductos(value);
                            },
                          );
                        },
                        focusNode: _searchFocusNode,
                        keyboardType: TextInputType.name,
                        style: const TextStyle(
                          fontSize: 20,
                          overflow: TextOverflow.ellipsis,
                        ),
                        decoration: InputDecoration(
                          labelText: "Buscar",
                          hintText: "Buscar productos",
                          suffixIcon: const Icon(
                            Icons.search_outlined,
                            size: 40,
                          ),
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
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2.0,
                            ),
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
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              itemHeight: 80,
                              isExpanded: true,
                              initialValue: _filtroCategoria,
                              items: _categoriasDisponibles.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _filtroCategoria = value!;
                                });
                                _searchProductos(_searchController.text);
                              },
                              decoration: const InputDecoration(
                                labelText: 'Categoría',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              itemHeight: 80,
                              isExpanded: true,
                              initialValue: _filtroClasificacion,
                              items: _clasificacionesDisponibles.map((cl) {
                                return DropdownMenuItem(
                                  value: cl,
                                  child: Text(cl),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _filtroClasificacion = value!;
                                });
                                _searchProductos(_searchController.text);
                              },
                              decoration: const InputDecoration(
                                labelText: 'Clasificación',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      if (_filteredProductos.isEmpty)
                        const Center(
                          child: Text("No hay productos para mostrar"),
                        ),
                      ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount:
                            _filteredProductos.length +
                            ((_hasMore && _searchController.text.isEmpty)
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index == _filteredProductos.length) {
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

                          final doc = _filteredProductos[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final imageUrl = data['imagen'] as String?;
                          final dpr = MediaQuery.of(context).devicePixelRatio;

                          return GestureDetector(
                            onTap: () {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      InfoProductos(producto: doc),
                                ),
                              );
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
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
                                          cacheManager:
                                              CustomCacheManager.instance,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.image_not_supported,
                                        size: 60,
                                      ),
                                title: Text(data['nombre'] ?? 'Sin nombre'),
                                subtitle: Text(
                                  data['precio'] is num
                                      ? '\$${(data['precio'] as num).toStringAsFixed(2)}'
                                      : 'Sin precio',
                                ),
                                trailing: _userRole == 'admin'
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.more_vert),
                                            onPressed: () async {
                                              _searchFocusNode.unfocus();

                                              final result = await navigator.push(
                                                MaterialPageRoute(
                                                  builder: (_) => EditProductos(
                                                    producto:
                                                        _filteredProductos[index],
                                                  ),
                                                ),
                                              );
                                              if (result == true) {
                                                _loadProductos(reset: true);
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text(
                                                    'Confirmar eliminación',
                                                  ),
                                                  content: const Text(
                                                    '¿Estás seguro de eliminar este producto?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          navigator.pop(false),
                                                      child: const Text(
                                                        'Cancelar',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          navigator.pop(true),
                                                      child: const Text(
                                                        'Eliminar',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                await _eliminarProducto(doc.id);
                                              }
                                            },
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 65),
                    ],
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await _loadProductos(reset: true);
          },
          child: const Icon(Icons.refresh, size: 30),
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
