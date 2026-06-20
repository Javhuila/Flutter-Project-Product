import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Pedidos/info_pedido.dart';

class SearchProductoPedidos extends StatefulWidget {
  const SearchProductoPedidos({super.key});

  @override
  State<SearchProductoPedidos> createState() => _SearchProductoPedidosState();
}

class _SearchProductoPedidosState extends State<SearchProductoPedidos> {
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _filtroFecha;

  List<DocumentSnapshot> _resultados = [];
  List<DocumentSnapshot> _pedidosCache = [];
  int _paginaActual = 0;
  int itemsPorPagina = 15;

  bool loading = false;
  bool _cargando = true;
  String? userRole;
  bool _isLoadingRole = true;

  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _cargarPedidosHoy();
    _loadUserRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
          userRole = doc['role'];
          _isLoadingRole = false;
        });
      } else {
        setState(() {
          userRole = 'asistente'; // fallback
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      setState(() {
        userRole = 'asistente'; // fallback en caso de error
        _isLoadingRole = false;
      });
    }
  }

  Future<void> _cargarPedidosHoy() async {
    setState(() => _cargando = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String adminId = user.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    final hoy = DateTime.now();

    final inicio = DateTime(hoy.year, hoy.month, hoy.day);

    final fin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);

    final snapshot = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('adminId', isEqualTo: adminId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(fin))
        .orderBy('fecha', descending: true)
        .get();

    setState(() {
      _pedidosCache = snapshot.docs;
      _resultados = [];
      _cargando = false;
    });
  }

  Future<void> _cargarPedidosPorFecha(DateTimeRange rango) async {
    setState(() => _cargando = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String adminId = user.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    final inicio = DateTime(
      rango.start.year,
      rango.start.month,
      rango.start.day,
    );

    final fin = DateTime(
      rango.end.year,
      rango.end.month,
      rango.end.day,
      23,
      59,
      59,
    );

    final snapshot = await FirebaseFirestore.instance
        .collection('pedidos')
        .where('adminId', isEqualTo: adminId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(fin))
        .orderBy('fecha', descending: true)
        .get();

    setState(() {
      _pedidosCache = snapshot.docs;
      _resultados = [];
      _paginaActual = 0;
      _cargando = false;
    });
  }

  Future<void> _buscarProducto() async {
    _searchFocusNode.unfocus();
    final texto = _searchController.text.trim().toLowerCase();
    if (texto.isEmpty) return;

    setState(() {
      loading = true;
    });

    final resultados = _pedidosCache.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final nombres = List<String>.from(data['productos_nombres'] ?? []);

      return nombres.any((nombre) => nombre.toLowerCase().contains(texto));
    }).toList();

    setState(() {
      _resultados = resultados;
      _paginaActual = 0;
      loading = false;
    });
  }

  List<Map<String, dynamic>> obtenerProducto(
    Map<String, dynamic> pedido,
    String nombreProducto,
  ) {
    final productos = List<Map<String, dynamic>>.from(
      pedido['productos'] ?? [],
    );

    return productos.where((p) {
      return p['nombre'].toString().toLowerCase().contains(
        nombreProducto.toLowerCase(),
      );
    }).toList();
  }

  List<DocumentSnapshot> _paginar(List<DocumentSnapshot> lista) {
    final inicio = _paginaActual * itemsPorPagina;
    final fin = inicio + itemsPorPagina;

    if (inicio >= lista.length) return [];

    return lista.sublist(inicio, fin > lista.length ? lista.length : fin);
  }

  @override
  Widget build(BuildContext context) {
    final resultadosPaginados = _paginar(_resultados);

    if (_cargando || _isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buscar productos'),
          actions: [
            IconButton(
              icon: const Icon(Icons.date_range),
              tooltip: _filtroFecha == null
                  ? "Seleccionar rango"
                  : "${_filtroFecha!.start.toString().split(' ')[0]}"
                        " - "
                        "${_filtroFecha!.end.toString().split(' ')[0]}",
              onPressed: () async {
                final rango = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2100),
                );

                if (rango != null) {
                  setState(() {
                    _filtroFecha = rango;
                  });

                  await _cargarPedidosPorFecha(rango);
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: TextFormField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  labelText: 'Producto',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _buscarProducto,
                  ),
                ),
              ),
            ),
            // if (_loading) const CircularProgressIndicator(),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _resultados.isEmpty
                        ? const Center(
                            child: Text('No se encontraron productos'),
                          )
                        : ListView.builder(
                            itemCount: resultadosPaginados.length,
                            itemBuilder: (context, index) {
                              final pedido = resultadosPaginados[index];
                              final data =
                                  pedido.data() as Map<String, dynamic>;
                              final producto = obtenerProducto(
                                data,
                                _searchController.text,
                              );

                              return Card(
                                margin: const EdgeInsets.all(8),
                                child: ListTile(
                                  title: Text(data['cliente']),

                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ...producto.map((producto) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Producto: ${producto['nombre']}",
                                              ),

                                              Text(
                                                "Cantidad: ${producto['cantidad']}",
                                              ),

                                              Text(
                                                "Valor unidad: \$${producto['precio']}",
                                              ),

                                              Text(
                                                "Total: \$${producto['total']}",
                                              ),

                                              const Divider(),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),

                                  trailing: const Icon(Icons.arrow_forward),

                                  onTap: () {
                                    _searchFocusNode.unfocus();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            InfoPedido(pedido: pedido),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _paginaActual > 0
                              ? () => setState(() => _paginaActual--)
                              : null,
                        ),

                        Text("Página ${_paginaActual + 1}"),

                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed:
                              (_paginaActual + 1) * itemsPorPagina <
                                  _resultados.length
                              ? () => setState(() => _paginaActual++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
