import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Clientes/clientes.dart';
import 'package:flutter_project_product/Inventario/inventario.dart';
import 'package:flutter_project_product/Layout/BottomNavigatorBar/settings_account.dart';
import 'package:flutter_project_product/Layout/BottomNavigatorBar/dashboard.dart';
import 'package:flutter_project_product/Pedidos/pedidos.dart';
import 'package:flutter_project_product/Productos/productos.dart';

class IniLayout extends StatefulWidget {
  const IniLayout({super.key});

  @override
  State<IniLayout> createState() => _IniLayoutState();
}

class _IniLayoutState extends State<IniLayout> {
  String? nombre;
  String? empresa;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        if (mounted) {
          setState(() {
            nombre = 'Usuario no encontrado';
            empresa = '';
            _isLoading = false;
          });
        }
        return;
      }

      final userData = userDoc.data()!;
      final role = userData['role'] ?? 'unknown';

      String nombreFinal = userData['name'] ?? 'Sin nombre';
      String empresaFinal = 'Sin empresa';

      if (role == 'admin') {
        empresaFinal = userData['empresa'] ?? 'Sin empresa';
      } else if (role == 'asistente') {
        final creadorUid = userData['adminId'];
        if (creadorUid != null) {
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(creadorUid)
              .get();

          if (adminDoc.exists) {
            final adminData = adminDoc.data()!;
            empresaFinal = adminData['empresa'] ?? 'Sin empresa';
          }
        }
      }

      if (mounted) {
        setState(() {
          nombre = nombreFinal;
          empresa = empresaFinal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          nombre = 'Error al cargar datos';
          empresa = '';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLoading
              ? 'Cargando empresa...'
              : (empresa?.isNotEmpty == true
                    ? empresa!
                    : 'Empresa no disponible'),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 8),
            child: Column(
              children: [
                const SizedBox(height: 50),
                Text(
                  _isLoading
                      ? 'Bienvenid@ nombre del usuario'
                      : 'Bienvenid@ ${nombre ?? "Usuario"}',
                  style: const TextStyle(fontSize: 30),
                ),
                const SizedBox(height: 50),
                ActionButtonWidget(
                  nameButton: "Pedidos",
                  actionButton: () {
                    navigator.push(
                      MaterialPageRoute(builder: (context) => const Pedidos()),
                    );
                  },
                ),
                const SizedBox(height: 50),
                ActionButtonWidget(
                  nameButton: "Productos",
                  actionButton: () {
                    navigator.push(
                      MaterialPageRoute(
                        builder: (context) => const Productos(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),
                ActionButtonWidget(
                  nameButton: "Clientes",
                  actionButton: () {
                    navigator.push(
                      MaterialPageRoute(builder: (context) => const Clientes()),
                    );
                  },
                ),
                const SizedBox(height: 50),
                ActionButtonWidget(
                  nameButton: "Inventario",
                  actionButton: () {
                    navigator.push(
                      MaterialPageRoute(
                        builder: (context) => const Inventario(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.react,
        height: 70,
        initialActiveIndex: 1,
        backgroundColor: theme.colorScheme.primary,
        activeColor: theme.colorScheme.onPrimary,
        color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
        items: const [
          TabItem(icon: Icons.dashboard_outlined, title: "Reporte"),
          TabItem(icon: Icons.home, title: "Inicio"),
          TabItem(icon: Icons.settings, title: "Ajustes"),
        ],
        onTap: (int index) {
          switch (index) {
            case 0:
              navigator.pushReplacement(
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
              break;
            case 1:
              break;
            case 2:
              navigator.pushReplacement(
                MaterialPageRoute(builder: (context) => const SettingsAcount()),
              );
              break;
          }
        },
      ),
    );
  }
}

class ActionButtonWidget extends StatelessWidget {
  const ActionButtonWidget({
    super.key,
    required this.nameButton,
    required this.actionButton,
  });

  final String nameButton;
  final VoidCallback actionButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white54, width: 2.0),
        borderRadius: BorderRadius.circular(30),
      ),
      width: double.infinity,
      height: 70,
      child: ElevatedButton(
        onPressed: actionButton,
        child: Text(
          nameButton,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
