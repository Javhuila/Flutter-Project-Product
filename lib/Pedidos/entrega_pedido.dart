import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Theme/catalogo_color.dart';

class EntregaPedido extends StatefulWidget {
  final DocumentSnapshot pedido;
  final void Function(bool nuevoEstado)? onEstadoCambiado;
  const EntregaPedido({super.key, required this.pedido, this.onEstadoCambiado});

  @override
  State<EntregaPedido> createState() => _EntregaPedidoState();
}

class _EntregaPedidoState extends State<EntregaPedido>
    with TickerProviderStateMixin {
  bool _actualizando = false;
  late bool _entregadoActual;

  @override
  void initState() {
    super.initState();
    final data = widget.pedido.data() as Map<String, dynamic>;
    _entregadoActual = data['entregado'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      top: 5,
      right: 5,
      child: GestureDetector(
        onTap: _actualizando
            ? null
            : () async {
                final messenger = ScaffoldMessenger.of(context);

                setState(() {
                  _actualizando = true;
                });

                try {
                  final nuevoEstado = !_entregadoActual;

                  // Actualizar en Firestore
                  await FirebaseFirestore.instance
                      .collection('pedidos')
                      .doc(widget.pedido.id)
                      .update({'entregado': nuevoEstado});

                  // Actualizar localmente para reflejar el cambio inmediato
                  setState(() {
                    _entregadoActual = nuevoEstado;
                  });

                  // Notificar al widget padre
                  if (widget.onEstadoCambiado != null) {
                    widget.onEstadoCambiado!(nuevoEstado);
                  }

                  // Espera pequeña para transición visual
                  await Future.delayed(const Duration(milliseconds: 250));
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error al actualizar: $e')),
                  );
                }

                if (mounted) {
                  setState(() {
                    _actualizando = false;
                  });
                }
              },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          ),
          child: _actualizando
              ? const SizedBox(
                  key: ValueKey('Cargando'),
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _entregadoActual ? Icons.check_circle : Icons.access_time,
                  key: ValueKey(_entregadoActual),
                  color: PaletasDeColores.getColorIconoEntrega(
                    entregado: _entregadoActual,
                    theme: theme,
                  ),
                  // color: _entregadoActual
                  //     ? theme.primaryColor
                  //     : theme.colorScheme.secondary,
                  size: 40,
                ),
        ),
      ),
    );
  }
}
