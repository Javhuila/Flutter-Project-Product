import 'package:pdf/widgets.dart' as pw;

class ProductosPdf {
  final String nombre;
  final String marca;
  final String precio;
  final String clasificacion;
  final pw.ImageProvider? imagen;

  ProductosPdf({
    required this.nombre,
    required this.marca,
    required this.precio,
    required this.clasificacion,
    required this.imagen,
  });
}
