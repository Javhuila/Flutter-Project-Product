import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Pedidos/Pagos/gestion_cuotas.dart';
import 'package:flutter_project_product/Pedidos/Pagos/gestion_fianza.dart';

class HistorialPagos extends StatefulWidget {
  const HistorialPagos({super.key});

  @override
  State<HistorialPagos> createState() => _HistorialPagosState();
}

class _HistorialPagosState extends State<HistorialPagos>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _userRole;
  bool _isLoadingRole = true;

  String _fechaDeuda = '';

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _limpiarDeudasVencidas(); // auto limpieza

    _loadUserRole();
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

  // ========================
  // LIMPIEZA AUTOMÁTICA
  // ========================
  Future<void> _limpiarDeudasVencidas() async {
    final limite = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 4)),
    );

    final query = await FirebaseFirestore.instance
        .collection('deudas')
        .where('estado', isEqualTo: 'pagado')
        .where('actualizado_en', isLessThanOrEqualTo: limite)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (var doc in query.docs) {
      batch.delete(doc.reference);
    }

    if (query.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // ========================
  // BORRADO MANUAL
  // ========================
  Future<void> _eliminarPagadas() async {
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar deudas pagadas'),
        content: const Text('¿Deseas eliminar todas las deudas completadas?'),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => navigator.pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final query = await FirebaseFirestore.instance
        .collection('deudas')
        .where('estado', isEqualTo: 'pagado')
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (var doc in query.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ========================
  // STREAMS
  // ========================
  Stream<QuerySnapshot> _streamActivas() {
    return FirebaseFirestore.instance
        .collection('deudas')
        .where('estado', isEqualTo: 'activo')
        .orderBy('actualizado_en', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _streamPagadas() {
    return FirebaseFirestore.instance
        .collection('deudas')
        .where('estado', isEqualTo: 'pagado')
        .orderBy('actualizado_en', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      // Mostramos un loader mientras se carga el rol del usuario
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de pagos'),
        actions: _userRole == 'admin'
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'Eliminar pagadas',
                  onPressed: _eliminarPagadas,
                ),
              ]
            : [],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Activas'),
            Tab(text: 'Pagadas'),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLista(_streamActivas()),
          _buildLista(_streamPagadas()),
        ],
      ),
    );
  }

  Widget _buildLista(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Sin registros'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (_, i) {
            final doc = snapshot.data!.docs[i];
            final data = doc.data() as Map<String, dynamic>;

            return _buildItem(doc.id, {...data, 'id': doc.id});
          },
        );
      },
    );
  }

  Widget _buildItem(String id, Map<String, dynamic> data) {
    final cliente = data['cliente'];

    final nombre = cliente != null
        ? cliente['nombre'] ?? 'Sin nombre'
        : 'Sin cliente';

    final numero = data['numero_pedido'] ?? '---';

    final fechaC = data['creado_en'];
    if (fechaC is Timestamp) {
      final date = fechaC.toDate();
      _fechaDeuda =
          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } else {
      _fechaDeuda = fechaC?.toString() ?? '';
    }

    return GestureDetector(
      onTap: () {
        _mostrarDetalleHistorial(context, data);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: Icon(
            data['tipo'] == 'cuotas'
                ? Icons.currency_exchange_outlined
                : Icons.savings_outlined,
          ),

          title: Text('$nombre - Pedido #$numero'),

          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total: \$${data['total']}'),
              Text('Pagado: \$${data['pagado']}'),
              Text('Saldo: \$${data['saldo']}'),
              SizedBox(height: 8),
              Text("Fecha: $_fechaDeuda"),
            ],
          ),

          trailing: _userRole == 'admin'
              ? PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: Text('Editar forma de pago'),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Text('Eliminar'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'editar') {
                      _editarDeuda(id, data);
                    }

                    if (value == 'eliminar') {
                      _eliminarIndividual(id);
                    }
                  },
                )
              : SizedBox(),
        ),
      ),
    );
  }

  // ========================
  // EDITAR
  // ========================
  void _editarDeuda(String deudaId, Map<String, dynamic> data) async {
    final tipo = data['tipo'];
    final pedidoId = data['pedido_id'];

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (pedidoId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Esta deuda no está vinculada a un pedido'),
        ),
      );
      return;
    }

    // Traemos el pedido actualizado
    final pedidoDoc = await FirebaseFirestore.instance
        .collection('pedidos')
        .doc(pedidoId)
        .get();

    if (!pedidoDoc.exists) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pedido no encontrado')),
      );
      return;
    }

    final pedidoData = pedidoDoc.data()!;
    final pago = Map<String, dynamic>.from(pedidoData['pago'] ?? {});

    // Seguridad
    if (pago.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('El pedido no tiene datos de pago')),
      );
      return;
    }

    final referencia = pago['referencia_pago'];

    if (referencia == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Este pedido no tiene deuda asociada')),
      );
      return;
    }

    // Abrir gestor según tipo
    if (tipo == 'cuotas') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              GestionCuotas(pedidoId: pedidoId, deudaId: referencia),
        ),
      );
    }

    if (tipo == 'fianza') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              GestionFianza(pedidoId: pedidoId, deudaId: referencia),
        ),
      );
    }
  }

  // ========================
  // BORRAR 1
  // ========================
  Future<void> _eliminarIndividual(String id) async {
    await FirebaseFirestore.instance.collection('deudas').doc(id).delete();
  }

  void _mostrarDetalleHistorial(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final List historial = List<Map<String, dynamic>>.from(
      data['historial'] ?? [],
    );

    final tipo = data['tipo'];

    final double total = (data['total'] ?? 0).toDouble();
    final double pagado = (data['pagado'] ?? 0).toDouble();
    final double saldo = (data['saldo'] ?? 0).toDouble();

    final int cuotasTotal = data['cuotas_total'] ?? 0;
    final int cuotasPagadas = data['cuotas_pagadas'] ?? 0;

    // Ordenar por fecha (más nuevo primero)
    historial.sort((a, b) {
      final fa = (a['fecha'] as Timestamp).toDate();
      final fb = (b['fecha'] as Timestamp).toDate();
      return fb.compareTo(fa);
    });

    showModalBottomSheet(
      barrierLabel: "Aportes/Abonos realizados",
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                'Historial de pagos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Detalle de pagos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildResumen(
                tipo: tipo,
                total: total,
                pagado: pagado,
                saldo: saldo,
                cuotasTotal: cuotasTotal,
                cuotasPagadas: cuotasPagadas,
              ),

              const Divider(height: 30),
              if (historial.isEmpty)
                const Center(child: Text('No hay registros')),

              if (historial.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: historial.length,

                    itemBuilder: (_, i) {
                      final item = Map<String, dynamic>.from(historial[i]);

                      final tipo = item['tipo'];
                      final monto = item['monto'];
                      final fecha = (item['fecha'] as Timestamp).toDate();

                      // ---------- CUOTAS ----------
                      if (tipo == 'cuota') {
                        final numero = item['numero'];

                        return ListTile(
                          leading: const Icon(Icons.payments),

                          title: Text('Cuota #$numero'),

                          subtitle: Text(_formatearFecha(fecha)),

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${monto.toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_userRole == 'admin')
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),

                                  onPressed: () {
                                    _editarRegistroHistorial(
                                      context: context,
                                      data: data,
                                      historial: historial,
                                      index: i,
                                      tipo: 'cuota',
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      }

                      // ---------- FIANZA ----------
                      return ListTile(
                        leading: const Icon(Icons.attach_money),

                        title: const Text('Aporte'),

                        subtitle: Text(_formatearFecha(fecha)),

                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${monto.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_userRole == 'admin')
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),

                                onPressed: () {
                                  _editarRegistroHistorial(
                                    context: context,
                                    data: data,
                                    historial: historial,
                                    index: i,
                                    tipo: 'aporte',
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  Widget _buildResumen({
    required String tipo,
    required double total,
    required double pagado,
    required double saldo,
    required int cuotasTotal,
    required int cuotasPagadas,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total: \$${total.toInt()}'),
        Text('Pagado: \$${pagado.toInt()}'),
        Text('Saldo: \$${saldo.toInt()}'),

        if (tipo == 'cuotas') ...[
          const SizedBox(height: 6),
          Text('Cuotas: $cuotasPagadas / $cuotasTotal'),
        ],
      ],
    );
  }

  void _editarRegistroHistorial({
    required BuildContext context,
    required Map<String, dynamic> data,
    required List historial,
    required int index,
    required String tipo,
  }) {
    final TextEditingController controller = TextEditingController();

    final actual = historial[index];

    final navigator = Navigator.of(context);

    // Valor actual
    controller.text = actual['monto'].toString();

    showDialog(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: Text(tipo == 'cuota' ? 'Editar cuota' : 'Editar aporte'),

          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,

            decoration: const InputDecoration(labelText: 'Nuevo valor'),
          ),

          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('Cancelar'),
            ),

            ElevatedButton(
              child: const Text('Guardar'),

              onPressed: () async {
                final nuevoValor = double.tryParse(controller.text);

                if (nuevoValor == null || nuevoValor <= 0) {
                  return;
                }

                await _guardarEdicionHistorial(
                  context,
                  data,
                  historial,
                  index,
                  nuevoValor,
                );

                navigator.pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _guardarEdicionHistorial(
    BuildContext context,
    Map<String, dynamic> data,
    List historial,
    int index,
    double nuevoMonto,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final docId = data['id'];

    if (docId == null || docId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error: ID inválido')),
      );
      return;
    }

    final ref = FirebaseFirestore.instance.collection('deudas').doc(docId);

    // Actualizar registro
    historial[index]['monto'] = nuevoMonto;
    historial[index]['fecha'] = Timestamp.now();

    // Recalcular pagado
    final nuevoPagado = historial.fold<double>(
      0.0,
      (sumPago, item) => sumPago + (item['monto'] ?? 0).toDouble(),
    );

    final total = (data['total'] ?? 0).toDouble();
    final double nuevoSaldo = (total - nuevoPagado) < 0
        ? 0.0
        : (total - nuevoPagado);

    // Guardar
    await ref.update({
      'historial': historial,
      'pagado': nuevoPagado,
      'saldo': nuevoSaldo,
      'actualizado_en': Timestamp.now(),
    });

    messenger.showSnackBar(
      const SnackBar(content: Text('Registro actualizado')),
    );
  }
}
