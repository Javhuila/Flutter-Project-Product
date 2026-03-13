import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GestionCuotas extends StatefulWidget {
  final String pedidoId;
  final String deudaId;

  const GestionCuotas({
    super.key,
    required this.pedidoId,
    required this.deudaId,
  });

  @override
  State<GestionCuotas> createState() => _GestionCuotasState();
}

class _GestionCuotasState extends State<GestionCuotas> {
  double total = 0;
  double pagado = 0;
  double saldo = 0;

  int cuotasTotal = 0;
  int cuotasPagadas = 0;
  double valorCuota = 0;

  List<Map<String, dynamic>> historial = [];

  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDeuda();
  }

  Future<void> _cargarDeuda() async {
    final doc = await FirebaseFirestore.instance
        .collection('deudas')
        .doc(widget.deudaId)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    final config = data['config'] ?? {};

    final historialDb = List<Map<String, dynamic>>.from(
      data['historial'] ?? [],
    );

    setState(() {
      total = (data['total'] ?? 0).toDouble();
      pagado = (data['pagado'] ?? 0).toDouble();
      saldo = (data['saldo'] ?? 0).toDouble();

      if (saldo > 0 && cuotasTotal > 0) {
        valorCuota = saldo / (cuotasTotal - cuotasPagadas);
      }

      cuotasTotal = config['cuotas'] ?? 0;
      valorCuota = (config['valor_cuota'] ?? 0).toDouble();

      historial = historialDb;

      cuotasPagadas = historialDb.length;

      cargando = false;
    });
  }

  bool get _puedePagarCuota => cuotasPagadas < cuotasTotal;

  Future<void> _registrarCuota() async {
    final messenger = ScaffoldMessenger.of(context);

    if (!_puedePagarCuota) return;

    final nuevaCuota = cuotasPagadas + 1;

    final nuevoPago = {
      'fecha': Timestamp.now(),
      'monto': valorCuota,
      'tipo': 'cuota',
      'numero': nuevaCuota,
    };

    final nuevoPagado = pagado + valorCuota;
    final nuevoSaldo = saldo - valorCuota;

    final deudaRef = FirebaseFirestore.instance
        .collection('deudas')
        .doc(widget.deudaId);

    final pedidoRef = FirebaseFirestore.instance
        .collection('pedidos')
        .doc(widget.pedidoId);

    final batch = FirebaseFirestore.instance.batch();

    // Deuda
    batch.update(deudaRef, {
      'pagado': nuevoPagado,
      'saldo': nuevoSaldo,
      'estado': nuevoSaldo <= 0 ? 'pagado' : 'activo',
      'historial': FieldValue.arrayUnion([nuevoPago]),
      'actualizado_en': Timestamp.now(),
    });

    // Pedido (resumen)
    batch.update(pedidoRef, {
      'pago.resumen.pagado': nuevoPagado,
      'pago.resumen.saldo': nuevoSaldo,
    });

    await batch.commit();

    if (!mounted) return;

    setState(() {
      pagado = nuevoPagado;
      saldo = nuevoSaldo;
      cuotasPagadas++;
      historial.add(nuevoPago);
    });

    await _cargarDeuda();

    messenger.showSnackBar(const SnackBar(content: Text('Cuota registrada')));
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ultima = historial.isNotEmpty ? historial.last : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de cuotas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: \$${total.toInt()}'),
            Text('Pagado: \$${pagado.toInt()}'),
            Text('Saldo: \$${saldo.toInt()}'),
            const SizedBox(height: 10),

            Text('Cuotas: $cuotasPagadas / $cuotasTotal'),
            Text('Valor cuota: \$${valorCuota.toInt()}'),

            const Divider(height: 30),

            if (ultima != null) ...[
              const Text(
                'Última cuota',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('\$${ultima['monto']} - ${ultima['fecha'].toDate()}'),
            ],

            const SizedBox(height: 60),

            ElevatedButton(
              onPressed: _puedePagarCuota ? _registrarCuota : null,
              child: Text(
                _puedePagarCuota
                    ? 'Registrar cuota ${cuotasPagadas + 1}'
                    : 'Cuotas completas',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
