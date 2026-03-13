import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditClientes extends StatefulWidget {
  final DocumentSnapshot cliente;
  const EditClientes({super.key, required this.cliente});

  @override
  State<EditClientes> createState() => _EditClientesState();
}

class _EditClientesState extends State<EditClientes> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _empresaController;
  late TextEditingController _telefonoController;
  late TextEditingController _direccionController;
  late TextEditingController _barrioController;
  late TextEditingController _correoController;
  String? _selectedTipoIden;
  final List<String> _tipoClient = ['Normal', 'Especial'];

  @override
  void initState() {
    super.initState();

    final data = widget.cliente.data() as Map<String, dynamic>;

    _nombreController = TextEditingController(text: data['nombre']);
    _apellidoController = TextEditingController(text: data['apellido']);
    _empresaController = TextEditingController(text: data['empresa']);
    _telefonoController = TextEditingController(text: data['telefono']);
    _direccionController = TextEditingController(text: data['direccion']);
    _barrioController = TextEditingController(text: data['barrio']);
    _correoController = TextEditingController(text: data['correo']);
    _selectedTipoIden = data['tipo'];
  }

  void editClientes() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_formKey.currentState!.validate()) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final clienteData = widget.cliente.data() as Map<String, dynamic>;
      final clienteAdminId = clienteData['adminId'];

      // Obtener el adminId del usuario actual (admin o asistente)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      String currentAdminId = currentUser.uid;
      if (userDoc.exists && userDoc.data()?['adminId'] != null) {
        currentAdminId = userDoc['adminId'];
      }

      // Validar si este cliente pertenece al admin actual
      if (clienteAdminId != currentAdminId) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No tienes permiso para editar este cliente'),
          ),
        );
        return;
      }

      final nombre = _nombreController.text.trim();
      final apellido = _apellidoController.text.trim();

      await FirebaseFirestore.instance
          .collection('clientes')
          .doc(widget.cliente.id)
          .update({
            'nombreCompleto': '$nombre $apellido',
            'nombre': _nombreController.text.trim(),
            'apellido': _apellidoController.text.trim(),
            'empresa': _empresaController.text.trim(),
            'telefono': _telefonoController.text.trim(),
            'direccion': _direccionController.text.trim(),
            'barrio': _barrioController.text.trim(),
            'correo': _correoController.text.trim(),
            'tipo': _selectedTipoIden,
          });

      messenger.showSnackBar(
        const SnackBar(content: Text('Cliente actualizado correctamente')),
      );
      navigator.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editar cliente")),
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
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(overflow: TextOverflow.ellipsis),
                ),
                SizedBox(height: 15),
                ElevatedButton(
                  onPressed: editClientes,
                  child: Text("Actualizar"),
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
