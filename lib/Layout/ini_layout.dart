import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Clientes/clientes.dart';
import 'package:flutter_project_product/Compras/compra_venta.dart';
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

enum CardAnimationType { bounce, rotate, shake, pulse, swing }

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
                const SizedBox(height: 30),
                Text(
                  _isLoading
                      ? 'Bienvenid@ nombre del usuario'
                      : 'Bienvenid@ ${nombre ?? "Usuario"}',
                  style: const TextStyle(fontSize: 30),
                ),
                const SizedBox(height: 30),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    DashboardCard(
                      title: "Pedidos",
                      animationType: CardAnimationType.bounce,
                      icon: Icons.pending_actions_sharp,
                      onTap: () {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => const Pedidos(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: "Productos",
                      animationType: CardAnimationType.rotate,
                      icon: Icons.category,
                      onTap: () {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => const Productos(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: "Clientes",
                      animationType: CardAnimationType.shake,
                      icon: Icons.people_outline,
                      onTap: () {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => const Clientes(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: "Inventario",
                      animationType: CardAnimationType.pulse,
                      icon: Icons.inventory_2_outlined,
                      onTap: () {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => const Inventario(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: "Compra",
                      animationType: CardAnimationType.swing,
                      icon: Icons.shopify_sharp,
                      onTap: () {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => const CompraVenta(),
                          ),
                        );
                      },
                    ),
                  ],
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

class DashboardCard extends StatefulWidget {
  final String title;
  final CardAnimationType animationType;
  final IconData icon;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.animationType,
    required this.icon,
    required this.onTap,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scheduleAnimation();
  }

  void _scheduleAnimation() {
    final random = Random();

    final delay = Duration(seconds: random.nextInt(5) + 2);

    _timer = Timer(delay, () async {
      try {
        await _controller.forward();
        await _controller.reverse();
      } catch (_) {}

      if (mounted) {
        _scheduleAnimation();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
        },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  color: Colors.black12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildAnimatedIcon(widget.icon),
                const SizedBox(height: 10),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildAnimatedIcon(IconData icon) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        switch (widget.animationType) {
          case CardAnimationType.bounce:
            return Transform.translate(
              offset: Offset(0, -10 * sin(_controller.value * pi)),
              child: Icon(
                icon,
                size: 50,
                color: Theme.of(context).primaryColor,
              ),
            );
          case CardAnimationType.rotate:
            return Transform.rotate(
              angle: _controller.value * 0.4,
              child: Icon(
                icon,
                size: 50,
                color: Theme.of(context).primaryColor,
              ),
            );
          case CardAnimationType.shake:
            return Transform.translate(
              offset: Offset(sin(_controller.value * 20) * 5, 0),
              child: Icon(
                icon,
                size: 50,
                color: Theme.of(context).primaryColor,
              ),
            );
          case CardAnimationType.pulse:
            return Transform.scale(
              scale: 1 + (_controller.value * 0.15),
              child: Icon(
                icon,
                size: 50,
                color: Theme.of(context).primaryColor,
              ),
            );
          case CardAnimationType.swing:
            return Transform.rotate(
              angle: sin(_controller.value * pi) * 0.25,
              child: Icon(
                icon,
                size: 50,
                color: Theme.of(context).primaryColor,
              ),
            );
        }
      },
    );
  }
}
