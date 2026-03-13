import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddClientes extends StatefulWidget {
  const AddClientes({super.key});

  @override
  State<AddClientes> createState() => _AddClientesState();
}

class _AddClientesState extends State<AddClientes> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _empresaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _barrioController = TextEditingController();
  final _correoController = TextEditingController();

  String? _selectedTipoIden;
  final List<String> _tipoClient = ['Normal', 'Especial'];

  void createClientes() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Obtener el adminId (puede ser el mismo UID o del admin si es asistente)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String adminId = user.uid;
      if (userDoc.exists && userDoc.data()?['adminId'] != null) {
        adminId = userDoc['adminId'];
      }

      final nombre = _nombreController.text.trim();
      final apellido = _apellidoController.text.trim();

      await FirebaseFirestore.instance.collection('clientes').add({
        'tipo': _selectedTipoIden,
        'nombreCompleto': '$nombre $apellido',
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'empresa': _empresaController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'barrio': _barrioController.text.trim(),
        'correo': _correoController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'adminId': adminId,
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Cliente creado exitosamente')),
      );
      navigator.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Agregar cliente")),
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
                  initialValue: _selectedTipoIden,
                  decoration: InputDecoration(
                    labelText: 'Tipo de cliente',
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
                  items: _tipoClient.map((String id) {
                    return DropdownMenuItem<String>(value: id, child: Text(id));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTipoIden = newValue;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Por favor seleccione una opción' : null,
                ),
                SizedBox(height: 15),
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
                SizedBox(height: 15),
                TextFormField(
                  controller: _apellidoController,
                  decoration: InputDecoration(labelText: "Apellido"),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo requerido';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _empresaController,
                  decoration: InputDecoration(
                    labelText: "Nombre de la empresa",
                  ),
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _telefonoController,
                  decoration: InputDecoration(labelText: "Telefono"),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo requerido';
                    }
                    if (!RegExp(r'^\d{9,15}$').hasMatch(value)) {
                      return 'Teléfono inválido';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _direccionController,
                  decoration: InputDecoration(labelText: "Dirección"),
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _barrioController,
                  decoration: InputDecoration(labelText: "Barrio"),
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _correoController,
                  decoration: InputDecoration(labelText: "Correo"),
                  style: TextStyle(overflow: TextOverflow.ellipsis),
                  validator: (value) {
                    // if (value == null || value.isEmpty) {
                    //   return 'Por favor ingresa tu email';
                    // }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),
                ElevatedButton(
                  onPressed: createClientes,
                  child: Text("Guardar"),
                ),
                const SizedBox(height: 65),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
