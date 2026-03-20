import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddCompra extends StatefulWidget {
  const AddCompra({super.key});

  @override
  State<AddCompra> createState() => _AddCompraState();
}

class _AddCompraState extends State<AddCompra> {
  final _formProductosKey = GlobalKey<FormState>();
  final _formInfoKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> productos = [];
  double totalCompra = 0;

  String? concurrencia;
  String? destinatario;
  String? productoId;
  String? nombre;
  String? imagen;

  final precioController = TextEditingController();
  final precioDefaultController = TextEditingController();
  final cantidadController = TextEditingController();
  final proveedorController = TextEditingController();

  double total = 0;

  void _agregarProducto(
    String id,
    String nombre,
    double precio,
    double precioDefault,
    int cantidad,
  ) {
    final total = precio * cantidad;

    setState(() {
      final index = productos.indexWhere((p) => p['productoId'] == id);

      if (index != -1) {
        productos[index]['cantidad'] += cantidad;

        productos[index]['cantidades'] ??= {};
        final actual = productos[index]['cantidades']["0"] ?? 0;

        productos[index]['cantidades']["0"] = actual + cantidad;

        productos[index]['valor_total'] += total;
      } else {
        productos.add({
          "productoId": id,
          "nombre": nombre,
          "precio_por_defecto": precioDefault,
          "precio_compra": precio,
          "cantidad": cantidad,
          "cantidades": {"0": cantidad},
          "valor_total": total,
        });
      }
      totalCompra += total;
    });
  }

  void _calcularTotal() {
    final precio = double.tryParse(precioController.text) ?? 0;
    final cantidad = int.tryParse(cantidadController.text) ?? 0;

    setState(() {
      total = precio * cantidad;
    });
  }

  Future<void> _guardarCompra() async {
    if (productos.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Agrega al menos un producto")));
      return;
    }

    if (!_formInfoKey.currentState!.validate()) return;

    await FirebaseFirestore.instance.collection('compras').add({
      "proveedor": proveedorController.text.isEmpty
          ? null
          : proveedorController.text,
      "destinatario": destinatario,
      "concurrencia": concurrencia,
      "fecha": Timestamp.now(),
      "total_compra": totalCompra,
      "total_productos": productos.length,
      "productos": productos,
    });

    Navigator.pop(context);
  }

  @override
  void dispose() {
    precioDefaultController.dispose();
    precioController.dispose();
    cantidadController.dispose();
    proveedorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Compra producto")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formProductosKey,
            child: Column(
              children: [
                StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('productos')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return CircularProgressIndicator();

                    final docs = snapshot.data!.docs;

                    return DropdownButton<String>(
                      isExpanded: true,
                      itemHeight: 100,
                      hint: const Text("Seleccionar producto"),
                      value: productoId,
                      items: docs.map((doc) {
                        final data = doc.data();

                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(data['nombre']),
                          onTap: () {
                            nombre = data['nombre'];
                            imagen = data['imagen'];
                          },
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          productoId = value;
                        });
                      },
                    );
                  },
                ),
                TextFormField(
                  controller: precioDefaultController,
                  decoration: const InputDecoration(
                    labelText: "Precio por defecto",
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return "Campo obligatorio";
                    if (double.tryParse(value) == null)
                      return "Número inválido";
                    return null;
                  },
                ),
                TextFormField(
                  controller: precioController,
                  decoration: const InputDecoration(labelText: "Precio compra"),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _calcularTotal(),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return "Campo obligatorio";
                    if (double.tryParse(value) == null)
                      return "Número inválido";
                    return null;
                  },
                ),

                TextFormField(
                  controller: cantidadController,
                  decoration: const InputDecoration(labelText: "Cantidad"),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _calcularTotal(),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return "Campo obligatorio";
                    if (int.tryParse(value) == null) return "Número inválido";
                    return null;
                  },
                ),

                ElevatedButton(
                  onPressed: () {
                    if (!_formProductosKey.currentState!.validate()) return;

                    if (productoId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Selecciona un producto")),
                      );
                      return;
                    }

                    final precioDefault =
                        double.tryParse(precioDefaultController.text) ?? 0;
                    final precio = double.tryParse(precioController.text) ?? 0;
                    final cantidad = int.tryParse(cantidadController.text) ?? 0;

                    if (precio <= 0 || precioDefault <= 0 || cantidad <= 0)
                      return;

                    _agregarProducto(
                      productoId!,
                      nombre!,
                      precio,
                      precioDefault,
                      cantidad,
                    );

                    // limpiar inputs
                    precioController.clear();
                    cantidadController.clear();
                    precioDefaultController.clear();
                  },
                  child: Text("Agregar producto"),
                ),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text("Producto")),
                      DataColumn(label: Text("Cant")),
                      DataColumn(label: Text("Total")),
                      DataColumn(label: Text("Acción")),
                    ],
                    rows: productos.map((p) {
                      return DataRow(
                        cells: [
                          DataCell(Text(p['nombre'])),
                          DataCell(Text(p['cantidad'].toString())),
                          DataCell(Text("\$${p['valor_total']}")),
                          DataCell(
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  totalCompra -= p['valor_total'];
                                  productos.remove(p);
                                });
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                Form(
                  key: _formInfoKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: proveedorController,
                        decoration: const InputDecoration(
                          labelText: "Proveedor",
                        ),
                      ),

                      TextFormField(
                        decoration: InputDecoration(labelText: "Destinatario"),
                        onChanged: (value) => destinatario = value,
                      ),

                      DropdownButtonFormField<String>(
                        initialValue: concurrencia,
                        hint: Text("Frecuencia"),
                        items: ["diario", "semanal", "mensual", "anual"]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            concurrencia = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) return "Campo obligatorio";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Total compra: \$${totalCompra.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _guardarCompra,
                  child: const Text("Guardar Compra"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
