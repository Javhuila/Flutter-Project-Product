import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Productos/edit_productos.dart';
import 'package:flutter_project_product/Service/Cloudinary/image_upload_service.dart';
import 'package:intl/intl.dart';

class InfoProductos extends StatefulWidget {
  final DocumentSnapshot producto;
  const InfoProductos({super.key, required this.producto});

  @override
  State<InfoProductos> createState() => _InfoProductosState();
}

class _InfoProductosState extends State<InfoProductos> {
  String? _userRole;
  bool _isLoadingRole = true;

  String? _categoriaImagen;
  bool _isLoadingCategoria = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadCategoriaDelProducto();
  }

  Future<void> _loadUserRole() async {
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
        _userRole = 'unknown';
        _isLoadingRole = false;
      });
    }
  }

  Future<void> _loadCategoriaDelProducto() async {
    final data = widget.producto.data() as Map<String, dynamic>;
    final String? nombreCategoria = data['categoria'];

    if (nombreCategoria == null || nombreCategoria.isEmpty) {
      setState(() {
        _categoriaImagen = null;
        _isLoadingCategoria = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categorias')
          .where('nombre', isEqualTo: nombreCategoria)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final catData = snapshot.docs.first.data();
        setState(() {
          _categoriaImagen = catData['imagen'];
          _isLoadingCategoria = false;
        });
      } else {
        setState(() {
          _categoriaImagen = null;
          _isLoadingCategoria = false;
        });
      }
    } catch (e) {
      setState(() {
        _categoriaImagen = null;
        _isLoadingCategoria = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.producto.data() as Map<String, dynamic>;

    final nombre = data['nombre'] ?? '';
    final contenido = data['contenido'] ?? '';
    final precio = data['precio'] ?? 0.0;
    final marca = data['marca'] ?? '';
    final categoria = data['categoria'] ?? '';
    final clasificacion = data['clasificacion'] ?? '';
    final imagenUrl = data['imagen'] ?? '';
    final fechaActualizacion = data['fecha_actualizacion'];

    final formattedDate = fechaActualizacion != null
        ? DateFormat(
            'dd/MM/yyyy – HH:mm',
          ).format((fechaActualizacion as Timestamp).toDate())
        : 'Sin fecha';

    final dpr = MediaQuery.of(context).devicePixelRatio;

    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Informacion del producto"),
        actions: [
          if (_userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: "Editar producto",
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                final result = await navigator.push(
                  MaterialPageRoute(
                    builder: (context) =>
                        EditProductos(producto: widget.producto),
                  ),
                );
                if (result == true) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Producto actualizado')),
                  );
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen principal
            Center(
              child: Stack(
                children: [
                  // Imagen principal del producto
                  if (imagenUrl != null && imagenUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        fadeInDuration: Duration(milliseconds: 300),
                        fadeOutDuration: Duration(milliseconds: 200),
                        memCacheHeight:
                            (490 * dpr.toInt()), // opcional para pantallas HD
                        maxHeightDiskCache: (490 * dpr.toInt()),
                        useOldImageOnUrlChange: true,
                        filterQuality: FilterQuality.low,
                        // imageUrl: imagenUrl,
                        imageUrl: getOptimizedCloudinaryUrl(
                          imagenUrl,
                          height: 500,
                        ),
                        height: 500,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => SizedBox(
                          height: 250,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => SizedBox(
                          height: 250,
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Imagen pequeña de la categoría (superpuesta)
                  if (!_isLoadingCategoria && _categoriaImagen != null)
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.8),
                          padding: const EdgeInsets.all(4),
                          child: CachedNetworkImage(
                            imageUrl: _categoriaImagen!,
                            filterQuality: FilterQuality.low,
                            width: 98,
                            height: 98,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 150),
                            fadeOutDuration: const Duration(milliseconds: 100),
                            memCacheHeight: (98 * dpr.toInt()),
                            memCacheWidth: (98 * dpr.toInt()),
                            useOldImageOnUrlChange: true,
                            placeholder: (_, _) =>
                                const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.broken_image, size: 98),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Nombre del producto
            Center(
              child: Text(
                nombre,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),

            // Información detallada
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detalle("Marca", marca),
                    _detalle("Contenido", contenido),
                    _detalle("Precio", "\$${precio.toStringAsFixed(2)}"),
                    _detalle("Categoría", categoria),
                    _detalle("Clasificación", clasificacion),
                    _detalle("Última modificación", formattedDate),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 70),
          ],
        ),
      ),
    );
  }

  Widget _detalle(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "$titulo:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(flex: 5, child: Text(valor)),
        ],
      ),
    );
  }
}
