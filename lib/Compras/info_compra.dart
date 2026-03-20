import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InfoCompra extends StatefulWidget {
  final DocumentSnapshot compra;

  const InfoCompra({super.key, required this.compra});

  @override
  State<InfoCompra> createState() => _InfoCompraState();
}

class _InfoCompraState extends State<InfoCompra> {
  Future<int?> _dialogCantidad(BuildContext context, int actual) async {
    TextEditingController controller = TextEditingController(
      text: actual.toString(),
    );

    return showDialog<int>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Nueva cantidad"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, int.tryParse(controller.text));
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  // Future<void> _editarCantidad(
  //   DocumentReference ref,
  //   Map<String, dynamic> producto,
  //   List productos,
  // ) async {
  //   final nuevaCantidad = await _dialogCantidad(context, producto['cantidad']);

  //   if (nuevaCantidad == null || nuevaCantidad <= 0) return;

  //   final nuevosProductos = List<Map<String, dynamic>>.from(productos);

  //   final index = nuevosProductos.indexWhere(
  //     (p) => p['productoId'] == producto['productoId'],
  //   );

  //   if (index == -1) return;

  //   final precio = producto['precio_compra'];

  //   nuevosProductos[index]['cantidad'] = nuevaCantidad;
  //   nuevosProductos[index]['valor_total'] = nuevaCantidad * precio;

  //   // 🔥 recalcular total general
  //   double nuevoTotal = 0;
  //   for (var p in nuevosProductos) {
  //     nuevoTotal += (p['valor_total'] ?? 0);
  //   }

  //   await ref.update({
  //     "productos": nuevosProductos,
  //     "total_compra": nuevoTotal,
  //   });
  // }

  Future<void> _editarCelda(
    DocumentReference ref,
    Map<String, dynamic> producto,
    List productos,
    int indexCelda,
  ) async {
    TextEditingController controller = TextEditingController(
      text: (producto['cantidades']?[indexCelda.toString()] ?? 0).toString(),
    );

    final nuevaCantidad = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Editar cantidad"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, int.tryParse(controller.text));
            },
            child: Text("Guardar"),
          ),
        ],
      ),
    );

    if (nuevaCantidad == null || nuevaCantidad < 0) return;

    final nuevosProductos = List<Map<String, dynamic>>.from(productos);

    final index = nuevosProductos.indexWhere(
      (p) => p['productoId'] == producto['productoId'],
    );

    if (index == -1) return;

    nuevosProductos[index]['cantidades'] ??= {};
    nuevosProductos[index]['cantidades'][indexCelda.toString()] = nuevaCantidad;

    // 🔥 recalcular total del producto
    double totalProducto = 0;
    final precio = producto['precio_compra'];

    nuevosProductos[index]['cantidades'].forEach((key, value) {
      totalProducto += value * precio;
    });

    nuevosProductos[index]['valor_total'] = totalProducto;

    // 🔥 recalcular total general
    double totalCompra = 0;
    for (var p in nuevosProductos) {
      totalCompra += (p['valor_total'] ?? 0);
    }

    await ref.update({
      "productos": nuevosProductos,
      "total_compra": totalCompra,
    });
  }

  void _mostrarGanancia(Map<String, dynamic> producto) {
    final precioCompra = (producto['precio_compra'] ?? 0).toDouble();
    final precioDefault = (producto['precio_por_defecto'] ?? 0).toDouble();
    final cantidad = producto['cantidades']?['0'] ?? producto['cantidad'] ?? 0;

    final flete = precioCompra - precioDefault;
    final gananciaTotal = flete * cantidad;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ganancia"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Precio compra: \$${precioCompra.toStringAsFixed(0)}"),
            Text("Precio base: \$${precioDefault.toStringAsFixed(0)}"),
            const SizedBox(height: 10),
            Text("Flete unitario: \$${flete.toStringAsFixed(0)}"),
            Text("Cantidad: $cantidad"),
            const SizedBox(height: 10),
            Text(
              "Ganancia total: \$${gananciaTotal.toStringAsFixed(0)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            if (flete < 0)
              const Text(
                "⚠️ Esto es una pérdida",
                style: TextStyle(color: Colors.red),
              ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detalle de Compra")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: widget.compra.reference.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final productos = data['productos'] ?? [];

          final fecha = data['fecha'];
          final fechaText = fecha != null
              ? (fecha as Timestamp).toDate().toString().split(' ')[0]
              : 'Sin fecha';

          double gananciaTotalCompra = 0;

          for (var p in productos) {
            final compra = (p['precio_compra'] ?? 0).toDouble();
            final base = (p['precio_por_defecto'] ?? 0).toDouble();
            final cantidad = p['cantidades']?['0'] ?? p['cantidad'] ?? 0;

            gananciaTotalCompra += (compra - base) * cantidad;
          }

          final concurrencia = data['concurrencia'] ?? 'diario';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 🧾 INFO GENERAL
                Card(
                  child: ListTile(
                    title: Text("Proveedor: ${data['proveedor'] ?? ''}"),
                    subtitle: Text("Fecha: $fechaText"),
                    trailing: Text(
                      "\$${data['total_compra'] ?? 0}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Text(
                  "Ganancia total: \$${gananciaTotalCompra.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: gananciaTotalCompra >= 0 ? Colors.green : Colors.red,
                  ),
                ),

                const SizedBox(height: 10),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Productos",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),

                // 📦 LISTA
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final ref = snapshot.data!.reference;

                      switch (concurrencia) {
                        case "diario":
                          return _vistaDiaria(productos, ref);

                        case "semanal":
                          return _vistaSemanal(productos, ref);

                        case "mensual":
                          return _vistaMensual(productos, ref);

                        case "anual":
                          return _vistaAnual(productos, ref);

                        default:
                          return _vistaDiaria(productos, ref);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _vistaDiaria(List productos, DocumentReference ref) {
    return ListView.builder(
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final producto = productos[index];
        final cantidad =
            producto['cantidades']?['0'] ?? producto['cantidad'] ?? 0;

        return Card(
          child: ListTile(
            title: Text(producto['nombre'] ?? ''),
            subtitle: Text(
              "Cant: $cantidad | Compra: \$${producto['precio_compra']} | Base: \$${producto['precio_por_defecto'] ?? 0}",
            ),

            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("\$${producto['valor_total']}"),

                IconButton(
                  icon: const Icon(Icons.attach_money),
                  onPressed: () => _mostrarGanancia(producto),
                ),

                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editarCelda(ref, producto, productos, 0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _vistaSemanal(List productos, DocumentReference ref) {
    final dias = ["L", "M", "M", "J", "V", "S", "D"];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text("Producto")),
          ...dias.map((d) => DataColumn(label: Text(d))),
        ],
        rows: productos.map((p) {
          return DataRow(
            cells: [
              DataCell(Text(p['nombre'])),

              ...List.generate(7, (i) {
                final cantidad = p['cantidades']?[i.toString()] ?? 0;

                return DataCell(
                  GestureDetector(
                    onTap: () => _editarCelda(ref, p, productos, i),
                    child: Text(cantidad.toString()),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _vistaMensual(List productos, DocumentReference ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Producto")),
          DataColumn(label: Text("S1")),
          DataColumn(label: Text("S2")),
          DataColumn(label: Text("S3")),
          DataColumn(label: Text("S4")),
        ],
        rows: productos.map((p) {
          return DataRow(
            cells: [
              DataCell(Text(p['nombre'])),

              ...List.generate(4, (i) {
                final cantidad = p['cantidades']?[i.toString()] ?? 0;

                return DataCell(
                  GestureDetector(
                    onTap: () => _editarCelda(ref, p, productos, i),
                    child: Text(cantidad.toString()),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _vistaAnual(List productos, DocumentReference ref) {
    final meses = [
      "Ene",
      "Feb",
      "Mar",
      "Abr",
      "May",
      "Jun",
      "Jul",
      "Ago",
      "Sep",
      "Oct",
      "Nov",
      "Dic",
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text("Producto")),
          ...meses.map((m) => DataColumn(label: Text(m))),
        ],
        rows: productos.map((p) {
          return DataRow(
            cells: [
              DataCell(Text(p['nombre'])),

              ...List.generate(12, (i) {
                final cantidad = p['cantidades']?[i.toString()] ?? 0;

                return DataCell(
                  GestureDetector(
                    onTap: () => _editarCelda(ref, p, productos, i),
                    child: Text(cantidad.toString()),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}
