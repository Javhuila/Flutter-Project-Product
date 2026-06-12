import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Compras/add_compra.dart';
import 'package:flutter_project_product/Compras/info_compra.dart';
import 'package:flutter_project_product/Layout/ini_layout.dart';

class CompraVenta extends StatefulWidget {
  const CompraVenta({super.key});

  @override
  State<CompraVenta> createState() => _CompraVentaState();
}

class _CompraVentaState extends State<CompraVenta> {
  String? _userRole;
  bool _cargando = true;
  List<QueryDocumentSnapshot> _comprasCache = [];
  String? filtroConcurrencia;
  String? filtroDestinatario;
  DateTime? fechaInicio;
  DateTime? fechaFin;

  int _paginaActual = 0;
  int itemsPorPagina = 5;

  String? _filtroConcurrencia;
  String? _filtroDestinatario;
  DateTimeRange? _filtroFecha;

  @override
  void initState() {
    super.initState();
    _inicializarCompra();
  }

  Future<void> _inicializarCompra() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    await _loadUserRole();
    if (!mounted) return;
    setState(() => _cargando = false);
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
          _cargando = false;
        });
      } else {
        setState(() {
          _userRole = 'asistente'; // fallback
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        _userRole = 'asistente'; // fallback en caso de error
        _cargando = false;
      });
    }
  }

  void _confirmarEliminar(BuildContext context, DocumentReference ref) {
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Eliminar compra"),
        content: const Text("¿Estás seguro que quieres eliminar esta compra?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.delete();

                if (!mounted) return;

                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text("Compra eliminada"),
                      duration: Duration(seconds: 2),
                    ),
                  );
              } catch (e) {
                if (!mounted) return;

                messenger.showSnackBar(
                  SnackBar(content: Text("Error al eliminar: $e")),
                );
              }
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  IconData getIcon(String tipo) {
    switch (tipo) {
      case 'diario':
        return Icons.free_cancellation_outlined;
      case 'semanal':
        return Icons.today;
      case 'mensual':
        return Icons.calendar_month;
      case 'anual':
        return Icons.event;
      default:
        return Icons.perm_contact_calendar_outlined;
    }
  }

  Map<String, dynamic> _calcularResumen(List<QueryDocumentSnapshot> compras) {
    double totalGeneral = 0;
    double gananciaGeneral = 0;

    final Map<String, double> totalesPorTipo = {
      'diario': 0,
      'semanal': 0,
      'mensual': 0,
      'anual': 0,
    };

    final Map<String, int> cantidadPorTipo = {
      'diario': 0,
      'semanal': 0,
      'mensual': 0,
      'anual': 0,
    };

    final Map<String, double> gananciasPorTipo = {
      'diario': 0,
      'semanal': 0,
      'mensual': 0,
      'anual': 0,
    };

    for (var doc in compras) {
      final data = doc.data() as Map<String, dynamic>;

      final tipo = data['concurrencia'] ?? 'diario';
      final total = (data['total_compra'] ?? 0).toDouble();

      totalGeneral += total;

      if (totalesPorTipo.containsKey(tipo)) {
        totalesPorTipo[tipo] = totalesPorTipo[tipo]! + total;
        cantidadPorTipo[tipo] = cantidadPorTipo[tipo]! + 1;
      }

      double gananciaCompra = 0;

      final productos = data['productos'] ?? [];

      for (var p in productos) {
        final tipoCompra = p['tipo_compra'] ?? 'normal';

        if (tipoCompra == 'flete') {
          final compra = (p['precio_compra'] ?? 0).toDouble();
          final venta = (p['precio_por_defecto'] ?? 0).toDouble();

          int cantidadTotal = 0;

          (p['cantidades'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
            cantidadTotal += (v as int);
          });

          gananciaCompra += (compra - venta) * cantidadTotal;
        }
      }
      gananciaGeneral += gananciaCompra;

      if (gananciasPorTipo.containsKey(tipo)) {
        gananciasPorTipo[tipo] = gananciasPorTipo[tipo]! + gananciaCompra;
      }
    }

    return {
      'totalGeneral': totalGeneral,
      'totalesPorTipo': totalesPorTipo,
      'cantidadPorTipo': cantidadPorTipo,
      'gananciasPorTipo': gananciasPorTipo,
      'gananciaGeneral': gananciaGeneral,
    };
  }

  void _mostrarResumen(List<QueryDocumentSnapshot> compras) {
    final resumen = _calcularResumen(compras);

    final totales = resumen['totalesPorTipo'] as Map<String, double>;
    final cantidades = resumen['cantidadPorTipo'] as Map<String, int>;
    final totalGeneral = resumen['totalGeneral'];
    final ganancias = resumen['gananciasPorTipo'] as Map<String, double>;
    final gananciaGeneral = resumen['gananciaGeneral'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Resumen de Compras"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...totales.keys.map((tipo) {
                  return ListTile(
                    title: Text(tipo.toUpperCase()),
                    subtitle: Column(
                      children: [
                        Text("Cantidad: ${cantidades[tipo]}"),
                        Text(
                          "Ganancia: \$${ganancias[tipo]!.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: ganancias[tipo]! >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text("\$${totales[tipo]!.toStringAsFixed(0)}"),
                  );
                }),
                const Divider(),
                ListTile(
                  title: const Text("TOTAL GENERAL"),
                  subtitle: Text(
                    "Ganancia total: \$${gananciaGeneral.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: gananciaGeneral >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: Text(
                    "\$${totalGeneral.toStringAsFixed(0)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _aplicarFiltros(
    List<QueryDocumentSnapshot> compras,
  ) {
    return compras.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      if (_filtroConcurrencia != null &&
          data['concurrencia'] != _filtroConcurrencia) {
        return false;
      }

      if (_filtroDestinatario != null &&
          _filtroDestinatario!.isNotEmpty &&
          !(data['destinatario'] ?? '').toString().toLowerCase().contains(
            _filtroDestinatario!.toLowerCase(),
          )) {
        return false;
      }

      if (_filtroFecha != null) {
        final fecha = (data['fecha'] as Timestamp?)?.toDate();
        if (fecha == null) return false;

        if (fecha.isBefore(_filtroFecha!.start) ||
            fecha.isAfter(_filtroFecha!.end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<QueryDocumentSnapshot> _paginar(List<QueryDocumentSnapshot> lista) {
    final inicio = _paginaActual * itemsPorPagina;
    final fin = inicio + itemsPorPagina;

    if (inicio >= lista.length) return [];

    return lista.sublist(inicio, fin > lista.length ? lista.length : fin);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final comprasStream = FirebaseFirestore.instance
        .collection('compras')
        .orderBy('fecha', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text("Compras"),
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
        actions: _userRole == 'admin'
            ? [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddCompra(),
                      ),
                    );
                  },
                  icon: Icon(Icons.add_shopping_cart),
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
              ]
            : [],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const DrawerHeader(
                margin: EdgeInsets.only(bottom: 2.0),
                padding: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 6.0),
                child: Text("Opciones"),
              ),

              // RESUMEN
              ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text("Ver resumen"),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarResumen(_comprasCache);
                },
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    spacing: 14,
                    children: [
                      const Text(
                        "Filtros",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButtonFormField<String>(
                        hint: const Text("Concurrencia"),
                        initialValue: _filtroConcurrencia,
                        items: ['diario', 'semanal', 'mensual', 'anual']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _filtroConcurrencia = value;
                            _paginaActual = 0;
                          });
                          Navigator.pop(context);
                        },
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: "Destinatario",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _filtroDestinatario = value;
                            _paginaActual = 0;
                          });
                          Navigator.pop(context);
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _filtroFecha == null
                              ? "Seleccionar fecha"
                              : "${_filtroFecha!.start.toString().split(' ')[0]} - ${_filtroFecha!.end.toString().split(' ')[0]}",
                        ),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final rango = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (rango != null) {
                            setState(() {
                              _filtroFecha = rango;
                              _paginaActual = 0;
                            });
                            navigator.pop();
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.clear),
                        label: const Text("Limpiar filtros"),
                        onPressed: () {
                          setState(() {
                            _filtroConcurrencia = null;
                            _filtroDestinatario = null;
                            _filtroFecha = null;
                            _paginaActual = 0;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder(
        stream: comprasStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No hay compras registradas"));
          }

          final compras = snapshot.data!.docs;
          _comprasCache = compras;
          final comprasFiltradas = _aplicarFiltros(compras);
          final comprasPaginadas = _paginar(comprasFiltradas);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: comprasPaginadas.length,
                  itemBuilder: (context, index) {
                    final data =
                        comprasPaginadas[index].data() as Map<String, dynamic>;

                    final fecha = data['fecha'] as Timestamp?;
                    final fechaText = fecha != null
                        ? fecha.toDate().toString().split(' ')[0]
                        : 'Sin fecha';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(
                                  getIcon(data['concurrencia'] ?? ''),
                                ),
                              ),

                              title: Text(
                                "${data['total_productos']} productos",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Proveedor: ${data['proveedor'] ?? 'N/A'}",
                                  ),
                                  Text(
                                    "Destinatario: ${data['destinatario'] ?? 'N/A'}",
                                  ),
                                ],
                              ),

                              // trailing:
                              onTap: () {
                                if (_userRole == "admin") {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InfoCompra(
                                        compra: comprasPaginadas[index],
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 10, top: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "\$${data['total_compra'] ?? 0}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  fechaText,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                _userRole == "admin"
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.delete_sweep_outlined,
                                        ),
                                        tooltip: "Eliminar compra",
                                        onPressed: () => _confirmarEliminar(
                                          context,
                                          comprasPaginadas[index].reference,
                                        ),
                                      )
                                    : Container(),
                              ],
                            ),
                          ),
                        ],
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
                              comprasFiltradas.length
                          ? () => setState(() => _paginaActual++)
                          : null,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
