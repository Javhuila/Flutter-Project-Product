import 'package:flutter/material.dart';

class ConfigPago extends StatefulWidget {
  final String tipoPago; // 'cuotas' | 'fianza'
  final double totalPedido;

  const ConfigPago({
    super.key,
    required this.tipoPago,
    required this.totalPedido,
  });

  @override
  State<ConfigPago> createState() => _ConfigPagoState();
}

class _ConfigPagoState extends State<ConfigPago> {
  // ------------------------
  // VARIABLES
  // ------------------------

  int _cantidadCuotas = 0;
  double _valorCuota = 0;

  double _aporteInicial = 0;

  final _formKey = GlobalKey<FormState>();

  // ------------------------
  // BUILD
  // ------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.tipoPago == 'cuotas'
              ? 'Configurar Cuotas'
              : 'Configurar Fianza / Crédito',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------
              // TOTAL
              // ------------------------
              Text(
                'Total del pedido: \$${widget.totalPedido.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------
              // CUOTAS
              // ------------------------
              if (widget.tipoPago == 'cuotas') ...[
                TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de cuotas',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final cuotas = int.tryParse(value ?? '');
                    if (cuotas == null || cuotas <= 0) {
                      return 'Ingrese un número válido de cuotas';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    final cuotas = int.tryParse(value) ?? 0;

                    setState(() {
                      _cantidadCuotas = cuotas;
                      _valorCuota = cuotas > 0
                          ? widget.totalPedido / cuotas
                          : 0;
                    });
                  },
                ),

                const SizedBox(height: 12),

                if (_cantidadCuotas > 0)
                  Text(
                    'Valor por cuota: \$${_valorCuota.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16),
                  ),
              ],

              // ------------------------
              // FIANZA / CRÉDITO
              // ------------------------
              if (widget.tipoPago == 'fianza') ...[
                TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Aporte inicial',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final aporte = double.tryParse(value ?? '');
                    if (aporte == null || aporte < 0) {
                      return 'Ingrese un monto válido';
                    }
                    if (aporte > widget.totalPedido) {
                      return 'El aporte no puede superar el total';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    final aporte = double.tryParse(value) ?? 0;

                    setState(() {
                      _aporteInicial = aporte;
                    });
                  },
                ),

                const SizedBox(height: 12),

                Text(
                  'Saldo pendiente: \$${(widget.totalPedido - _aporteInicial).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],

              // ------------------------
              // BOTONES
              // ------------------------
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmar,
                      child: const Text('Confirmar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------
  // CONFIRMAR
  // ------------------------

  void _confirmar() {
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;

    if (widget.tipoPago == 'cuotas') {
      if (_cantidadCuotas <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Debe ingresar al menos una cuota')),
        );
        return;
      }

      Navigator.pop(context, {
        'tipo': 'cuotas',
        'cuotas': _cantidadCuotas,
        'valor_cuota': _valorCuota,
        'pagado': 0.0,
      });
    }

    if (widget.tipoPago == 'fianza') {
      Navigator.pop(context, {'tipo': 'fianza', 'pagado': _aporteInicial});
    }
  }
}
