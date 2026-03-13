import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Models/save_productos.dart';
import 'package:flutter_project_product/Service/Cloudinary/image_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'add_categoria_productos.dart';
import 'add_clasificacion_productos.dart';

class AddProductos extends StatefulWidget {
  const AddProductos({super.key});

  @override
  State<AddProductos> createState() => _AddProductosState();
}

class _AddProductosState extends State<AddProductos> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _contenidoController = TextEditingController();
  final _precioController = TextEditingController();
  final _marcaController = TextEditingController();

  File? _image;
  bool _isPickingImage = false;

  List<String> _categorias = [];
  List<String> _clasificaciones = [];
  String? _selectedCategory;
  String? _selectedClasifica;

  Future<void> _loadCategorias() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    String adminId = currentUser.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId']; // Si es asistente, usar el adminId
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('categorias')
        .where('adminId', isEqualTo: adminId)
        .get();

    setState(() {
      _categorias = snapshot.docs.map((e) => e['nombre'] as String).toList();
    });
  }

  Future<void> _loadClasificaciones() async {
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
        .collection('clasificacion')
        .where('adminId', isEqualTo: adminId)
        .get();

    setState(() {
      _clasificaciones = snapshot.docs
          .map((e) => e['nombre'] as String)
          .toList();
    });
  }

  // Future<void> _showAddTipoDialog(
  //   BuildContext context, {
  //   required String tipo,
  // }) async {
  //   final opcion = await showDialog<String>(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: Text(
  //         tipo == 'categoria'
  //             ? 'Administrar categorías'
  //             : 'Administrar clasificaciones',
  //       ),
  //       content: const Text('¿Qué deseas hacer?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, 'agregar'),
  //           child: const Text('Agregar'),
  //         ),
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, 'eliminar'),
  //           child: const Text('Eliminar'),
  //         ),
  //       ],
  //     ),
  //   );
  //   if (opcion == 'agregar') {
  //     tipo == 'categoria' ? null : await addClasificacionProductos(context);
  //   } else if (opcion == 'eliminar') {
  //     tipo == 'categoria'
  //         ? await showEliminarTipoDialog(context, tipo: 'categoria')
  //         : await showEliminarTipoDialog(context, tipo: 'clasificacion');
  //   }
  //   // después recargar
  //   await _loadCategorias();
  //   await _loadClasificaciones();
  // }

  // Future<void> showEliminarTipoDialog(
  //   BuildContext context, {
  //   required String tipo,
  // }) async {
  //   final currentUser = FirebaseAuth.instance.currentUser;
  //   if (currentUser == null) return;

  //   final userDoc = await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(currentUser.uid)
  //       .get();

  //   String adminId = currentUser.uid;
  //   if (userDoc.exists && userDoc.data()?['adminId'] != null) {
  //     adminId = userDoc['adminId'];
  //   }

  //   final coll = tipo == 'categoria'
  //       ? FirebaseFirestore.instance.collection('categorias')
  //       : FirebaseFirestore.instance.collection('clasificacion');

  //   final snapshot = await coll.where('adminId', isEqualTo: adminId).get();
  //   final opciones = snapshot.docs;

  //   final idToDelete = await showDialog<String>(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: Text(
  //         tipo == 'categoria' ? 'Eliminar categoría' : 'Eliminar clasificación',
  //       ),
  //       content: SizedBox(
  //         width: double.maxFinite,
  //         child: ListView.builder(
  //           shrinkWrap: true,
  //           itemCount: opciones.length,
  //           itemBuilder: (_, i) {
  //             final nombre = opciones[i]['nombre'];
  //             return ListTile(
  //               title: Text(nombre),
  //               onTap: () => Navigator.pop(context, opciones[i].id),
  //             );
  //           },
  //         ),
  //       ),
  //     ),
  //   );

  //   if (idToDelete != null) {
  //     await coll.doc(idToDelete).delete();
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           '${tipo[0].toUpperCase()}${tipo.substring(1)} eliminada',
  //         ),
  //       ),
  //     );
  //   }
  // }

  Future<void> pickImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar una foto'),
                onTap: () => navigator.pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Seleccionar desde galería'),
                onTap: () => navigator.pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null || !mounted) return;

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      setState(() {
        if (pickedFile != null) {
          _image = File(pickedFile.path);
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('No se seleccionó ninguna imagen')),
          );
        }
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    } finally {
      _isPickingImage = false;
    }
  }

  void addProduct() async {
    if (_formKey.currentState!.validate()) {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      if (_image == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Por favor selecciona una imagen')),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final imageUrl = await imageUploadService(_image!);

        if (imageUrl != null) {
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

          await saveProductos(
            nombre: _nombreController.text.trim(),
            contenido: _contenidoController.text.trim(),
            precio: double.tryParse(_precioController.text.trim()) ?? 0,
            marca: _marcaController.text.trim(),
            categoria: _selectedCategory!,
            clasificacion: _selectedClasifica!,
            imageUrl: imageUrl,
            adminId: adminId,
          );

          navigator.pop(); // Cerrar loading
          messenger.showSnackBar(
            const SnackBar(content: Text('Producto agregado exitosamente')),
          );
          navigator.pop(true); // Volver atrás
        } else {
          navigator.pop();
          messenger.showSnackBar(
            const SnackBar(content: Text('Error al subir imagen')),
          );
        }
      } catch (e) {
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCategorias();
    _loadClasificaciones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agregar productos"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'categoria') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddCategoriaProductos(),
                  ),
                ).then((_) {
                  _loadCategorias(); // Recargar luego de volver
                });
              } else if (value == 'clasificacion') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddClasificacionProductos(),
                  ),
                ).then((_) {
                  _loadClasificaciones(); // Recargar clasificaciones al volver
                });
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'categoria',
                child: Text('Gestionar categoría'),
              ),
              const PopupMenuItem(
                value: 'clasificacion',
                child: Text('Gestionar clasificación'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  itemHeight: 80,
                  isExpanded: true,
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    hintText: 'Seleccione una opción',
                    suffixIcon: const Icon(Icons.contact_emergency_rounded),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  items: _categorias
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  validator: (v) =>
                      v == null ? 'Seleccione una categoría' : null,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  itemHeight: 80,
                  isExpanded: true,
                  initialValue: _selectedClasifica,
                  decoration: InputDecoration(
                    labelText: 'Presentación',
                    hintText: 'Seleccione una opción',
                    suffixIcon: const Icon(Icons.contact_emergency_rounded),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  items: _clasificaciones
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedClasifica = v),
                  validator: (v) =>
                      v == null ? 'Seleccione una clasificación' : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _nombreController,
                  decoration: InputDecoration(labelText: "Nombre"),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _contenidoController,
                  decoration: InputDecoration(labelText: "Contenido"),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _precioController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo requerido';
                    }
                    final parsed = double.tryParse(value);
                    if (parsed == null) {
                      return 'Ingrese un número válido';
                    }
                    return null;
                  },
                  decoration: InputDecoration(labelText: "Precio"),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _marcaController,
                  decoration: InputDecoration(labelText: "Marca"),
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: _image == null
                        ? const Icon(Icons.camera_alt, size: 50)
                        : ClipOval(
                            child: Image.file(
                              _image!,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton(onPressed: addProduct, child: Text("Guardar")),
                const SizedBox(height: 65),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
