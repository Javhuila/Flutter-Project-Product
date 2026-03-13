import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GestionFianza extends StatefulWidget {
  final String pedidoId;
  final String deudaId;

  const GestionFianza({
    super.key,
    required this.pedidoId,
    required this.deudaId,
  });

  @override
  State<GestionFianza> createState() => _GestionFianzaState();
}

class _GestionFianzaState extends State<GestionFianza> {
  double total = 0;
  double pagado = 0;
  double saldo = 0;

  List<Map<String, dynamic>> historial = [];

  final TextEditingController _abonoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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

    final hist = List<Map<String, dynamic>>.from(data['historial'] ?? []);

    final double t = (data['total'] ?? 0).toDouble();
    final double p = (data['pagado'] ?? 0).toDouble();
    final double s = (data['saldo'] ?? 0).toDouble();

    setState(() {
      total = t;
      pagado = p;
      saldo = s < 0 ? 0 : s;

      historial = hist;

      cargando = false;
    });
  }

  Future<void> _registrarAbono() async {
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;

    final abono = double.parse(_abonoCtrl.text);

    if (abono <= 0 || abono > saldo) return;

    final nuevoPagado = pagado + abono;
    final double nuevoSaldo = (saldo - abono) < 0 ? 0.0 : (saldo - abono);

    final nuevoRegistro = {
      'fecha': Timestamp.now(),
      'monto': abono,
      'tipo': 'aporte',
    };

    final deudaRef = FirebaseFirestore.instance
        .collection('deudas')
        .doc(widget.deudaId);

    final pedidoRef = FirebaseFirestore.instance
        .collection('pedidos')
        .doc(widget.pedidoId);

    final batch = FirebaseFirestore.instance.batch();

    // Actualizar deuda
    batch.update(deudaRef, {
      'pagado': nuevoPagado,
      'saldo': nuevoSaldo,
      'estado': nuevoSaldo <= 0 ? 'pagado' : 'activo',
      'historial': FieldValue.arrayUnion([nuevoRegistro]),
      'actualizado_en': Timestamp.now(),
    });

    // Actualizar resumen en pedido
    batch.update(pedidoRef, {
      'pago.resumen.pagado': nuevoPagado,
      'pago.resumen.saldo': nuevoSaldo,
    });

    await batch.commit();

    if (!mounted) return;

    await _cargarDeuda();

    // setState(() {
    //   pagado = nuevoPagado;
    //   saldo = nuevoSaldo;
    //   historial.add(nuevoRegistro);
    // });

    _abonoCtrl.clear();

    messenger.showSnackBar(
      const SnackBar(content: Text('Abono registrado correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de fianza')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pagado.toInt()} de ${total.toInt()}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Falta \$${saldo.toInt()}',
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _abonoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Digite abono',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final monto = double.tryParse(value ?? '');
                  if (monto == null || monto <= 0) {
                    return 'Ingrese un valor válido';
                  }
                  if (monto > saldo) {
                    return 'El abono no puede ser mayor al saldo';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),
              Text(
                'Valor del pedido: ${total.toInt()}',
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox.square(dimension: 50),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saldo > 0 ? _registrarAbono : null,
                  child: const Text('Registrar abono'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
