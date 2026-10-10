import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> saveProductos({
  required String nombre,
  required String contenido,
  required double precio,
  double? precioEmpresa,
  required String marca,
  required String categoria,
  required String clasificacion,
  required String imageUrl,
  required String adminId,
}) async {
  final productosRef = FirebaseFirestore.instance.collection('productos');

  await productosRef.add({
    'nombre': nombre,
    'contenido': contenido,
    'precio': precio,
    'precio_empresa': precioEmpresa ?? 0.0, // new field
    'marca': marca,
    'categoria': categoria,
    'clasificacion': clasificacion,
    'imagen': imageUrl,
    'fecha_creacion': Timestamp.now(),
    'adminId': adminId, // ← Único ID que guardas
  });
}
