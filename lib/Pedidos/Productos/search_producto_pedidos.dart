import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Pedidos/info_pedido.dart';

class SearchProductoPedidos extends StatefulWidget {
  const SearchProductoPedidos({super.key});

  @override
  State<SearchProductoPedidos> createState() => _SearchProductoPedidosState();
}

class _SearchProductoPedidosState extends State<SearchProductoPedidos> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _resultados = [];

  bool loading = false;

  Future<void> _buscarProducto() async {
    final texto = _searchController.text.trim().toLowerCase();
    if (texto.isEmpty) return;

    setState(() {
      loading = true;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('pedidos')
        .get();

    final resultados = snapshot.docs.where((doc) {
      final data = doc.data();
      final nombres = List<String>.from(data['productos_nombres'] ?? []);

      return nombres.any((nombre) => nombre.contains(texto));
    }).toList();

    setState(() {
      _resultados = resultados;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar productos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextFormField(
              controller: _searchController,
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
            child: ListView.builder(
              itemCount: _resultados.length,
              itemBuilder: (context, index) {
                final pedido = _resultados[index];
                final data = pedido.data() as Map<String, dynamic>;
                final producto = obtenerProducto(data, _searchController.text);

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(data['cliente']),

                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...producto.map((producto) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Producto: ${producto['nombre']}"),

                                Text("Cantidad: ${producto['cantidad']}"),

                                Text("Valor unidad: \$${producto['precio']}"),

                                Text("Total: \$${producto['total']}"),

                                const Divider(),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),

                    trailing: const Icon(Icons.arrow_forward),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InfoPedido(pedido: pedido),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
