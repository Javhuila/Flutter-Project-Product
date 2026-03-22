import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

import '../Service/Cloudinary/image_upload_service.dart';

class AddCategoriaProductos extends StatefulWidget {
  const AddCategoriaProductos({super.key});

  @override
  State<AddCategoriaProductos> createState() => _AddCategoriaProductosState();
}

class _AddCategoriaProductosState extends State<AddCategoriaProductos> {
  List<DocumentSnapshot> _categorias = [];
  bool _isAdmin = false;
  String? adminId;

  @override
  void initState() {
    super.initState();
    cargarCategorias();
  }

  Future<void> cargarCategorias() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    adminId = user.uid;

    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId']; // si es asistente
    }

    _isAdmin = userDoc.data()?['role'] == 'admin';

    final snapshot = await FirebaseFirestore.instance
        .collection('categorias')
        .where('adminId', isEqualTo: adminId)
        .get();

    setState(() {
      _categorias = snapshot.docs;
    });
  }

  Future<void> mostrarFormularioCategoria({DocumentSnapshot? doc}) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: doc?['nombre']);
    File? selectedImage;
    String? imageUrl = doc?['imagen'];
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final navigator = Navigator.of(context);

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(doc == null ? 'Agregar categoría' : 'Editar categoría'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: "Nombre"),
                    validator: (value) => value == null || value.isEmpty
                        ? "Campo requerido"
                        : null,
                  ),
                  const SizedBox(height: 15),
                  if (selectedImage != null)
                    Image.file(selectedImage!, height: 100)
                  else if (imageUrl != null && imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: getOptimizedCloudinaryUrl(imageUrl),
                      filterQuality: FilterQuality.low,
                      height: 100,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 150),
                      fadeOutDuration: const Duration(milliseconds: 100),
                      memCacheHeight: (100 * dpr.toInt()),
                      memCacheWidth: (100 * dpr.toInt()),
                      useOldImageOnUrlChange: true,
                      placeholder: (_, _) =>
                          const CircularProgressIndicator(strokeWidth: 2),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image, size: 50),
                    ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: context,
                        builder: (_) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text("Tomar foto"),
                                onTap: () => navigator.pop(ImageSource.camera),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text("Desde galería"),
                                onTap: () => navigator.pop(ImageSource.gallery),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (source != null) {
                        final picked = await ImagePicker().pickImage(
                          source: source,
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            selectedImage = File(picked.path);
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: const Text("Seleccionar imagen"),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  String? finalImageUrl = imageUrl;

                  if (selectedImage != null) {
                    finalImageUrl = await imageUploadService(selectedImage!);
                  }

                  final data = {
                    'nombre': controller.text.trim(),
                    'imagen': finalImageUrl ?? '',
                    'adminId': adminId,
                  };

                  if (doc == null) {
                    await FirebaseFirestore.instance
                        .collection('categorias')
                        .add(data);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('categorias')
                        .doc(doc.id)
                        .update(data);
                  }
                  navigator.pop();
                  await cargarCategorias();
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> eliminarCategoria(String id) async {
    await FirebaseFirestore.instance.collection('categorias').doc(id).delete();
    await cargarCategorias();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Categorías'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => mostrarFormularioCategoria(),
            ),
        ],
      ),
      body: _categorias.isEmpty
          ? const Center(child: Text("No hay categorías"))
          : ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _categorias.length,
              itemBuilder: (_, i) {
                final cat = _categorias[i];
                final imageUrl = cat['imagen'];
                final dpr = MediaQuery.of(context).devicePixelRatio;

                return ListTile(
                  leading:
                      cat['imagen'] != null &&
                          cat['imagen'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: getOptimizedCloudinaryUrl(imageUrl),
                            filterQuality: FilterQuality.low,
                            placeholder: (_, _) => const SizedBox(
                              width: 45,
                              height: 45,
                              child: CircularProgressIndicator(),
                            ),
                            width: 45,
                            height: 45,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 150),
                            fadeOutDuration: const Duration(milliseconds: 100),
                            memCacheHeight: (45 * dpr.toInt()),
                            memCacheWidth: (45 * dpr.toInt()),
                            useOldImageOnUrlChange: true,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.broken_image, size: 35),
                            cacheManager: CustomCacheManager.instance,
                          ),
                        )
                      : const CircleAvatar(
                          child: Icon(Icons.image_not_supported),
                        ),
                  title: Text(cat['nombre']),
                  trailing: _isAdmin
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  mostrarFormularioCategoria(doc: cat),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => eliminarCategoria(cat.id),
                            ),
                          ],
                        )
                      : null,
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
