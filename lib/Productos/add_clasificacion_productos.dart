import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddClasificacionProductos extends StatefulWidget {
  const AddClasificacionProductos({super.key});

  @override
  State<AddClasificacionProductos> createState() =>
      _AddClasificacionProductosState();
}

class _AddClasificacionProductosState extends State<AddClasificacionProductos> {
  List<DocumentSnapshot> _clasificaciones = [];
  bool _isAdmin = false;
  String? adminId;

  @override
  void initState() {
    super.initState();
    cargarClasificaciones();
  }

  Future<void> cargarClasificaciones() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    adminId = user.uid;

    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    _isAdmin = userDoc.data()?['role'] == 'admin';

    final snapshot = await FirebaseFirestore.instance
        .collection('clasificacion')
        .where('adminId', isEqualTo: adminId)
        .get();

    setState(() {
      _clasificaciones = snapshot.docs;
    });
  }

  Future<void> mostrarFormularioClasificacion({DocumentSnapshot? doc}) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: doc?['nombre']);
    final navigator = Navigator.of(context);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          doc == null ? "Agregar clasificación" : "Editar clasificación",
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: "Nombre"),
            validator: (value) =>
                value == null || value.isEmpty ? "Campo requerido" : null,
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
                final data = {
                  'nombre': controller.text.trim(),
                  'adminId': adminId,
                };

                if (doc == null) {
                  await FirebaseFirestore.instance
                      .collection('clasificacion')
                      .add(data);
                } else {
                  await FirebaseFirestore.instance
                      .collection('clasificacion')
                      .doc(doc.id)
                      .update(data);
                }
                navigator.pop();
                await cargarClasificaciones();
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> eliminarClasificacion(String id) async {
    await FirebaseFirestore.instance
        .collection('clasificacion')
        .doc(id)
        .delete();
    await cargarClasificaciones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionar Clasificaciones"),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => mostrarFormularioClasificacion(),
            ),
        ],
      ),
      body: _clasificaciones.isEmpty
          ? const Center(child: Text("No hay clasificaciones"))
          : ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _clasificaciones.length,
              itemBuilder: (_, i) {
                final clas = _clasificaciones[i];
                return ListTile(
                  title: Text(clas['nombre']),
                  trailing: _isAdmin
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  mostrarFormularioClasificacion(doc: clas),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => eliminarClasificacion(clas.id),
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
