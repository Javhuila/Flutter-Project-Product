import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'edit_clientes.dart';

class InfoClientes extends StatefulWidget {
  final DocumentSnapshot cliente;
  const InfoClientes({super.key, required this.cliente});

  @override
  State<InfoClientes> createState() => _InfoClientesState();
}

class _InfoClientesState extends State<InfoClientes> {
  String? _userRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.cliente.data() as Map<String, dynamic>;

    final nombre = data['nombreCompleto'] ?? '';
    final empresa = data['empresa'] ?? '';
    final telefono = data['telefono'] ?? '';
    final direccion = data['direccion'] ?? '';
    final barrio = data['barrio'] ?? '';
    final correo = data['correo'] ?? '';
    final tipo = data['tipo'] ?? '';

    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Información del Cliente"),
        actions: [
          if (_userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: "Editar cliente",
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditClientes(cliente: widget.cliente),
                  ),
                );
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildSectionTitle("Nombre completo"),
                      Text(
                        nombre,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Empresa"),
                      Text(
                        empresa,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Teléfono"),
                      Text(
                        telefono,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Dirección"),
                      Text(
                        direccion,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Barrio"),
                      Text(
                        barrio,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Correo electrónico"),
                      Text(
                        correo,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Tipo de cliente"),
                      Chip(
                        label: Text(tipo),
                        backgroundColor: tipo == 'Especial'
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.grey,
      ),
    );
  }
}
