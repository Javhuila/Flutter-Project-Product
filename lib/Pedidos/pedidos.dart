import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Layout/ini_layout.dart';
import 'package:flutter_project_product/Pedidos/Pagos/gestion_cuotas.dart';
import 'package:flutter_project_product/Pedidos/Pagos/gestion_fianza.dart';
import 'package:flutter_project_product/Pedidos/Pagos/historial_pagos.dart';
import 'package:flutter_project_product/Pedidos/add_pedidos.dart';
import 'package:flutter_project_product/Pedidos/config_pago.dart';
import 'package:flutter_project_product/Pedidos/edit_pedidos.dart';
import 'package:flutter_project_product/Pedidos/entrega_pedido.dart';
import 'package:flutter_project_product/Pedidos/info_pedido.dart';
import 'package:flutter_project_product/Theme/catalogo_color.dart';
import 'package:flutter_project_product/Theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Pedidos extends StatefulWidget {
  const Pedidos({super.key});

  @override
  State<Pedidos> createState() => _PedidosState();
}

class _PedidosState extends State<Pedidos> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  late AnimationController _brilloController;
  late Animation<double> _brilloAnimation;

  late AnimationController _giroController;
  bool _detenerCicloGiro = false;

  final int _pageSize = 18;
  bool isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocumentInicial;
  DocumentSnapshot? _lastDocumentFiltrado;

  String? _userRole;
  bool _isLoadingRole = true;

  List<DocumentSnapshot> _pedidosCargados = [];
  List<DocumentSnapshot> _pedidosFiltrados = [];
  List<DocumentSnapshot> _pedidosVisibles = [];

  late AnimationController _animationController;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  // String _busqueda = "";
  bool _estaFiltrado = false;

  late String _usuarioIdFiltrado;

  List<String> _fechasUnicas = []; // Lista para almacenar las fechas únicas
  String? _fechaSeleccionada =
      'Todos'; // Variable para almacenar la fecha seleccionada
  Map<String, List<DocumentSnapshot>> pedidosPorFecha = {};

  List<Map<String, dynamic>> _usuarios =
      []; // Lista de usuarios (admin y asistente)
  String? _usuarioSeleccionado = 'Todos'; // Usuario seleccionado en el Dropdown
  // String? _entregaSeleccionada = 'Todos'; // Usuario seleccionado en el Dropdown

  Timer? _debounce;

  String _filtroEntrega = 'Todos';

  // String _formaPago = 'entrega';

  final Map<String, ValueNotifier<Map<String, dynamic>?>> _pagoNotifiers = {};

  Future<void> _cargarPedidosInicial() async {
    setState(() {
      isLoading = true;
      _pedidosCargados.clear();
      _pedidosVisibles.clear();
      _lastDocumentInicial = null;
      _hasMore = true;
    });

    Query query = FirebaseFirestore.instance
        .collection("pedidos")
        .where("adminId", isEqualTo: _usuarioIdFiltrado)
        .orderBy("numero_pedido", descending: true)
        .limit(_pageSize);

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocumentInicial = snapshot.docs.last;
      _pedidosCargados = snapshot.docs;
      _pedidosVisibles = snapshot.docs.take(_pageSize).toList();
      _hasMore = snapshot.docs.length == _pageSize;
    } else {
      _hasMore = false;
    }

    setState(() => isLoading = false);
  }

  Future<void> _loadUserRole() async {
    try {
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
          _userRole = 'asistente'; // fallback
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      setState(() {
        _userRole = 'asistente'; // fallback en caso de error
        _isLoadingRole = false;
      });
    }
  }

  Future<void> _determinarUsuarioParaFiltrado() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      if (data.containsKey('adminId')) {
        // Es asistente
        _usuarioIdFiltrado = data['adminId'];
      } else {
        // Es admin
        _usuarioIdFiltrado = user.uid;
      }
    } else {
      _usuarioIdFiltrado = user.uid; // fallback seguro
    }
  }

  // Método para cargar los usuarios admin y sus asistentes
  Future<void> _cargarUsuarios() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() as Map<String, dynamic>;

    // Iniciamos con la opción "Todos"
    List<Map<String, dynamic>> usuarios = [
      {'id': 'Todos', 'name': 'Todos', 'role': 'todos'},
    ];

    if (userData['role'] == 'admin') {
      // Si el usuario es admin, mostrar admin y sus asistentes
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('adminId', isEqualTo: user.uid)
          .get();

      // Agregar al admin a la lista
      usuarios.add({
        'id': user.uid,
        'name': userData['name'] ?? 'Desconocido',
        'role': 'admin',
      });

      // Agregar los asistentes del admin
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['role'] == 'asistente') {
          usuarios.add({
            'id': doc.id,
            'name': data['name'] ?? 'Desconocido',
            'role': 'asistente',
          });
        }
      }
    } else if (userData['role'] == 'asistente') {
      // Si el usuario es asistente, mostrar solo el admin al que pertenece
      final adminId = userData['adminId'];
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .get();
      final adminData = adminDoc.data() as Map<String, dynamic>;

      usuarios.add({
        'id': user.uid,
        'name': userData['name'] ?? 'Desconocido',
        'role': 'asistente',
      });

      usuarios.add({
        'id': adminId,
        'name': adminData['name'] ?? 'Desconocido',
        'role': 'admin',
      });
    }

    if (!mounted) return;

    setState(() {
      _usuarios = usuarios; // Actualizamos la lista de usuarios
      _usuarioSeleccionado = 'Todos'; // Valor por defecto
    });
  }

  String _normalize(String text) {
    const withAccents = 'áàäâãéèëêíìïîóòöôõúùüûñÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuunAAAAAEEEEIIIIOOOOOUUUUN';

    String result = text;

    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }

    return result.toLowerCase().trim();
  }

  void _actualizarPedidosVisibles() {
    final rawQuery = _searchController.text.trim();
    final queryNorm = _normalize(rawQuery);
    List<DocumentSnapshot> pedidosFiltrados = List.from(_pedidosCargados);

    // 1. Filtrar por fecha
    if (_fechaSeleccionada != null && _fechaSeleccionada != 'Todos') {
      pedidosFiltrados = pedidosFiltrados.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        DateTime fechaPedido;
        if (data['fecha'] is Timestamp) {
          fechaPedido = (data['fecha'] as Timestamp).toDate();
        } else if (data['fecha'] is String) {
          fechaPedido = DateTime.tryParse(data['fecha']) ?? DateTime.now();
        } else {
          fechaPedido = DateTime.now();
        }
        final fechaStr = _formatearFecha(fechaPedido);
        return _normalize(fechaStr) == _normalize(_fechaSeleccionada!);
      }).toList();
    }

    // 2. Filtrar por usuario
    if (_usuarioSeleccionado != null && _usuarioSeleccionado != 'Todos') {
      pedidosFiltrados = pedidosFiltrados.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final adminId = data['adminId'];
        final creadoPor = data['creado_por'];
        return adminId == _usuarioSeleccionado ||
            creadoPor == _usuarioSeleccionado;
      }).toList();
    }

    // 3. Filtrar por búsqueda (cliente o fecha)
    if (queryNorm.isNotEmpty) {
      pedidosFiltrados = pedidosFiltrados.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final cliente = _normalize((data['cliente'] ?? '').toString());

        DateTime? fechaObj;
        if (data['fecha'] is Timestamp) {
          fechaObj = (data['fecha'] as Timestamp).toDate();
        } else if (data['fecha'] is String) {
          fechaObj = DateTime.tryParse(data['fecha']);
        }
        String fechaStr = '';
        if (fechaObj != null) {
          fechaStr = _formatearFecha(fechaObj);
        }

        return cliente.contains(queryNorm) ||
            _normalize(fechaStr).contains(queryNorm);
      }).toList();
    }

    // 4. Filtrar por estado de entrega
    if (_filtroEntrega == 'Entregados') {
      pedidosFiltrados = pedidosFiltrados.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['entregado'] ?? false) == true;
      }).toList();
    } else if (_filtroEntrega == 'No entregados') {
      pedidosFiltrados = pedidosFiltrados.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['entregado'] ?? false) == false;
      }).toList();
    }

    // 5. Decide cuántos mostrar (paginación parcial o completa hasta límite)
    if (_estaFiltrado) {
      // En modo filtrado, mostrar hasta _pageSize por defecto, luego poder “cargar más” si hay más
      final mostrar = pedidosFiltrados.take(_pageSize).toList();
      setState(() {
        _pedidosVisibles = mostrar;
        // Si hay más de pageSize resultados filtrados, permitir “cargar más”
        _hasMore = pedidosFiltrados.length > _pageSize;
      });
    } else {
      // En modo normal (sin filtro/búsqueda), respetar la paginación que ya cargaste desde Firestore
      final mostrar = pedidosFiltrados.take(_pedidosCargados.length).toList();
      setState(() {
        _pedidosVisibles = mostrar;
        // En este modo, _hasMore ya lo calculaste con Firestore
        // _hasMore se mantiene tal cual lo definiste al cargar más
        // No se necesita recalcularlo aquí
      });
    }
  }

  Future<void> _cargarPedidosFiltradosDesdeFirestore({
    bool reset = true,
  }) async {
    // Asegurar usuario admin si aún no determinado
    await _determinarUsuarioParaFiltrado();

    if (reset) {
      setState(() {
        isLoading = true;
        _isLoadingMore = false;
        _hasMore = true;
        _lastDocumentFiltrado = null;
        _pedidosCargados.clear();
        _pedidosFiltrados.clear();
        _pedidosVisibles.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    // Construir query base (siempre restringimos adminId para seguridad)
    Query query = FirebaseFirestore.instance
        .collection('pedidos')
        .where('adminId', isEqualTo: _usuarioIdFiltrado);

    // --- Aplicar filtro de fecha (si aplica) ---
    final bool hayFecha =
        _fechaSeleccionada != null && _fechaSeleccionada != 'Todos';
    if (hayFecha) {
      final rango = _rangoDiaDesdeClave(_fechaSeleccionada!);
      query = query
          .where(
            'fecha',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango['inicio']!),
          )
          .where(
            'fecha',
            isLessThanOrEqualTo: Timestamp.fromDate(rango['fin']!),
          );
    }

    // --- Aplicar filtro de usuario (solo cuando fecha != Todos y usuario != Todos) ---
    final bool hayUsuarioSeleccionado =
        _fechaSeleccionada != 'Todos' &&
        _usuarioSeleccionado != null &&
        _usuarioSeleccionado != 'Todos';
    if (hayUsuarioSeleccionado) {
      // `creado_por` y/o adminId pueden contener el uid del autor;
      // Queremos pedidos creados por ese usuario (creado_por) o asociados al adminId.
      // Ya filtramos adminId arriba; aquí filtramos por creado_por igual al usuario seleccionado.
      query = query.where('creado_por', isEqualTo: _usuarioSeleccionado);
    }

    // --- Aplicar filtro de entrega (si aplica) ---
    if (_filtroEntrega == 'Entregados') {
      query = query.where('entregado', isEqualTo: true);
    } else if (_filtroEntrega == 'No entregados') {
      query = query.where('entregado', isEqualTo: false);
    }

    // --- Si se pasa texto de búsqueda, Firestore no hace "contains" nativo.
    // Para búsquedas simples en cliente, cargamos una ventana razonable (pageSize * 4)
    // y filtramos en cliente. Aquí pedimos pageSize (puedes aumentar si quieres más cobertura).
    // Nota: si necesitas búsquedas escalables, piensa en integrar trigram/asistente indexing.
    //
    // Orden por numero_pedido DESC para que muestre los pedidos más recientes (por número)
    if (hayFecha) {
      // Obligatorio: si hay rango por fecha, se debe ordenar POR fecha primero
      query = query
          .orderBy('fecha') // ascendente por defecto — correcto para Firestore
          .orderBy('numero_pedido', descending: true)
          .limit(_pageSize);
    } else {
      // No hay rango → podemos ordenar directamente por numero_pedido
      query = query.orderBy('numero_pedido', descending: true).limit(_pageSize);
    }

    // --- Paginación: usar startAfterDocument cuando no es reset
    if (!reset && _lastDocumentFiltrado != null) {
      query = query.startAfterDocument(_lastDocumentFiltrado!);
    }

    final snapshot = await query.get();

    // Actualizar estados con resultados
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        if (reset) {
          _pedidosCargados = snapshot.docs;
        } else {
          _pedidosCargados.addAll(snapshot.docs);
        }
        _lastDocumentFiltrado = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _pageSize;
      });
    } else {
      if (reset) {
        setState(() {
          _pedidosCargados = [];
          _lastDocumentFiltrado = null;
          _hasMore = false;
        });
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    }

    // Si hay texto de búsqueda - aplicar filtro local adicional en los docs recuperados
    final texto = _searchController.text.trim().toLowerCase();
    List<DocumentSnapshot> resultados = List.from(_pedidosCargados);
    if (texto.isNotEmpty) {
      resultados = resultados.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final cliente = (data['cliente'] ?? '').toString().toLowerCase();
        final numero = (data['numero_pedido'] ?? '').toString().toLowerCase();
        return cliente.contains(texto) || numero.contains(texto);
      }).toList();
    }

    // Ordenar localmente por numero_pedido por seguridad (ya lo pedimos en la query)
    resultados.sort((a, b) {
      final na = (a.data() as Map)['numero_pedido'] ?? 0;
      final nb = (b.data() as Map)['numero_pedido'] ?? 0;
      return (nb as int).compareTo(na as int);
    });

    _pedidosFiltrados = resultados;

    // Guardar filtrados y la primera ventana visible
    setState(() {
      if (reset) {
        _pedidosVisibles = _pedidosFiltrados.take(_pageSize).toList();
      } else {
        final inicio = _pedidosVisibles.length;
        // final fin = inicio + _pageSize;

        _pedidosVisibles.addAll(_pedidosFiltrados.skip(inicio).take(_pageSize));
      }

      isLoading = false;
      _isLoadingMore = false;
    });
  }

  // Future<void> _cargarPedidosPorFecha(String fechaSeleccionada) async {
  //   // await _determinarUsuarioParaFiltrado();

  //   // 1. Obtener el rango del día
  //   final rango = _rangoDiaDesdeClave(fechaSeleccionada);

  //   // 2. Construir consulta base (solo por fecha)
  //   Query query = FirebaseFirestore.instance
  //       .collection('pedidos')
  //       .where(
  //         'fecha',
  //         isGreaterThanOrEqualTo: Timestamp.fromDate(rango['inicio']!),
  //       )
  //       .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(rango['fin']!));

  //   // 3. Si usuario ≠ "Todos" → aplicar filtro por usuario
  //   if (_usuarioSeleccionado != null && _usuarioSeleccionado != "Todos") {
  //     query = query.where('adminId', isEqualTo: _usuarioSeleccionado);
  //   }

  //   // 4. Orden obligatorio por fecha antes de numero_pedido
  //   query = query
  //       .orderBy('fecha', descending: true)
  //       .orderBy('numero_pedido', descending: true)
  //       .limit(_pageSize);

  //   // 5. Ejecutar consulta
  //   final snapshot = await query.get();

  //   setState(() {
  //     _pedidosCargados = snapshot.docs;
  //     _lastDocumentInicial = snapshot.docs.isNotEmpty
  //         ? snapshot.docs.last
  //         : null;
  //     _hasMore = snapshot.docs.length == _pageSize;
  //   });

  //   _actualizarPedidosVisibles(); // Aplica búsqueda / filtros sobre esa carga
  // }

  Map<String, DateTime> _rangoDiaDesdeClave(String claveFecha) {
    final ahora = DateTime.now();
    DateTime inicioDia;
    DateTime finDia;

    if (claveFecha == 'Hoy') {
      inicioDia = DateTime(ahora.year, ahora.month, ahora.day);
      finDia = inicioDia
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
    } else if (claveFecha == 'Ayer') {
      inicioDia = DateTime(
        ahora.year,
        ahora.month,
        ahora.day,
      ).subtract(const Duration(days: 1));
      finDia = inicioDia
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
    } else {
      // claveFecha en formato: "01 de septiembre de 2025"
      final partes = claveFecha.split(' de ');
      if (partes.length == 3) {
        final dia = int.tryParse(partes[0]) ?? 1;
        final mesTexto = partes[1].toLowerCase();
        final anio = int.tryParse(partes[2]) ?? ahora.year;

        const meses = {
          'enero': 1,
          'febrero': 2,
          'marzo': 3,
          'abril': 4,
          'mayo': 5,
          'junio': 6,
          'julio': 7,
          'agosto': 8,
          'septiembre': 9,
          'octubre': 10,
          'noviembre': 11,
          'diciembre': 12,
        };

        final mes = meses[mesTexto] ?? 1;

        inicioDia = DateTime(anio, mes, dia);
        finDia = inicioDia
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
      } else {
        // Fallback: usar hoy
        inicioDia = DateTime(ahora.year, ahora.month, ahora.day);
        finDia = inicioDia
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
      }
    }

    return {'inicio': inicioDia, 'fin': finDia};
  }

  Future<void> _aplicarFiltros() async {
    final texto = _searchController.text.trim().toLowerCase();
    final bool hayBusqueda = texto.isNotEmpty;
    final bool hayFecha =
        _fechaSeleccionada != null && _fechaSeleccionada != 'Todos';
    final bool hayUsuario =
        _usuarioSeleccionado != null && _usuarioSeleccionado != 'Todos';
    final bool hayEntrega = _filtroEntrega != 'Todos';

    _estaFiltrado = hayBusqueda || hayFecha || hayUsuario || hayEntrega;

    // Si NO hay filtros activos: solo mostrar los pedidos cargados inicialmente
    if (!_estaFiltrado) {
      await _cargarPedidosInicial();
      return;
    }

    // Si hay algún filtro → cargar desde Firestore los pedidos que cumplan, paginados
    await _cargarPedidosFiltradosDesdeFirestore(reset: true);
  }

  // Método para calcular el número de pedidos y la suma total
  Future<void> _mostrarResumenPedidos() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await _determinarUsuarioParaFiltrado();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Obtenemos el ID del admin principal
    String adminId = _usuarioIdFiltrado;

    // Si la fecha seleccionada no es válida, salir
    if (_fechaSeleccionada == null || _fechaSeleccionada == 'Todos') {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Selecciona una fecha para ver el resumen'),
        ),
      );
      return;
    }

    // Calculamos rango de la fecha seleccionada
    final rango = _rangoDiaDesdeClave(_fechaSeleccionada!);

    // Construimos la lista de IDs de usuarios a incluir
    List<String> usuariosAIncluir = [];

    if (_usuarioSeleccionado == 'Todos') {
      // Incluimos el admin principal y todos sus asistentes
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('adminId', isEqualTo: adminId)
          .get();

      usuariosAIncluir = [adminId, ...snapshot.docs.map((d) => d.id)];
    } else {
      // Solo el usuario seleccionado
      usuariosAIncluir = [_usuarioSeleccionado!];
    }

    // Consultamos todos los pedidos de esos usuarios dentro del rango de fecha
    final snapshot = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('adminId', isEqualTo: adminId)
        .where(
          'fecha',
          isGreaterThanOrEqualTo: Timestamp.fromDate(rango['inicio']!),
        )
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(rango['fin']!))
        .get();

    // Filtramos localmente los pedidos solo de los usuarios incluidos
    final pedidosFiltrados = snapshot.docs.where((doc) {
      final data = doc.data();
      return usuariosAIncluir.contains(data['creado_por']);
    }).toList();

    // Calculamos totales
    final totalPedidos = pedidosFiltrados.length;
    double sumaTotal = pedidosFiltrados.fold(0, (previousValue, pedido) {
      final data = pedido.data();
      return previousValue + (data['valor_total'] ?? 0.0);
    });

    if (!mounted) return;

    // Mostramos resumen
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resumen de pedidos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Fecha: $_fechaSeleccionada'),
            const SizedBox(height: 10),
            Text('Total de pedidos: $totalPedidos'),
            Text('Suma total: ${sumaTotal.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminacion(BuildContext context, String pedidoId) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Eliminar pedido?'),
          content: const Text('Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('pedidos')
                    .doc(pedidoId)
                    .delete();

                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const Pedidos()),
                  (route) => false,
                );
                messenger.showSnackBar(
                  const SnackBar(content: Text('Pedido eliminado.')),
                );
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cargarPedidos() async {
    await _determinarUsuarioParaFiltrado();

    final snapshot = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('adminId', isEqualTo: _usuarioIdFiltrado)
        .orderBy('numero_pedido', descending: true)
        .limit(_pageSize)
        .get();

    if (!mounted) return;

    setState(() {
      _pedidosCargados = snapshot.docs;
      _lastDocumentInicial = snapshot.docs.isNotEmpty
          ? snapshot.docs.last
          : null;
      _hasMore = snapshot.docs.length == _pageSize;

      pedidosPorFecha = _agruparPorFecha(
        _pedidosCargados,
      ); // Agrupamos los pedidos por fecha

      // Extraemos las fechas únicas
      _fechasUnicas = _pedidosCargados
          .map((pedido) {
            final data = pedido.data() as Map<String, dynamic>;
            final fecha = (data['fecha'] as Timestamp).toDate();
            return _formatearFecha(fecha);
          })
          .toSet()
          .toList();

      // Si solo hay una fecha, la seleccionamos automáticamente
      if (_fechasUnicas.length == 1) {
        _fechaSeleccionada = _fechasUnicas[0];
      }
    });

    _aplicarFiltros(); // Aplica búsqueda si hay texto
  }

  void _filtrarPedidos() {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _pedidosVisibles = List.from(_pedidosCargados);
      });
      return;
    }

    setState(() {
      _pedidosVisibles = _pedidosCargados.where((pedido) {
        final data = pedido.data() as Map<String, dynamic>;
        final cliente = (data['cliente'] ?? '').toString().toLowerCase();
        final fechaObj = data['fecha'] is Timestamp
            ? (data['fecha'] as Timestamp).toDate()
            : null;

        final fechaStr = fechaObj != null
            ? "${fechaObj.day.toString().padLeft(2, '0')}/${fechaObj.month.toString().padLeft(2, '0')}/${fechaObj.year}"
            : '';

        return cliente.contains(query) || fechaStr.contains(query);
      }).toList();
    });
  }

  Future<void> _cargarMasPedidos() async {
    if (_isLoadingMore || !_hasMore) return;

    // MODO SIN FILTROS
    if (!_estaFiltrado) {
      if (_lastDocumentInicial == null) return;

      setState(() => _isLoadingMore = true);

      final snapshot = await FirebaseFirestore.instance
          .collection("pedidos")
          .where("adminId", isEqualTo: _usuarioIdFiltrado)
          .orderBy("numero_pedido", descending: true)
          .startAfterDocument(_lastDocumentInicial!)
          .limit(_pageSize)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocumentInicial = snapshot.docs.last;
        _pedidosVisibles.addAll(snapshot.docs);
        _hasMore = snapshot.docs.length == _pageSize;
      } else {
        _hasMore = false;
      }

      setState(() => _isLoadingMore = false);
      return;
    }

    // MODO FILTRADO
    await _cargarPedidosFiltradosDesdeFirestore(reset: false);
  }

  Future<void> _cargarFechasUnicasParaAdmin() async {
    await _determinarUsuarioParaFiltrado();

    final snapshot = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('adminId', isEqualTo: _usuarioIdFiltrado)
        .get(const GetOptions(source: Source.server)); // o default

    // Extraer fechas únicas
    final Set<String> fechasSet = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      DateTime fechaPedido;
      if (data['fecha'] is Timestamp) {
        fechaPedido = (data['fecha'] as Timestamp).toDate();
      } else if (data['fecha'] is String) {
        fechaPedido = DateTime.tryParse(data['fecha']) ?? DateTime.now();
      } else {
        fechaPedido = DateTime.now();
      }
      final claveFecha = _formatearFecha(fechaPedido);
      fechasSet.add(claveFecha);
    }

    final fechasList = fechasSet.toList()
      ..sort((a, b) {
        // Si quieres orden descendente por fecha: parsea las fechas y compara
        // O simplemente deja el orden alfabético si _formatear es consistente
        return b.compareTo(a);
      });

    if (!mounted) return;

    setState(() {
      _fechasUnicas = fechasList;
      if (!_fechasUnicas.contains(_fechaSeleccionada)) {
        _fechaSeleccionada = 'Todos';
      }
    });
  }

  Future<void> _eliminarPedidosAntiguos(int dias) async {
    final ahora = DateTime.now();
    final limite = ahora.subtract(Duration(days: dias));

    final snapshot = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('fecha', isLessThan: Timestamp.fromDate(limite))
        .get();

    for (var doc in snapshot.docs) {
      await FirebaseFirestore.instance
          .collection('pedidos')
          .doc(doc.id)
          .delete();
    }
  }

  Future<void> _aplicarPoliticaDeRetencion() async {
    final prefs = await SharedPreferences.getInstance();
    final dias = prefs.getInt('dias_retenidos') ?? 8; // Valor por defecto
    await _eliminarPedidosAntiguos(dias);
  }

  void _mostrarDialogoRetencion() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final prefs = await SharedPreferences.getInstance();
    int diasActuales = prefs.getInt('dias_retenidos') ?? 8;

    if (!mounted) return;
    int? nuevoValor = await showDialog<int>(
      context: context,
      builder: (context) {
        int valorTemp = diasActuales;
        return AlertDialog(
          title: const Text("Elegir días de retención"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    min: 1,
                    max: 15,
                    divisions: 14,
                    value: valorTemp.toDouble(),
                    label: "$valorTemp días",
                    onChanged: (double newVal) {
                      setState(() {
                        valorTemp = newVal.toInt();
                      });
                    },
                  ),
                  Text("Mantener pedidos por $valorTemp días"),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => navigator.pop(),
            ),
            ElevatedButton(
              child: const Text("Guardar"),
              onPressed: () => navigator.pop(valorTemp),
            ),
          ],
        );
      },
    );

    if (nuevoValor != null) {
      await prefs.setInt('dias_retenidos', nuevoValor);

      messenger.showSnackBar(
        SnackBar(content: Text("Configuración actualizada: $nuevoValor días")),
      );
      await _eliminarPedidosAntiguos(nuevoValor); // Ejecutar al momento
      await _cargarPedidos(); // Recargar la lista
    }
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final fechaSinHora = DateTime(fecha.year, fecha.month, fecha.day);

    final diferencia = hoy.difference(fechaSinHora).inDays;

    if (diferencia == 0) return 'Hoy';
    if (diferencia == 1) return 'Ayer';

    // Ej: 01 de septiembre de 2025
    return "${fecha.day.toString().padLeft(2, '0')} de "
        "${_nombreMes(fecha.month)} de ${fecha.year}";
  }

  String _nombreMes(int mes) {
    const meses = [
      '', // posición 0 vacía para que enero sea índice 1
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return meses[mes];
  }

  Map<String, List<DocumentSnapshot>> _agruparPorFecha(
    List<DocumentSnapshot> pedidos,
  ) {
    final Map<String, List<DocumentSnapshot>> agrupados = {};

    for (final pedido in pedidos) {
      final data = pedido.data() as Map<String, dynamic>;
      DateTime fechaPedido;

      if (data['fecha'] is Timestamp) {
        fechaPedido = (data['fecha'] as Timestamp).toDate();
      } else if (data['fecha'] is String) {
        fechaPedido = DateTime.tryParse(data['fecha']) ?? DateTime.now();
      } else {
        fechaPedido = DateTime.now();
      }

      final claveFecha = _formatearFecha(fechaPedido);

      agrupados.putIfAbsent(claveFecha, () => []).add(pedido);
    }

    return agrupados;
  }

  void _iniciarBrilloAleatorio() async {
    while (mounted) {
      // Espera entre 3 a 10 segundos aleatoriamente
      await Future.delayed(Duration(seconds: 3 + (Random().nextInt(7))));

      if (!mounted) return;

      // Reproduce el brillo una vez
      await _brilloController.forward();
      await _brilloController.reverse();
    }
  }

  void _iniciarCicloAnimacion() async {
    while (!_detenerCicloGiro) {
      if (_detenerCicloGiro || !mounted) break;

      // Detener giro inicial al cargar el widget Pedido (15 s)
      if (_giroController.isAnimating) {
        await _giroController.animateTo(
          0,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 800),
        );

        _giroController.stop();
        _giroController.reset();
      }
      await Future.delayed(const Duration(seconds: 15));

      if (_detenerCicloGiro || !mounted) break;

      // Activar giro (15 s)
      if (!_giroController.isAnimating) {
        _giroController.repeat(reverse: true);
      }
      await Future.delayed(const Duration(seconds: 15));

      if (_detenerCicloGiro || !mounted) break;

      // Detener giro (10 s)
      if (_giroController.isAnimating) {
        await _giroController.animateTo(
          0,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 800),
        );

        _giroController.stop();
        _giroController.reset();
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  @override
  void initState() {
    super.initState();
    // _cargarPedidos();
    _determinarUsuarioParaFiltrado().then((_) {
      _cargarFechasUnicasParaAdmin();
      _cargarPedidos();
      _cargarUsuarios();
    });
    _loadUserRole();
    _aplicarPoliticaDeRetencion();
    _searchController.addListener(_filtrarPedidos);

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _actualizarPedidosVisibles();
      });
    });

    _brilloController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _brilloAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _brilloController, curve: Curves.easeInOut),
    );

    _iniciarBrilloAleatorio();

    _giroController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _iniciarCicloAnimacion();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      // -1 Izquierda, 0 Derecha. DX
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _detenerCicloGiro = true;

    _animationController.dispose();
    _brilloController.dispose();
    _giroController.dispose();
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final brightness = Theme.of(context).brightness;
    final shadowColor = PaletasDeColores.getShadowColor(
      themeProvider.catalogo,
      brightness,
    );

    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pedidos"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const IniLayout()),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt),
            tooltip: "Agregar pedido",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPedidos()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Configurar retención",
            onPressed: _mostrarDialogoRetencion,
          ),
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: "Filtros",
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      const Text(
                        "Filtros",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  /// FECHA
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 200, // límite de altura del menú desplegable
                    itemHeight: 49, // altura de cada elemento de la lista
                    initialValue: _fechaSeleccionada,
                    onChanged: (String? newValue) {
                      setState(() {
                        _fechaSeleccionada = newValue;
                        _usuarioSeleccionado =
                            'Todos'; // resetear usuario al cambiar fecha
                      });
                      _aplicarFiltros(); // esta única línea maneja un todo
                    },
                    items: ['Todos', ..._fechasUnicas]
                        .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        })
                        .toList(),
                    decoration: const InputDecoration(labelText: 'Fecha'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _usuarioSeleccionado,
                          onChanged: (_fechaSeleccionada == 'Todos')
                              ? null
                              : (String? newValue) {
                                  setState(
                                    () => _usuarioSeleccionado = newValue,
                                  );
                                  _aplicarFiltros();
                                },

                          items: _usuarios.map<DropdownMenuItem<String>>((
                            Map<String, dynamic> usuario,
                          ) {
                            return DropdownMenuItem<String>(
                              value: usuario['id'],
                              child: Text(usuario['name']),
                            );
                          }).toList(),
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _mostrarResumenPedidos,
                        child: const Text('Info'),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Divider(),
                  SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: _filtroEntrega,
                    onChanged: (value) {
                      setState(() => _filtroEntrega = value!);
                      _aplicarFiltros();
                    },
                    items: const [
                      DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'Entregados',
                        child: Text('Entregados'),
                      ),
                      DropdownMenuItem(
                        value: 'No entregados',
                        child: Text('No entregados'),
                      ),
                    ],
                    decoration: const InputDecoration(labelText: 'Entrega'),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
          child: Column(
            children: [
              SizedBox(height: 20),
              TextFormField(
                controller: _searchController,
                keyboardType: TextInputType.name,
                style: const TextStyle(
                  fontSize: 20,
                  overflow: TextOverflow.ellipsis,
                ),
                decoration: InputDecoration(
                  labelText: "Buscar",
                  hintText: "Buscar pedidos",
                  suffixIcon: const Icon(Icons.search_outlined, size: 40),
                  suffixIconColor: Colors.grey,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Colors.grey),
                    gapPadding: 10,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Colors.grey),
                    gapPadding: 10,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Colors.red, width: 2.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: Colors.deepOrange,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _pedidosVisibles.isEmpty
                  ? const Center(child: Text("No hay pedidos encontrados"))
                  : ListView(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      children: _agruparPorFecha(_pedidosVisibles).entries.map((
                        entry,
                      ) {
                        final fecha = entry.key;
                        final pedidosDeEseDia = entry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10.0,
                                horizontal: 5,
                              ),
                              child: Center(
                                child: Text(
                                  fecha,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            ...pedidosDeEseDia.asMap().entries.map((entry) {
                              final pedido = entry.value;
                              final data =
                                  pedido.data() as Map<String, dynamic>;

                              _pagoNotifiers.putIfAbsent(pedido.id, () {
                                final pago =
                                    data['pago'] as Map<String, dynamic>?;

                                return ValueNotifier<Map<String, dynamic>?>(
                                  pago ??
                                      {
                                        'tipo': data['forma_pago'] ?? 'entrega',
                                        'extra': {'metodo': 'efectivo'},
                                      },
                                );
                              });

                              return _buildPedidoItem(
                                context,
                                pedido,
                                shadowColor,
                                data,
                                theme,
                                _pagoNotifiers[pedido.id]!,
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Center(
                    child: GestureDetector(
                      onTap: _isLoadingMore ? null : _cargarMasPedidos,
                      child: Column(
                        children: [
                          if (_isLoadingMore)
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.download, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            _hasMore
                                ? 'Toca para cargar más...'
                                : 'No hay más pedidos',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 250),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.history),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistorialPagos()),
          );
        },
      ),
    );
  }

  SlideTransition _buildPedidoItem(
    BuildContext context,
    DocumentSnapshot<Object?> pedido,
    Color shadowColor,
    Map<String, dynamic> data,
    ThemeData theme,
    ValueNotifier<Map<String, dynamic>?> pagoNotifier,
  ) {
    final bool esAdmin =
        data['creado_por'] == FirebaseAuth.instance.currentUser?.uid;
    final numBig = data['numero_pedido']?.toString() ?? '0';
    final numSmall = numBig.length > 2
        ? numBig.substring(numBig.length - 2)
        : numBig.padLeft(2, '0');
    const formasPago = {
      'entrega': 'Pago por entrega',
      'bancario': 'Pago bancario',
      'cuotas': 'Cuotas',
      'fianza': 'Fianza / Credito',
    };
    // final pago = pedido['pago'];

    String getTextoFormaPago(String formaPago, Map<String, dynamic>? pago) {
      if (pago == null) {
        return formasPago[formaPago] ?? formaPago;
      }

      final extra = pago['extra'] as Map<String, dynamic>? ?? {};

      // ================= ENTREGA =================
      if (formaPago == 'entrega') {
        final metodo = extra['metodo'] ?? 'Efectivo';
        return 'Pago por entrega - $metodo';
      }

      // ================= BANCARIO =================
      if (formaPago == 'bancario') {
        final entidad = extra['entidad'];
        final otro = extra['otro'];

        final texto = entidad == 'otro'
            ? (otro ?? 'Otro')
            : (entidad ?? 'Bancario');

        return texto.toString().toUpperCase().substring(0, 1) +
            texto.toString().substring(1);
      }

      // ================= CRÉDITO =================
      if (formaPago == 'cuotas' || formaPago == 'fianza') {
        return formasPago[formaPago] ?? formaPago;
      }

      return formasPago[formaPago] ?? formaPago;
    }

    return SlideTransition(
      position: _offsetAnimation,
      child: Column(
        children: [
          GestureDetector(
            onLongPress: () {
              _mostrarInfoEdicion(context, data);
            },
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InfoPedido(pedido: pedido),
                ),
              );
            },
            onDoubleTap: () {
              final pago = pagoNotifier.value;
              final formaPago = pago?['tipo'] ?? 'entrega';
              final referencia = pago?['referencia_pago'];

              if (formaPago == 'entrega' || formaPago == 'bancario') {
                _mostrarDialogFormaPago(context, pedido, pagoNotifier);
                return;
              }

              if ((formaPago == 'cuotas' || formaPago == 'fianza') &&
                  pago == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Este pedido no tiene información de pago registrada',
                    ),
                  ),
                );
                return;
              }

              if (formaPago == 'cuotas') {
                if (referencia == null) {
                  _mostrarDialogFormaPago(context, pedido, pagoNotifier);
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GestionCuotas(pedidoId: pedido.id, deudaId: referencia),
                  ),
                );
                return;
              }

              if (formaPago == 'fianza') {
                if (referencia == null) {
                  _mostrarDialogFormaPago(context, pedido, pagoNotifier);
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GestionFianza(pedidoId: pedido.id, deudaId: referencia),
                  ),
                );
                return;
              }

              // SOLO PARA ENTREGA / BANCARIO
              // _mostrarDialogFormaPago(context, pedido, formaPagoNotifier);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  key: ValueKey(pedido.id),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 20,
                        offset: const Offset(10, 5),
                      ),
                    ],
                    color: shadowColor,
                  ),
                  width: MediaQuery.of(context).size.width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 15,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                ),
                                child: Text(
                                  data['cliente'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ValueListenableBuilder<Map<String, dynamic>?>(
                                valueListenable: pagoNotifier,
                                builder: (context, pago, _) {
                                  final forma = pago?['tipo'] ?? 'entrega';

                                  final texto = getTextoFormaPago(forma, pago);

                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                                    child: Text(
                                      "Forma de pago: $texto",
                                      key: ValueKey(
                                        '${forma}_${pago?['extra']}',
                                      ),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Total: \$${data['valor_total']}",
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 15,
                                children: [
                                  Text(
                                    "Productos: ${data['productos_contabilizado']}",
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 15),
                                  Text(
                                    "Cantidad: ${data['cantidad_total']}",
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          verticalDirection: VerticalDirection.up,
                          spacing: 10,
                          children: [
                            _userRole == "admin"
                                ? PopupMenuButton<int>(
                                    icon: AnimatedIcon(
                                      icon: AnimatedIcons.menu_arrow,
                                      progress: _animationController,
                                    ),
                                    iconSize: 35,
                                    onSelected: (value) {
                                      if (value == 1) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditPedidos(pedido: pedido),
                                          ),
                                        );
                                      } else if (value == 2) {
                                        _confirmarEliminacion(
                                          context,
                                          pedido.id,
                                        );
                                      }
                                    },
                                    itemBuilder: (BuildContext context) {
                                      return [
                                        const PopupMenuItem<int>(
                                          value: 1,
                                          height: 55,
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_document),
                                              SizedBox(width: 8),
                                              Text(
                                                'Editar',
                                                style: TextStyle(fontSize: 25),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem<int>(
                                          value: 2,
                                          height: 55,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline_rounded,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Eliminar',
                                                style: TextStyle(fontSize: 25),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ];
                                    },
                                  )
                                : Container(),
                            SizedBox(
                              width: 45, // evita overflow
                              height: 45,
                              child: AnimatedBuilder(
                                animation: _giroController,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle: esAdmin
                                        ? _giroController.value * 2 * 3.1416
                                        : -_giroController.value * 2 * 3.1416,
                                    child: Transform.scale(
                                      scale:
                                          1 +
                                          (_giroController.value *
                                              0.3), // crece un poco
                                      child: Icon(
                                        esAdmin
                                            ? Icons.stars_rounded
                                            : Icons.stars_outlined,
                                        // color: esAdmin
                                        //     ? theme.primaryColor
                                        //     : theme.colorScheme.secondary,
                                        color:
                                            PaletasDeColores.getColorIconoUsuario(
                                              esAdmin: esAdmin,
                                              theme: theme,
                                              backgroundReal:
                                                  theme.scaffoldBackgroundColor,
                                            ),
                                        size: 45,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: 35),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: -35, // ← Esto lo hace quedar pegado sin espacio
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _brilloAnimation,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // CÍRCULO RECORTADO (solo la mitad se ve)
                            Opacity(
                              opacity: _brilloAnimation.value,
                              child: ClipPath(
                                clipper: _HalfCircleClipper(),
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.primaryColor.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 12 * _brilloAnimation.value,
                                        spreadRadius:
                                            2 * _brilloAnimation.value,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // NÚMERO COMPLETO (NO SE RECORTA)
                            Positioned(
                              top:
                                  32, // mueve el número hacia arriba para que no se tape
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      content: Text(
                                        'Pedido #${data['numero_pedido']}',
                                        style: TextStyle(fontSize: 36),
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  numSmall,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                EntregaPedido(
                  key: ValueKey('entrega_${pedido.id}'),
                  pedido: pedido,
                  onEstadoCambiado: (nuevoEstado) async {
                    setState(() {
                      final index = _pedidosVisibles.indexWhere(
                        (p) => p.id == pedido.id,
                      );

                      if (index != -1) {
                        _pedidosVisibles[index].data['entregado'] = nuevoEstado;
                      }
                    });

                    // También actualiza la fuente de datos (Firestore)
                    await FirebaseFirestore.instance
                        .collection('pedidos')
                        .doc(pedido.id)
                        .update({'entregado': nuevoEstado});

                    // Opcional: vuelve a aplicar filtros si están activos
                    // _aplicarFiltros();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _mostrarDialogFormaPago(
    BuildContext context,
    DocumentSnapshot pedido,
    ValueNotifier<Map<String, dynamic>?> pagoNotifier,
  ) {
    final pagoActual = pagoNotifier.value;

    String? formaPagoSeleccionada = pagoActual?['tipo'] ?? 'entrega';
    String? entidadBancaria = pagoActual?['extra']?['entidad'];
    String? entidadBancariaOtro = pagoActual?['extra']?['otro'];

    final otroController = TextEditingController(
      text: entidadBancariaOtro ?? '',
    );

    const bancos = ['nequi', 'bancolombia', 'davivienda', 'otro'];

    if (entidadBancaria != null && !bancos.contains(entidadBancaria)) {
      entidadBancaria = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cambiar forma de pago'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      itemHeight: 50,
                      initialValue: formaPagoSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Forma de pago',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'entrega',
                          child: Text('Pago por entrega'),
                        ),
                        DropdownMenuItem(
                          value: 'bancario',
                          child: Text('Pago bancario'),
                        ),
                        DropdownMenuItem(
                          value: 'cuotas',
                          child: Text('Cuotas'),
                        ),
                        DropdownMenuItem(
                          value: 'fianza',
                          child: Text('Fianza / Fiado'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          formaPagoSeleccionada = value;
                          if (value == 'bancario') {
                            entidadBancaria ??= 'nequi';
                          } else {
                            entidadBancaria = null;
                            entidadBancariaOtro = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 9),
                    if (formaPagoSeleccionada == 'entrega')
                      const Text(
                        'Método de pago: Efectivo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (formaPagoSeleccionada == 'bancario') ...[
                      DropdownButtonFormField<String>(
                        initialValue: entidadBancaria,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Entidad bancaria',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'nequi',
                            child: Text('Nequi'),
                          ),
                          DropdownMenuItem(
                            value: 'bancolombia',
                            child: Text('Bancolombia'),
                          ),
                          DropdownMenuItem(
                            value: 'davivienda',
                            child: Text('Davivienda'),
                          ),
                          DropdownMenuItem(value: 'otro', child: Text('Otro')),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            entidadBancaria = value;
                          });
                        },
                      ),
                      if (entidadBancaria == 'otro')
                        TextFormField(
                          controller: otroController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de entidad',
                          ),
                          onChanged: (value) {
                            entidadBancariaOtro = value;
                          },
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                otroController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Si pasa a cuotas o fianza → pantalla aparte
                if (formaPagoSeleccionada == 'cuotas' ||
                    formaPagoSeleccionada == 'fianza') {
                  Navigator.pop(context);

                  final config = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConfigPago(
                        tipoPago: formaPagoSeleccionada!,
                        totalPedido: pedido['valor_total'].toDouble(),
                      ),
                    ),
                  );

                  if (config == null) return;

                  // Crear deuda
                  final deudaRef = FirebaseFirestore.instance
                      .collection('deudas')
                      .doc();

                  final pagado = (config['pagado'] ?? 0).toDouble();
                  final total = pedido['valor_total'].toDouble();

                  await deudaRef.set({
                    'pedido_id': pedido.id,
                    'numero_pedido': pedido['numero_pedido'],
                    'cliente': {
                      'nombre': pedido['cliente'],
                      'tipo': pedido['tipo'],
                    },
                    'tipo': formaPagoSeleccionada,
                    'total': total,
                    'pagado': pagado,
                    'saldo': total - pagado,
                    'estado': pagado >= total ? 'pagado' : 'activo',
                    'historial': pagado > 0
                        ? [
                            {
                              'fecha': Timestamp.now(),
                              'monto': pagado,
                              'tipo': formaPagoSeleccionada == 'cuotas'
                                  ? 'cuota'
                                  : 'aporte',
                            },
                          ]
                        : [],
                    'config': config,
                    'creado_en': Timestamp.now(),
                    'actualizado_en': Timestamp.now(),
                  });

                  // Actualizar pedido
                  await FirebaseFirestore.instance
                      .collection('pedidos')
                      .doc(pedido.id)
                      .update({
                        'forma_pago': formaPagoSeleccionada,
                        'pago': {
                          'tipo': formaPagoSeleccionada,
                          'referencia_pago': deudaRef.id,
                          'resumen': {
                            'total': total,
                            'pagado': pagado,
                            'saldo': total - pagado,
                          },
                        },
                      });

                  final nuevoPago = {
                    'tipo': formaPagoSeleccionada,
                    'referencia_pago': deudaRef.id,
                    'resumen': {
                      'total': total,
                      'pagado': pagado,
                      'saldo': total - pagado,
                    },
                    'extra': null,
                  };

                  pagoNotifier.value = nuevoPago;

                  if (context.mounted) {
                    otroController.dispose();
                    Navigator.pop(context);
                  }
                  return;
                }

                // =====================
                // ENTREGA / BANCARIO
                // =====================
                Map<String, dynamic>? extraPago;

                if (formaPagoSeleccionada == 'entrega') {
                  extraPago = {'metodo': 'efectivo'};
                }

                if (formaPagoSeleccionada == 'bancario') {
                  if (entidadBancaria == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Seleccione una entidad bancaria'),
                      ),
                    );
                    return;
                  }

                  if (entidadBancaria == 'otro' &&
                      (entidadBancariaOtro == null ||
                          entidadBancariaOtro!.isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ingrese el nombre del banco'),
                      ),
                    );
                    return;
                  }
                  extraPago = {
                    'entidad': entidadBancaria == 'otro'
                        ? 'otro'
                        : entidadBancaria,
                    'otro': entidadBancaria == 'otro'
                        ? entidadBancariaOtro
                        : null,
                  };
                }

                await FirebaseFirestore.instance
                    .collection('pedidos')
                    .doc(pedido.id)
                    .update({
                      'forma_pago': formaPagoSeleccionada,
                      'pago': {
                        'tipo': formaPagoSeleccionada,
                        'referencia_pago': null,
                        'resumen': null,
                        'extra': extraPago,
                      },
                    });

                final nuevoPago = {
                  'tipo': formaPagoSeleccionada,
                  'extra': extraPago,
                  'referencia_pago': null,
                  'resumen': null,
                };

                pagoNotifier.value = nuevoPago;

                if (context.mounted) {
                  otroController.dispose();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Forma de pago actualizada')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarInfoEdicion(BuildContext context, Map<String, dynamic> data) {
    final creador = data['creado_por_nombre'] ?? 'Desconocido';
    final editor = data['editado_por_nombre'];
    final editadoEn = data['editado_en'];

    String fechaEdicion = 'Sin fecha';

    if (editadoEn is Timestamp) {
      final date = editadoEn.toDate();
      fechaEdicion =
          '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Información del pedido',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_document),
                  SizedBox(width: 5),
                  Text('Creado por: $creador'),
                ],
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    editor != null
                        ? Icons.draw_outlined
                        : Icons.edit_off_outlined,
                  ),
                  Text(editor != null ? 'Editado por: $editor' : 'Sin edición'),
                ],
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today),
                  Text('Última edición: $fechaEdicion'),
                ],
              ),

              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }
}

extension on Object? Function() {
  void operator []=(String index, bool newValue) {}
}

class _HalfCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Oculta la mitad superior: solo deja visible la inferior
    path.addRect(
      Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
    );

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
