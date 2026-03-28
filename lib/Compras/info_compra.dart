import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

class InfoCompra extends StatefulWidget {
  final DocumentSnapshot compra;

  const InfoCompra({super.key, required this.compra});

  @override
  State<InfoCompra> createState() => _InfoCompraState();
}

class _InfoCompraState extends State<InfoCompra> {
  Map<String, bool> _celdasResaltadas = {};

  String _nombrePeriodo(String concurrencia, int index) {
    switch (concurrencia) {
      case "diario":
        return "Hoy";

      case "semanal":
        const dias = [
          "Lunes",
          "Martes",
          "Miércoles",
          "Jueves",
          "Viernes",
          "Sábado",
          "Domingo",
        ];
        return dias[index];

      case "mensual":
        return "Semana ${index + 1}";

      case "anual":
        const meses = [
          "Enero",
          "Febrero",
          "Marzo",
          "Abril",
          "Mayo",
          "Junio",
          "Julio",
          "Agosto",
          "Septiembre",
          "Octubre",
          "Noviembre",
          "Diciembre",
        ];
        return meses[index];

      default:
        return "";
    }
  }

  Future<void> _editarCelda(
    DocumentReference ref,
    Map<String, dynamic> producto,
    List productos,
    String concurrencia,
    int indexCelda,
  ) async {
    final key = "${producto['productoId']}_$indexCelda";

    setState(() {
      _celdasResaltadas[key] = true;
    });

    // quitar highlight después de un tiempo
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _celdasResaltadas[key] = false;
      });
    });
    // final indexCelda = _obtenerIndiceActual(concurrencia);
    TextEditingController controller = TextEditingController(
      text: (producto['cantidades']?[indexCelda.toString()] ?? 0).toString(),
    );

    final nuevaCantidad = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          "Editar cantidad para (${_nombrePeriodo(concurrencia, indexCelda)})",
        ),
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

    // recalcular total del producto
    double totalProducto = 0;
    final precio = (producto['precio_compra'] ?? 0).toDouble();

    nuevosProductos[index]['cantidades'].forEach((key, value) {
      totalProducto += value * precio;
    });

    nuevosProductos[index]['valor_total'] = totalProducto;

    // recalcular total general
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
    final tipoCompra = producto['tipo_compra'] ?? 'normal';
    final esFlete = tipoCompra == 'flete';

    final precioCompra = (producto['precio_compra'] ?? 0).toDouble();
    final precioVenta = (producto['precio_por_defecto'] ?? 0).toDouble();
    int cantidadTotal = 0;

    (producto['cantidades'] as Map<String, dynamic>? ?? {}).forEach((
      key,
      value,
    ) {
      cantidadTotal += (value as int);
    });

    double gananciaUnitaria = 0;
    double gananciaTotal = 0;

    if (esFlete) {
      gananciaUnitaria = precioCompra - precioVenta;
      gananciaTotal = gananciaUnitaria * cantidadTotal;
    }

    if (esFlete && precioVenta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Producto sin precio de venta")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ganancia"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tipo: ${esFlete ? "Flete" : "Normal"}"),
            Text("Precio compra: \$${precioCompra.toStringAsFixed(0)}"),

            if (esFlete) ...[
              Text("Precio venta: \$${precioVenta.toStringAsFixed(0)}"),
              const SizedBox(height: 10),
              Text(
                "Ganancia unitaria: \$${gananciaUnitaria.toStringAsFixed(0)}",
              ),
              Text("Cantidad: $cantidadTotal"),
              const SizedBox(height: 10),
              Text(
                "Ganancia total: \$${gananciaTotal.toStringAsFixed(0)}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ] else
              const Text("Este producto no maneja cálculo de ganancia"),
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

  Future<Directory?> getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // En Android, el directorio Downloads está en External Storage Public Directory
      final downloadsPath = Directory('/storage/emulated/0/Download');
      if (await downloadsPath.exists()) {
        return downloadsPath;
      }
    } else if (Platform.isIOS) {
      // iOS no tiene una carpeta Downloads pública, usa Documents
      return await getApplicationDocumentsDirectory();
    }
    return null;
  }

  Future<void> _generarPDF(
    List productos,
    String concurrencia,
    String fechaCom,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // Solicitar permiso de almacenamiento (solo Android)
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();

      if (!status.isGranted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Permiso de almacenamiento denegado')),
        );
        return;
      }
    }

    final pdf = pw.Document();

    double gananciaTotalCompra = 0;

    for (var p in productos) {
      final tipoCompra = p['tipo_compra'] ?? 'normal';

      if (tipoCompra == 'flete') {
        final compra = (p['precio_compra'] ?? 0).toDouble();
        final base = (p['precio_por_defecto'] ?? 0).toDouble();

        int cantidadTotal = 0;

        (p['cantidades'] as Map<String, dynamic>? ?? {}).forEach((key, value) {
          cantidadTotal += (value as int);
        });

        gananciaTotalCompra += (compra - base) * cantidadTotal;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];

          widgets.add(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Reporte de Compra",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text("Fecha: $fechaCom")),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      flex: 6,
                      child: pw.Text(
                        "Ganancia total: \$${gananciaTotalCompra.toStringAsFixed(0)}",
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: gananciaTotalCompra >= 0
                              ? PdfColors.green
                              : PdfColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text("Concurrencia: $concurrencia"),
                pw.SizedBox(height: 20),

                // Generar tabla según la concurrencia
                _tablaPDF(productos, concurrencia),
                pw.SizedBox(height: 20),
                pw.Text(
                  "Detalle de Ganancias",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                ..._detalleGananciasPDF(productos),
              ],
            ),
          );

          return widgets;
        },
      ),
    );

    // Guardar en el dispositivo
    final directory = await getDownloadsDirectory();
    if (directory == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo acceder a la carpeta Downloads'),
        ),
      );
      return;
    }
    final folder = Directory('${directory.path}/MisReportes');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final now = DateTime.now();

    final formatted =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour}_${now.minute}_${now.second}";

    final file = File('${folder.path}/reporte_compra_$formatted.pdf');
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("PDF generado en: ${file.path}")));
  }

  Future<void> _mostrarDialogoCarga() async {
    final navigator = Navigator.of(context);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar"),
        content: Text("¿Deseas generar el pdf?"),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => navigator.pop(true),
            child: const Text("Confirmar"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // No permitir cerrar tocando fuera
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Flexible(child: Text("Generando catálogo...", softWrap: true)),
            ],
          ),
        );
      },
    );
    try {
      final snapshot = await widget.compra.reference.get();
      final compraData = snapshot.data() as Map<String, dynamic>;

      final productos = compraData['productos'] ?? [];
      final concurrencia = compraData['concurrencia'] ?? 'diario';
      String fechaCom;
      final fechaCompra = compraData["fecha"];

      if (fechaCompra is Timestamp) {
        fechaCom = fechaCompra.toDate().toIso8601String().split('T').first;
      } else if (fechaCompra is String) {
        fechaCom =
            DateTime.tryParse(
              fechaCompra,
            )?.toIso8601String().split('T').first ??
            '';
      } else {
        fechaCom = 'Sin fecha';
      }

      await _generarPDF(productos, concurrencia, fechaCom);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      navigator.pop(); // cerrar loader
    }
  }

  pw.Widget _tablaPDF(List productos, String concurrencia) {
    switch (concurrencia) {
      case 'diario':
        return pw.TableHelper.fromTextArray(
          headers: ['Producto', 'Cantidad', 'Compra', 'Base', 'Total'],
          data: productos.map((p) {
            final cantidad = p['cantidades']?['0'] ?? 0;
            final total = p['valor_total'] ?? 0;
            final tipoCompra = p['tipo_compra'] ?? 'normal';
            final esFlete = tipoCompra == 'flete';
            return [
              p['nombre'],
              cantidad,
              p['precio_compra'],
              esFlete ? p['precio_por_defecto'] : '-',
              total,
            ];
          }).toList(),
        );

      case 'semanal':
        final dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
        return pw.TableHelper.fromTextArray(
          headers: ['Producto', ...dias],
          data: productos.map((p) {
            return [
              p['nombre'],
              ...List.generate(7, (i) => p['cantidades']?[i.toString()] ?? 0),
            ];
          }).toList(),
        );

      case 'mensual':
        final semanas = ['S1', 'S2', 'S3', 'S4'];
        return pw.TableHelper.fromTextArray(
          headers: ['Producto', ...semanas],
          data: productos.map((p) {
            return [
              p['nombre'],
              ...List.generate(4, (i) => p['cantidades']?[i.toString()] ?? 0),
            ];
          }).toList(),
        );

      case 'anual':
        final meses = [
          'Ene',
          'Feb',
          'Mar',
          'Abr',
          'May',
          'Jun',
          'Jul',
          'Ago',
          'Sep',
          'Oct',
          'Nov',
          'Dic',
        ];
        return pw.TableHelper.fromTextArray(
          headers: ['Producto', ...meses],
          data: productos.map((p) {
            return [
              p['nombre'],
              ...List.generate(12, (i) => p['cantidades']?[i.toString()] ?? 0),
            ];
          }).toList(),
        );

      default:
        return pw.Text("Concurrencia no válida");
    }
  }

  List<pw.Widget> _detalleGananciasPDF(List productos) {
    List<pw.Widget> lista = [];

    for (var p in productos) {
      final tipoCompra = p['tipo_compra'] ?? 'normal';
      final esFlete = tipoCompra == 'flete';

      final precioCompra = (p['precio_compra'] ?? 0).toDouble();
      final precioVenta = (p['precio_por_defecto'] ?? 0).toDouble();

      int cantidadTotal = 0;

      (p['cantidades'] as Map<String, dynamic>? ?? {}).forEach((key, value) {
        cantidadTotal += (value as int);
      });

      double gananciaUnitaria = 0;
      double gananciaTotal = 0;

      if (esFlete) {
        gananciaUnitaria = precioCompra - precioVenta;
        gananciaTotal = gananciaUnitaria * cantidadTotal;
      }

      lista.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                p['nombre'] ?? '',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 4),

              pw.Text("Tipo: ${esFlete ? "Flete" : "Normal"}"),
              pw.Text("Precio compra: \$${precioCompra.toStringAsFixed(0)}"),

              if (esFlete) ...[
                pw.Text("Precio venta: \$${precioVenta.toStringAsFixed(0)}"),
                pw.Text(
                  "Ganancia unitaria: \$${gananciaUnitaria.toStringAsFixed(0)}",
                ),
                pw.Text("Cantidad: $cantidadTotal"),
                pw.Text(
                  "Ganancia total: \$${gananciaTotal.toStringAsFixed(0)}",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ] else
                pw.Text("No aplica ganancia"),
            ],
          ),
        ),
      );
    }

    return lista;
  }

  int _obtenerIndiceActual(String concurrencia) {
    final now = DateTime.now();

    switch (concurrencia) {
      case "diario":
        return 0;

      case "semanal":
        // Lunes = 0, Domingo = 6
        return now.weekday - 1;

      case "mensual":
        // Semana del mes (0–5)
        final now = DateTime.now();
        final primerDia = DateTime(now.year, now.month, 1);

        final offset = primerDia.weekday - 1; // lunes = 0
        return ((now.day + offset - 1) / 7).floor();

      case "anual":
        // Mes (0–11)
        return now.month - 1;

      default:
        return 0;
    }
  }

  int _semanasDelMes(DateTime fecha) {
    final primerDia = DateTime(fecha.year, fecha.month, 1);
    final ultimoDia = DateTime(fecha.year, fecha.month + 1, 0);

    final diasMes = ultimoDia.day;

    final primerWeekday = primerDia.weekday; // 1=Lunes ... 7=Domingo

    final totalCeldas = diasMes + (primerWeekday - 1);

    return (totalCeldas / 7).ceil();
  }

  Widget _celdaConIndicador({
    required BuildContext context,
    required String text,
    required bool esActual,
    required bool resaltado,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        transform: resaltado
            ? (Matrix4.identity()..scaleByDouble(1.15, 0, 0, 0))
            : Matrix4.identity(),
        decoration: esActual
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: resaltado
                    ? colorScheme.secondary.withValues(alpha: 0.9)
                    : esActual
                    ? colorScheme.primary.withValues(alpha: 0.9)
                    : Colors.transparent,
                boxShadow: resaltado
                    ? [
                        BoxShadow(
                          color: colorScheme.secondary.withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : esActual
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              )
            : null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: Text(
            text,
            key: ValueKey(text),
            style: TextStyle(
              fontWeight: esActual ? FontWeight.bold : FontWeight.normal,
              color: onTap == null
                  ? theme.disabledColor
                  : esActual
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  bool _edicionBloqueada(DateTime fechaCompra, String concurrencia) {
    final now = DateTime.now();

    switch (concurrencia) {
      case "diario":
        return false;

      case "semanal":
        // fin de semana = domingo
        final inicioSemana = fechaCompra.subtract(
          Duration(days: fechaCompra.weekday - 1),
        );
        final finSemana = inicioSemana.add(const Duration(days: 6));

        return now.isAfter(finSemana);

      case "mensual":
        return now.year != fechaCompra.year || now.month != fechaCompra.month;

      case "anual":
        return now.year != fechaCompra.year;

      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de Compra"),
        actions: [
          IconButton(
            tooltip: "Generar PDF",
            onPressed: _mostrarDialogoCarga,
            icon: Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
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

          final fechaDate = fecha != null
              ? (fecha as Timestamp).toDate()
              : DateTime.now();

          double gananciaTotalCompra = 0;

          for (var p in productos) {
            final tipoCompra = p['tipo_compra'] ?? 'normal';

            if (tipoCompra == 'flete') {
              final compra = (p['precio_compra'] ?? 0).toDouble();
              final base = (p['precio_por_defecto'] ?? 0).toDouble();
              int cantidadTotal = 0;

              (p['cantidades'] as Map<String, dynamic>? ?? {}).forEach((
                key,
                value,
              ) {
                cantidadTotal += (value as int);
              });

              gananciaTotalCompra += (compra - base) * cantidadTotal;
            }
          }

          final concurrencia = data['concurrencia'] ?? 'diario';

          final bloqueado = _edicionBloqueada(fechaDate, concurrencia);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: ListTile(
                    title: Text(
                      "Proveedor: ${data['proveedor'] ?? 'Sin proveedor'}",
                    ),
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

                Expanded(
                  child: Builder(
                    builder: (_) {
                      final ref = snapshot.data!.reference;

                      switch (concurrencia) {
                        case "diario":
                          return _vistaDiaria(
                            productos,
                            ref,
                            concurrencia,
                            bloqueado,
                          );

                        case "semanal":
                          return _vistaSemanal(
                            productos,
                            ref,
                            concurrencia,
                            bloqueado,
                          );

                        case "mensual":
                          return _vistaMensual(
                            productos,
                            ref,
                            concurrencia,
                            bloqueado,
                          );

                        case "anual":
                          return _vistaAnual(
                            productos,
                            ref,
                            concurrencia,
                            bloqueado,
                          );

                        default:
                          return _vistaDiaria(
                            productos,
                            ref,
                            concurrencia,
                            bloqueado,
                          );
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

  Widget _vistaDiaria(
    List productos,
    DocumentReference ref,
    String concurrencia,
    bool bloqueado,
  ) {
    return ListView.builder(
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final producto = productos[index];
        final cantidad = producto['cantidades']?['0'] ?? 0;

        final tipoCompra = producto['tipo_compra'] ?? 'normal';
        final esFlete = tipoCompra == 'flete';

        return Card(
          child: ListTile(
            title: Text(producto['nombre'] ?? ''),
            subtitle: Text(
              esFlete
                  ? "Cant: $cantidad | Compra: \$${producto['precio_compra']} | Base: \$${producto['precio_por_defecto'] ?? 0}"
                  : "Cant: $cantidad | Compra: \$${producto['precio_compra']}",
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
                  onPressed: bloqueado
                      ? null
                      : () => _editarCelda(
                          ref,
                          producto,
                          productos,
                          concurrencia,
                          index,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _vistaSemanal(
    List productos,
    DocumentReference ref,
    String concurrencia,
    bool bloqueado,
  ) {
    final dias = ["L", "M", "M", "J", "V", "S", "D"];

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text("Producto")),
              ...dias.map((d) => DataColumn(label: Text(d))),
            ],
            rows: productos.map((p) {
              final indiceActual = _obtenerIndiceActual(concurrencia);
              return DataRow(
                cells: [
                  DataCell(
                    GestureDetector(
                      onTap: () {
                        _mostrarGanancia(p);
                      },
                      child: Text(p['nombre']),
                    ),
                  ),

                  ...List.generate(7, (i) {
                    final cantidad = p['cantidades']?[i.toString()] ?? 0;
                    final key = "${p['productoId']}_$i";
                    final resaltado = _celdasResaltadas[key] ?? false;

                    return DataCell(
                      _celdaConIndicador(
                        context: context,
                        text: cantidad.toString(),
                        esActual: i == indiceActual,
                        resaltado: resaltado,
                        onTap: bloqueado
                            ? null
                            : () => _editarCelda(
                                ref,
                                p,
                                productos,
                                concurrencia,
                                i,
                              ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
        if (bloqueado)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Compra finalizada",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _vistaMensual(
    List productos,
    DocumentReference ref,
    String concurrencia,
    bool bloqueado,
  ) {
    final now = DateTime.now();
    final totalSemanas = _semanasDelMes(now);
    final indiceActual = _obtenerIndiceActual(concurrencia);

    final semanas = List.generate(totalSemanas, (i) => "S${i + 1}");

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text("Producto")),
              ...semanas.map((s) => DataColumn(label: Text(s))),
            ],
            rows: productos.map((p) {
              return DataRow(
                cells: [
                  DataCell(
                    GestureDetector(
                      onTap: () {
                        _mostrarGanancia(p);
                      },
                      child: Text(p['nombre']),
                    ),
                  ),

                  ...List.generate(totalSemanas, (i) {
                    final cantidad = p['cantidades']?[i.toString()] ?? 0;
                    final key = "${p['productoId']}_$i";
                    final resaltado = _celdasResaltadas[key] ?? false;

                    return DataCell(
                      _celdaConIndicador(
                        context: context,
                        text: cantidad.toString(),
                        esActual: i == indiceActual,
                        resaltado: resaltado,
                        onTap: bloqueado
                            ? null
                            : () => _editarCelda(
                                ref,
                                p,
                                productos,
                                concurrencia,
                                i,
                              ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
        if (bloqueado)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Compra finalizada",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _vistaAnual(
    List productos,
    DocumentReference ref,
    String concurrencia,
    bool bloqueado,
  ) {
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

    final indiceActual = _obtenerIndiceActual(concurrencia);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text("Producto")),
              ...meses.map((m) => DataColumn(label: Text(m))),
            ],
            rows: productos.map((p) {
              return DataRow(
                cells: [
                  DataCell(
                    GestureDetector(
                      onTap: () {
                        _mostrarGanancia(p);
                      },
                      child: Text(p['nombre']),
                    ),
                  ),

                  ...List.generate(12, (i) {
                    final cantidad = p['cantidades']?[i.toString()] ?? 0;
                    final key = "${p['productoId']}_$i";
                    final resaltado = _celdasResaltadas[key] ?? false;

                    return DataCell(
                      _celdaConIndicador(
                        context: context,
                        text: cantidad.toString(),
                        esActual: i == indiceActual,
                        resaltado: resaltado,
                        onTap: bloqueado
                            ? null
                            : () => _editarCelda(
                                ref,
                                p,
                                productos,
                                concurrencia,
                                i,
                              ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
        if (bloqueado)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Compra finalizada",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
