import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../Service/Cloudinary/image_upload_service.dart';

class EditProductos extends StatefulWidget {
  final DocumentSnapshot producto;
  const EditProductos({super.key, required this.producto});

  @override
  State<EditProductos> createState() => _EditProductosState();
}

class _EditProductosState extends State<EditProductos> {
  final _formKey = GlobalKey<FormState>();

  File? _image;
  List<String> _tipoCategory = [];
  List<String> _listClasifica = [];
  String? _selectedCategory;
  String? _selectedClasifica;
  late TextEditingController _nombreController;
  late TextEditingController _contenidoController;
  late TextEditingController _precioController;
  late TextEditingController _marcaController;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      } else {
        // debugPrint('No hay imagen seleccionada.');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("No hay imagen seleccionada.")));
      }
    });
  }

  Future<void> _actualizarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final productoAdminId = widget.producto['adminId'];

    final currentUser = FirebaseAuth.instance.currentUser!;
    String currentAdminId = currentUser.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      currentAdminId = userDoc['adminId'];
    }

    if (productoAdminId != currentAdminId) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No tienes permiso para editar este producto'),
        ),
      );
      return;
    }

    String? imageUrl = widget.producto['imagen'];

    if (_image != null) {
      final uploadedUrl = await imageUploadService(_image!);
      if (uploadedUrl != null) {
        imageUrl = uploadedUrl;
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Error subiendo la nueva imagen')),
        );
        return;
      }
    }

    await FirebaseFirestore.instance
        .collection('productos')
        .doc(widget.producto.id)
        .update({
          'nombre': _nombreController.text.trim(),
          'contenido': _contenidoController.text.trim(),
          'precio': double.tryParse(_precioController.text.trim()),
          'marca': _marcaController.text.trim(),
          'categoria': _selectedCategory,
          'clasificacion': _selectedClasifica,
          'imagen': imageUrl,
          'fecha_actualizacion': Timestamp.now(),
        });

    messenger.showSnackBar(
      const SnackBar(content: Text('Producto actualizado correctamente')),
    );

    navigator.pop(true);
  }

  Future<void> _loadCategoriesAndClasificaciones() async {
    // Ejemplo para cargar categorías desde Firestore
    final currentUser = FirebaseAuth.instance.currentUser!;
    String adminId = currentUser.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    final categoriasSnapshot = await FirebaseFirestore.instance
        .collection('categorias')
        .where('adminId', isEqualTo: adminId)
        .get();

    final clasificacionesSnapshot = await FirebaseFirestore.instance
        .collection('clasificacion')
        .where('adminId', isEqualTo: adminId)
        .get();

    setState(() {
      _tipoCategory = categoriasSnapshot.docs
          .map((doc) => doc['nombre'] as String)
          .toList();
      _listClasifica = clasificacionesSnapshot.docs
          .map((doc) => doc['nombre'] as String)
          .toList();

      // Si la categoría o clasificación actual del producto no está en las listas, la añadimos
      if (_selectedCategory != null &&
          !_tipoCategory.contains(_selectedCategory)) {
        _tipoCategory.add(_selectedCategory!);
      }
      if (_selectedClasifica != null &&
          !_listClasifica.contains(_selectedClasifica)) {
        _listClasifica.add(_selectedClasifica!);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _nombreController = TextEditingController(
      text: widget.producto['nombre'] ?? '',
    );
    _contenidoController = TextEditingController(
      text: widget.producto['contenido'] ?? '',
    );
    _precioController = TextEditingController(
      text: (widget.producto['precio'] ?? 0).toString(),
    );
    _marcaController = TextEditingController(
      text: widget.producto['marca'] ?? '',
    );

    _selectedCategory = widget.producto['categoria'];
    _selectedClasifica = widget.producto['clasificacion'];

    _loadCategoriesAndClasificaciones();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _contenidoController.dispose();
    _precioController.dispose();
    _marcaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editar productos")),
      body: _tipoCategory.isEmpty || _listClasifica.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      items: _tipoCategory.map((String id) {
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(id),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val),
                      validator: (value) =>
                          value == null ? 'Seleccione una categoría' : null,
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
                      items: _listClasifica.map((String id) {
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(id),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedClasifica = val),
                      validator: (value) =>
                          value == null ? 'Seleccione una presentación' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _nombreController,
                      decoration: InputDecoration(labelText: "Nombre"),
                      style: TextStyle(overflow: TextOverflow.ellipsis),
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
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: _image == null
                                ? (widget.producto['imagen'] != null
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: widget.producto['imagen'],
                                            fit: BoxFit.cover,
                                            width: 100,
                                            height: 100,
                                            placeholder: (context, url) =>
                                                const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error),
                                          ),
                                        )
                                      : const Icon(Icons.camera_alt, size: 50))
                                : ClipOval(
                                    child: Image.file(
                                      _image!,
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                    ),
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              height: 32,
                              width: 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: _actualizarProducto,
                      child: Text("Guardar"),
                    ),
                    const SizedBox(height: 65),
                  ],
                ),
              ),
            ),
    );
  }
}
