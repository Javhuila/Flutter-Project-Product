import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Layout/BottomNavigatorBar/Account/list_asistente.dart';
import 'package:flutter_project_product/Layout/BottomNavigatorBar/Account/profile.dart';
import 'package:flutter_project_product/Layout/BottomNavigatorBar/dashboard.dart';
import 'package:flutter_project_product/Layout/ini_layout.dart';
import 'package:flutter_project_product/Theme/catalogo_color.dart';
import 'package:flutter_project_product/Theme/tamano_fuente.dart';
import 'package:flutter_project_product/Theme/theme_provider.dart';
import 'package:provider/provider.dart';

import '../../Service/auth_service.dart';
import '../../Service/auth_wrapper.dart';

class SettingsAcount extends StatefulWidget {
  const SettingsAcount({super.key});

  @override
  State<SettingsAcount> createState() => _SettingsAcountState();
}

class _SettingsAcountState extends State<SettingsAcount> {
  final AuthService _authService = AuthService();

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

  void _mostrarSelectorDeColores(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Elige un catálogo de colores"),
        content: RadioGroup<ColorCatalogo>(
          groupValue: themeProvider.catalogo,
          onChanged: (ColorCatalogo? nuevo) {
            if (nuevo != null) {
              themeProvider.setCatalogo(nuevo);
              Navigator.pop(context);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ColorCatalogo.values.map((catalogo) {
              final colorPrincipal = PaletasDeColores.getContainerColor(
                catalogo,
                Theme.of(context).brightness,
              );

              return RadioListTile<ColorCatalogo>(
                value: catalogo,
                title: Row(
                  children: [
                    CircleAvatar(backgroundColor: colorPrincipal, radius: 10),
                    const SizedBox(width: 10),
                    Text(catalogo.name.toUpperCase()),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _mostrarSelectorDeFuente(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Selecciona el tamaño de fuente"),
        content: RadioGroup<FontSizeOption>(
          groupValue: themeProvider.fontSize,
          onChanged: (FontSizeOption? nuevo) {
            if (nuevo != null) {
              themeProvider.setFontSize(nuevo);
              Navigator.pop(context);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: FontSizeOption.values.map((sizeOption) {
              return RadioListTile<FontSizeOption>(
                value: sizeOption,
                title: Text(sizeOption.label),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final navigator = Navigator.of(context);

    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Ajustes"), elevation: 10),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 25),
            const Center(
              child: CircleAvatar(child: Icon(Icons.person_pin, size: 50)),
            ),
            const SizedBox(height: 15),
            const Divider(),
            const SizedBox(height: 5),
            ListTile(
              leading: Icon(Icons.person_search_rounded),
              title: Text("Perfil"),
              onTap: () {
                navigator.push(
                  MaterialPageRoute(builder: (_) => const Profile()),
                );
              },
            ),
            if (_userRole == 'admin') ...[
              const SizedBox(height: 5),
              const Divider(),
              const SizedBox(height: 5),
              ListTile(
                leading: Icon(Icons.people_rounded),
                title: Text("Cuentas de asistentes"),
                onTap: () {
                  navigator.push(
                    MaterialPageRoute(builder: (_) => const ListAsistente()),
                  );
                },
              ),
            ],
            const SizedBox(height: 5),
            const Divider(),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dark_mode),
                      SizedBox(width: 10),
                      Text("Modo Oscuro", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  Switch(
                    value: themeProvider.modoOscuro,
                    onChanged: (value) => themeProvider.toggleModoOscuro(value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            const Divider(),
            const SizedBox(height: 5),
            ListTile(
              leading: Icon(Icons.color_lens_outlined),
              title: Text("Selección de colores"),
              onTap: () => _mostrarSelectorDeColores(context, themeProvider),
            ),
            const SizedBox(height: 5),
            const Divider(),
            ListTile(
              leading: Icon(Icons.format_size),
              title: Text("Tamaño de fuente"),
              subtitle: Text(themeProvider.fontSize.label),
              onTap: () => _mostrarSelectorDeFuente(context, themeProvider),
            ),
            const SizedBox(height: 5),
            const Divider(),
            const SizedBox(height: 5),
            ListTile(
              leading: Icon(Icons.power_settings_new_rounded),
              title: Text("Cerrar Sesión"),
              onTap: () async {
                await _authService.logout();

                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 5),
            const Divider(),
            const SizedBox(height: 5),
          ],
        ),
      ),
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.react,
        height: 70,
        initialActiveIndex: 2,
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const IniLayout()),
              );
              break;
            case 2:
              break;
          }
        },
      ),
    );
  }
}
