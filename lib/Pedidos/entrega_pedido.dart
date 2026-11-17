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

  Future<void> _cambiarEstado(bool entregadoActual) async {
    if (_actualizando) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _actualizando = true);

    final nuevoEstado = !entregadoActual;

    try {
      await widget.pedido.reference.update({'entregado': nuevoEstado});

      widget.onEstadoCambiado?.call(nuevoEstado);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actualizando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      top: 5,
      right: 5,
      child: StreamBuilder<DocumentSnapshot>(
        stream: widget.pedido.reference.snapshots(),
        initialData: widget.pedido,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;

          final entregadoActual = data?['entregado'] == true;

          return GestureDetector(
            onTap: _actualizando || !snapshot.hasData
                ? null
                : () => _cambiarEstado(entregadoActual),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                ),
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
                      entregadoActual ? Icons.check_circle : Icons.access_time,
                      key: ValueKey(entregadoActual),
                      color: PaletasDeColores.getColorIconoEntrega(
                        entregado: entregadoActual,
                        theme: theme,
                      ),
                      // color: _entregadoActual
                      //     ? theme.primaryColor
                      //     : theme.colorScheme.secondary,
                      size: 40,
                    ),
            ),
          );
        },
      ),
    );
  }
}
