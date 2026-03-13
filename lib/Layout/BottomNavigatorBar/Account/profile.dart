import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Service/Cloudinary/image_upload_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _formKey = GlobalKey<FormState>();
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _empresaController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _nitEmpresaController = TextEditingController();

  bool _isLoading = true;

  String _userRole = 'unknown';
  bool _isEditable = false;

  String? _firmaUrl;
  final _signatureController = SignatureController(
    penColor: Colors.black,
    penStrokeWidth: 4,
    exportPenColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _empresaController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _nitEmpresaController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<File?> _convertSignatureToFile(SignatureController controller) async {
    final Uint8List? pngBytes = await controller.toPngBytes();
    if (pngBytes == null) return null;

    final tempDir = await getTemporaryDirectory();
    final file = await File(
      '${tempDir.path}/firma_${DateTime.now().millisecondsSinceEpoch}.png',
    ).create();
    await file.writeAsBytes(pngBytes);
    return file;
  }

  Future<void> _loadProfileData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) throw Exception('Usuario no encontrado.');

      final userData = userDoc.data()!;
      _userRole = userData['role'];
      _nameController.text = userData['name'] ?? '';
      _firmaUrl = userData['firmaUrl'];

      if (_userRole == 'admin') {
        _isEditable = true;

        _empresaController.text = userData['empresa'] ?? '';
        _telefonoController.text = userData['telefono'] ?? '';
        _direccionController.text = userData['direccion'] ?? '';
        _nitEmpresaController.text = userData['nitEmpresa'] ?? '';
      } else if (_userRole == 'asistente') {
        _isEditable = false;

        // Buscar datos del admin que creó este asistente
        final adminId = userData['adminId'];
        if (adminId != null) {
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(adminId)
              .get();

          if (adminDoc.exists) {
            final adminData = adminDoc.data()!;
            _empresaController.text = adminData['empresa'] ?? '';
            _telefonoController.text = adminData['telefono'] ?? '';
            _direccionController.text = adminData['direccion'] ?? '';
            _nitEmpresaController.text = adminData['nitEmpresa'] ?? '';
          }
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error cargando perfil: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!_isEditable) return;

    if (_formKey.currentState!.validate()) {
      try {
        String? firmaUrl;

        if (!_signatureController.isNotEmpty) {
          final file = await _convertSignatureToFile(_signatureController);
          if (file != null) {
            firmaUrl = await imageUploadService(file);
          }
        }

        final updateData = {
          'name': _nameController.text.trim(),
          'empresa': _empresaController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'direccion': _direccionController.text.trim(),
          'nitEmpresa': _nitEmpresaController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (firmaUrl != null) {
          updateData['firmaUrl'] = firmaUrl;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(updateData);

        messenger.showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        _signatureController.clear();
        setState(() => _firmaUrl = firmaUrl);
        navigator.pop();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nombre',
                      readOnly: !_isEditable,
                    ),
                    _buildTextField(
                      controller: _empresaController,
                      label: 'Nombre de la empresa',
                      readOnly: _userRole != 'admin',
                    ),
                    _buildTextField(
                      controller: _nitEmpresaController,
                      label: 'NIT de la empresa',
                      readOnly: _userRole != 'admin',
                    ),
                    _buildTextField(
                      controller: _telefonoController,
                      label: 'Teléfono del administrador',
                      keyboardType: TextInputType.phone,
                      readOnly: _userRole != 'admin',
                    ),
                    _buildTextField(
                      controller: _direccionController,
                      label: 'Dirección de la empresa',
                      readOnly: _userRole != 'admin',
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Firma digital",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (_firmaUrl != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Image.network(
                          _firmaUrl!,
                          height: 150,
                          errorBuilder: (_, _, _) =>
                              const Text("No se pudo cargar la firma."),
                        ),
                      ),
                    if (_isEditable)
                      TextButton(
                        onPressed: _mostrarDialogoFirma,
                        child: const Text('Actualizar firma'),
                      ),
                    ElevatedButton(
                      onPressed: _updateProfile,
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (!readOnly && (value == null || value.isEmpty)) {
            return 'Campo requerido';
          }
          return null;
        },
      ),
    );
  }

  void _mostrarDialogoFirma() {
    final tempController = SignatureController(
      penColor: Colors.black,
      penStrokeWidth: 4,
      exportPenColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            width: double.infinity,
            height: 350,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Agregar / Actualizar Firma',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(),
                    color: Colors.grey[200],
                  ),
                  child: Signature(
                    controller: tempController,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => tempController.clear(),
                      child: const Text("Limpiar firma"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (tempController.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Firma vacía. Intenta de nuevo.'),
                            ),
                          );
                          return;
                        }

                        final file = await _convertSignatureToFile(
                          tempController,
                        );
                        if (file != null) {
                          final newUrl = await imageUploadService(file);
                          if (newUrl != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({'firmaUrl': newUrl});

                            setState(() {
                              _firmaUrl = newUrl;
                            });

                            navigator.pop();

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Firma guardada correctamente.'),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text("Guardar"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => navigator.pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
