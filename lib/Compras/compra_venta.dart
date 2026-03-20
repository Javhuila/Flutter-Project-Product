import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Compras/add_compra.dart';
import 'package:flutter_project_product/Compras/info_compra.dart';

class CompraVenta extends StatefulWidget {
  const CompraVenta({super.key});

  @override
  State<CompraVenta> createState() => _CompraVentaState();
}

class _CompraVentaState extends State<CompraVenta> {
  IconData getIcon(String tipo) {
    switch (tipo) {
      case 'diario':
        return Icons.today;
      case 'semanal':
        return Icons.calendar_view_week;
      case 'mensual':
        return Icons.calendar_month;
      case 'anual':
        return Icons.event;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final comprasStream = FirebaseFirestore.instance
        .collection('compras')
        .orderBy('fecha', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text("Comprar"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddCompra()),
              );
            },
            icon: Icon(Icons.add_shopping_cart),
          ),
        ],
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

          return ListView.builder(
            itemCount: compras.length,
            itemBuilder: (context, index) {
              final data = compras[index].data();

              final fecha = data['fecha'] as Timestamp?;
              final fechaText = fecha != null
                  ? fecha.toDate().toString().split(' ')[0]
                  : 'Sin fecha';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(getIcon(data['concurrencia'] ?? '')),
                  ),

                  title: Text(
                    "${data['total_productos']} productos",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Proveedor: ${data['proveedor'] ?? 'N/A'}"),
                      Text("Destinatario: ${data['destinatario'] ?? 'N/A'}"),
                    ],
                  ),

                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "\$${data['total_compra'] ?? 0}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(fechaText, style: const TextStyle(fontSize: 12)),
                    ],
                  ),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InfoCompra(compra: compras[index]),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
