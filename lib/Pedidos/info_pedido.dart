import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Pedidos/edit_pedidos.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'dart:io';
import 'package:flutter/services.dart' show NetworkAssetBundle, MethodChannel;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class InfoPedido extends StatefulWidget {
  final DocumentSnapshot pedido;
  const InfoPedido({super.key, required this.pedido});

  @override
  State<InfoPedido> createState() => _InfoPedidoState();
}

class _InfoPedidoState extends State<InfoPedido> with TickerProviderStateMixin {
  ReceiptController? _receiptController;

  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  String? _userRole;
  bool _isLoadingRole = true;

  DocumentSnapshot? _deudaActual;
  List<DocumentSnapshot> _otrasDeudas = [];

  bool _cargandoDeuda = true;

  Map<String, dynamic>? _adminCache;
  String? _clienteTelefonoCache;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _offsetAnimation =
        Tween<Offset>(begin: const Offset(0.5, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    _loadUserRole();
    _cargarDeudas();
  }

  Future<void> _loadUserRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        setState(() {
          _userRole = doc['role'];
          _isLoadingRole = false;
        });
      } else {
        setState(() {
          _userRole = 'asistente'; // fallback
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      setState(() {
        _userRole = 'asistente'; // fallback en caso de error
        _isLoadingRole = false;
      });
    }
  }

  Future<String?> _obtenerFirmaDelUsuario(String userId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (!userDoc.exists) return null;
    final data = userDoc.data()!;
    final role = data['role'];
    if (role == 'admin') {
      return data['firmaUrl']; // campo donde guardas la URL o ruta de firma
    } else if (role == 'asistente') {
      final adminId = data['adminId'];
      if (adminId == null) return null;
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .get();
      return adminDoc.data()?['firmaUrl'];
    }
    return null;
  }

  Future<File?> _generarPDF(Map<String, dynamic> data) async {
    try {
      final pdf = pw.Document();
      final cliente = data['cliente'] ?? '';
      final numPedido = data['numero_pedido'] ?? '';
      final formaPago = data['forma_pago'] ?? '';
      final observacion = data['observacion'] ?? '';
      final valorTotal = (data['valor_total'] ?? 0).toDouble();
      final productos = data['productos'] as List<dynamic>? ?? [];

      // Fecha
      String fecha;
      final fechaData = data['fecha'];
      if (fechaData is Timestamp) {
        fecha = fechaData.toDate().toIso8601String().split('T').first;
      } else if (fechaData is String) {
        fecha =
            DateTime.tryParse(fechaData)?.toIso8601String().split('T').first ??
            '';
      } else {
        fecha = 'Sin fecha';
      }

      // Obtener firma si existe
      String? firmaUrl;
      String? userId = data['adminId'] ?? data['creado_por'];
      if (userId != null) {
        firmaUrl = await _obtenerFirmaDelUsuario(userId);
      }

      Uint8List? firmaBytes;
      if (firmaUrl != null && firmaUrl.isNotEmpty) {
        try {
          final response = await NetworkAssetBundle(
            Uri.parse(firmaUrl),
          ).load("");
          firmaBytes = response.buffer.asUint8List();
        } catch (_) {}
      }

      String? adminNombre;
      String? adminTelefono;

      if (userId != null) {
        final adminData = await _obtenerAdminData(userId);

        if (adminData != null) {
          adminNombre = adminData['name'];
          adminTelefono = adminData['telefono'];
        }
      }

      String? clienteTelefono;

      if (cliente.isNotEmpty) {
        clienteTelefono = await _obtenerClienteData(cliente);
      }

      // Imprimir deuda
      final pago = data['pago'] as Map<String, dynamic>?;

      String textoFormaPago = '';
      String textoDeuda = '';
      String textoUltimoPago = '';

      const formasPagoMap = {
        'entrega': 'Pago por entrega',
        'bancario': 'Pago bancario',
        'cuotas': 'Cuotas',
        'fianza': 'Fianza / Crédito',
      };

      textoFormaPago = formasPagoMap[formaPago] ?? formaPago;

      if (pago != null && pago['resumen'] != null) {
        final resumen = pago['resumen'];

        final total = (resumen['total'] ?? 0).toDouble();
        final pagado = (resumen['pagado'] ?? 0).toDouble();
        final saldo = (resumen['saldo'] ?? 0).toDouble();

        // Obtener última fecha desde historial (si existe)
        DateTime? ultimaFecha;

        final refId = pago['referencia_pago'];

        if (refId != null) {
          try {
            final deudaDoc = await FirebaseFirestore.instance
                .collection('deudas')
                .doc(refId)
                .get();

            if (deudaDoc.exists) {
              final deudaData = deudaDoc.data();

              final historial = deudaData?['historial'] as List<dynamic>? ?? [];

              if (historial.isNotEmpty) {
                final last = historial.last['fecha'] as Timestamp;
                ultimaFecha = last.toDate();
              }

              // Cuotas
              if (formaPago == 'cuotas') {
                final totalCuotas = deudaData?['config']?['cuotas'] ?? 0;

                textoDeuda =
                    'Cuotas: ${historial.length} / $totalCuotas\nSaldo: \$${saldo.toInt()}';
              }

              // Fianza
              if (formaPago == 'fianza') {
                textoDeuda =
                    'Pagado: \$${pagado.toInt()} / \$${total.toInt()}\nSaldo: \$${saldo.toInt()}';
              }
            }
          } catch (_) {}
        }

        if (ultimaFecha != null) {
          textoUltimoPago =
              'Último pago: ${ultimaFecha.toString().split(' ')[0]}';
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          footer: (context) {
            return pw.Column(
              children: [
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Realizado por: ${adminNombre ?? 'Administrador'}",
                      style: pw.TextStyle(fontSize: 20),
                    ),
                    pw.Text(
                      adminTelefono ?? '',
                      style: pw.TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ],
            );
          },
          build: (pw.Context context) {
            final widgets = <pw.Widget>[];

            widgets.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Fecha: $fecha', style: pw.TextStyle(fontSize: 28)),
                  pw.Text(
                    'N° $numPedido',
                    style: pw.TextStyle(
                      fontSize: 33,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 7, // 🔥 50%
                    child: pw.Text(
                      'Cliente: $cliente',
                      style: pw.TextStyle(
                        fontSize: 35,
                        fontNormal: pw.Font.helvetica(),
                      ),
                      maxLines: 2,
                      softWrap: true,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 3, // 🔥 50%
                    child: pw.Text(
                      'Tel: ${clienteTelefono ?? ''}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 22),
                    ),
                  ),
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(
              pw.Text(
                'Forma de pago: $textoFormaPago',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            if (textoDeuda.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 4));

              widgets.add(
                pw.Text(textoDeuda, style: const pw.TextStyle(fontSize: 14)),
              );
            }

            if (textoUltimoPago.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 2));

              widgets.add(
                pw.Text(
                  textoUltimoPago,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              );
            }

            widgets.add(pw.SizedBox(height: 10));
            widgets.add(
              pw.Text(
                'Observación:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            );
            widgets.add(pw.Text(observacion));
            widgets.add(pw.Divider());
            widgets.add(
              pw.Text(
                'Detalle del Pedido:',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 8));

            // Filas de productos
            for (var prod in productos) {
              widgets.add(
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        "${prod['nombre']}",
                        style: pw.TextStyle(fontSize: 17),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        "×${prod['cantidad']}",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 17),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        "\$${prod['precio']}",
                        textAlign: pw.TextAlign.end,
                        style: pw.TextStyle(fontSize: 17),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        "\$${prod['total']}",
                        textAlign: pw.TextAlign.end,
                        style: pw.TextStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ),
              );
              widgets.add(pw.SizedBox(height: 4));
            }

            widgets.add(pw.SizedBox(height: 12));
            widgets.add(
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      "Total:",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      "\$${valorTotal.toStringAsFixed(2)}",
                      textAlign: pw.TextAlign.end,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (firmaBytes != null) {
              widgets.add(pw.Divider());
              widgets.add(
                pw.Text(
                  'Firma:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(pw.Image(pw.MemoryImage(firmaBytes), height: 80));
            }

            return widgets;
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/pedido_${cliente}_$fecha.pdf");
      await file.writeAsBytes(await pdf.save());

      return file;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
      return null;
    }
  }

  Future<void> _generarYCompartirPDF(Map<String, dynamic> data) async {
    final file = await _generarPDF(data);
    if (file == null) return;

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: 'Compartir pedido',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al compartir PDF: $e')));
    }
  }

  Future<void> _enviarPedidoPorWhatsapp(Map<String, dynamic> data) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Mostrar el diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enviar pedido"),
          content: const Text(
            "¿Deseas enviar el pedido al cliente por WhatsApp?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Enviar"),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    if (!mounted) return;

    // Mostrar diálogo de carga
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Flexible(
                child: Text("Enviando pedido al cliente...", softWrap: true),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Tomamos el nombre del cliente desde el pedido
      final clienteNombre = data['cliente'] ?? '';

      if (clienteNombre.isEmpty) {
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('El pedido no tiene cliente asociado.')),
        );
        return;
      }

      // Buscar en la colección "clientes" un documento donde 'nombre' == clienteNombre
      final clientesRef = FirebaseFirestore.instance.collection('clientes');
      final snapshot = await clientesRef
          .where('nombreCompleto', isEqualTo: clienteNombre)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context); // Cierra el diálogo de carga
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'No se encontró el cliente "$clienteNombre" en la base de datos.',
            ),
          ),
        );
        return;
      }

      // Obtener el teléfono del cliente encontrado
      final clienteData = snapshot.docs.first.data();
      final telefono = clienteData['telefono'];

      if (telefono == null || telefono.toString().trim().isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'El cliente "$clienteNombre" no tiene teléfono registrado.',
            ),
          ),
        );
        return;
      }

      // Generar el PDF con la función reutilizable
      final file = await _generarPDF(data);
      if (file == null) {
        navigator.pop();
        return;
      }

      navigator.pop(); // Cierra el diálogo de carga antes de continuar

      // Crear mensaje de WhatsApp
      final telefonoLimpio = telefono.toString().replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      // Agregar código del país si faltan los primeros dígitos
      String telefonoInternacional = telefonoLimpio;
      if (telefonoInternacional.length == 10) {
        telefonoInternacional =
            '57$telefonoInternacional'; // Cambia 57 por tu país
      }

      final mensaje = Uri.encodeComponent(
        "Hola $clienteNombre, te envío tu pedido en PDF.",
      );

      if (Platform.isAndroid) {
        try {
          const platform = MethodChannel('com.example.whatsapp_channel');

          await platform.invokeMethod('sendToWhatsApp', {
            'phone': telefonoInternacional,
            'filePath': file.path,
            'message': 'Hola $clienteNombre, te envío tu pedido en PDF.',
          });

          messenger.showSnackBar(
            const SnackBar(content: Text('WhatsApp abierto correctamente.')),
          );
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Error al abrir WhatsApp: $e')),
          );
        }
      } else {
        // iOS u otras plataformas
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/pdf')],
            text: mensaje,
            subject: "Pedido de $clienteNombre",
          ),
        );
      }
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Error al enviar pedido: $e')),
      );
    }
  }

  Future<void> _cargarDeudas() async {
    if (!mounted) return;

    setState(() {
      _cargandoDeuda = true;
    });
    try {
      final data = widget.pedido.data() as Map<String, dynamic>;

      final pago = data['pago'];

      if (pago == null) {
        debugPrint("SIN PAGO");
        _finalizarCarga();
        return;
      }

      final deudaId = pago['referencia_pago'];

      if (deudaId == null || deudaId.toString().isEmpty) {
        debugPrint("SIN REFERENCIA");
        _finalizarCarga();
        return;
      }

      final deudaDoc = await FirebaseFirestore.instance
          .collection('deudas')
          .doc(deudaId)
          .get();

      if (!deudaDoc.exists) {
        _finalizarCarga();
        return;
      }

      final dataCliente = data['cliente'];

      String clienteNombre = '';

      if (dataCliente is Map) {
        clienteNombre = dataCliente['nombre']?.toString() ?? '';
      } else if (dataCliente is String) {
        clienteNombre = dataCliente;
      } else if (dataCliente is List && dataCliente.isNotEmpty) {
        clienteNombre = dataCliente.first.toString();
      } else {
        clienteNombre = '';
      }

      final otras = await FirebaseFirestore.instance
          .collection('deudas')
          .where('cliente.nombre', isEqualTo: clienteNombre)
          .where('estado', isEqualTo: 'activo')
          .get();

      setState(() {
        _deudaActual = deudaDoc;

        _otrasDeudas = otras.docs.where((d) => d.id != deudaId).toList();

        _cargandoDeuda = false;
      });
    } catch (e, s) {
      debugPrint("ERROR CARGAR DEUDA => $e");
      debugPrint("$s");

      _finalizarCarga();
    }
  }

  void _finalizarCarga() {
    if (!mounted) return;

    setState(() {
      _cargandoDeuda = false;
    });
  }

  Future<Map<String, dynamic>?> _obtenerAdminData(String userId) async {
    if (_adminCache != null) return _adminCache;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (!userDoc.exists) return null;

    final data = userDoc.data()!;
    final role = data['role'];

    if (role == 'admin') {
      return data;
    } else if (role == 'asistente') {
      final adminId = data['adminId'];
      if (adminId == null) return null;

      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .get();

      _adminCache = adminDoc.data();
      return _adminCache;
    }

    return null;
  }

  Future<String?> _obtenerClienteData(String nombreCliente) async {
    if (_clienteTelefonoCache != null) return _clienteTelefonoCache;

    final snapshot = await FirebaseFirestore.instance
        .collection('clientes')
        .where('nombreCompleto', isEqualTo: nombreCliente)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    _clienteTelefonoCache = snapshot.docs.first.data()['telefono'];

    return _clienteTelefonoCache;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.pedido.data() as Map<String, dynamic>;
    final List productos = data['productos'] ?? [];
    final cliente = data['cliente'] ?? '';
    final numPedido = data['numero_pedido'] ?? [];
    final formPago = data['forma_pago'] ?? '';
    late final String fecha;

    final fechaData = data['fecha'];
    if (fechaData is Timestamp) {
      fecha = fechaData.toDate().toString().split(' ')[0];
    } else if (fechaData is String) {
      fecha = DateTime.tryParse(fechaData)?.toString().split(' ')[0] ?? '';
    } else {
      fecha = 'Sin fecha';
    }
    final observacion = data['observacion'] ?? '';
    final valorTotal = data['valor_total'] ?? 0;

    const formasPago = {
      'entrega': 'Pago por entrega',
      'bancario': 'Pago bancario',
      'cuotas': 'Cuotas',
      'fianza': 'Fianza / Credito',
    };

    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Resumen del Pedido"),
        actions: _userRole == 'admin'
            ? [
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: "Editar Pedido",
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditPedidos(pedido: widget.pedido),
                      ),
                    );
                    setState(() {});
                  },
                ),
              ]
            : [],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 25,
                ),
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Text(
                      "N° pedido: $numPedido",
                      style: const TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Cliente: $cliente",
                      style: const TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 15),
                    Text("Forma de pago: ${formasPago[formPago]}"),
                    const SizedBox(height: 15),
                    Text("Fecha: $fecha"),
                    const SizedBox(height: 15),
                    const Text(
                      "Observación:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(observacion),
                    _buildInfoDeuda(),
                    const Divider(height: 10),
                    const Text(
                      "Detalle del Pedido",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: productos.length,
                      itemBuilder: (context, index) {
                        final producto = productos[index];
                        return Card(
                          child: ListTile(
                            title: Text(producto['nombre'] ?? ''),
                            subtitle: Text(
                              "Cantidad: ${producto['cantidad']}  |  Precio: \$${producto['precio']}",
                            ),
                            trailing: Text("Total: \$${producto['total']}"),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        "Total General: \$${valorTotal.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 175),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                tooltip: "Compartir documento",
                heroTag: "fab1",
                onPressed: () {
                  _generarYCompartirPDF(
                    widget.pedido.data() as Map<String, dynamic>,
                  );
                },
                child: const Icon(Icons.share_sharp),
              ),
              SizedBox(width: 16),
              FloatingActionButton(
                tooltip: "Imprimir pedido",
                heroTag: "fab2",
                onPressed: () {
                  _showReceiptPreview(data);
                },
                child: const Icon(Icons.local_print_shop_rounded),
              ),
              SizedBox(width: 16),
              FloatingActionButton(
                tooltip: "Compartir pedido directo",
                heroTag: "fab3",
                onPressed: () {
                  _enviarPedidoPorWhatsapp(
                    widget.pedido.data() as Map<String, dynamic>,
                  );
                },
                child: const Icon(Icons.switch_access_shortcut_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptPreview(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Vista de Impresión"),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: _buildReceiptLayout(data),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text("Imprimir"),
              onPressed: () => _printPedido(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReceiptLayout(Map<String, dynamic> data) {
    final productos = data['productos'] as List<dynamic>? ?? [];
    final cliente = data['cliente'] ?? '';
    late final String fecha;

    final fechaData = data['fecha'];
    if (fechaData is Timestamp) {
      fecha = fechaData.toDate().toString().split(' ')[0];
    } else if (fechaData is String) {
      fecha = DateTime.tryParse(fechaData)?.toString().split(' ')[0] ?? '';
    } else {
      fecha = 'Sin fecha';
    }
    final numPedido = data['numero_pedido'] ?? '';
    final observacion = data['observacion'] ?? '';
    final valorTotal = data['valor_total'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Recibo de Pedido N° ${(numPedido)}",
          style: TextStyle(fontSize: 22),
        ),
        Text("Cliente: $cliente"),
        Text("Fecha: $fecha"),
        const SizedBox(height: 8),
        const Text("Observación:"),
        Text(observacion),
        const Divider(),
        const Text("Detalle:", style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(flex: 2, child: Text("Producto")),
            Expanded(
              flex: 1,
              child: Text("Cantidad", textAlign: TextAlign.center),
            ),
            Expanded(
              flex: 2,
              child: Text("Valor c/u", textAlign: TextAlign.end),
            ),
            Expanded(flex: 2, child: Text("Total", textAlign: TextAlign.end)),
          ],
        ),
        ...productos.map((prod) {
          return Row(
            children: [
              Expanded(flex: 2, child: Text("${prod['nombre']}")),
              Expanded(
                flex: 1,
                child: Text(
                  "×${prod['cantidad']}",
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("\$${prod['precio']}", textAlign: TextAlign.end),
              ),
              Expanded(
                flex: 2,
                child: Text("\$${prod['total']}", textAlign: TextAlign.end),
              ),
            ],
          );
        }),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Text(
                "Total: ",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                "\$${(valorTotal).toStringAsFixed(2)}",
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _printPedido(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final device = await FlutterBluetoothPrinter.selectDevice(context);
    if (device != null) {
      await _receiptController?.print(address: device.address);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se seleccionó impresora')),
      );
    }
  }

  Widget _buildInfoDeuda() {
    if (_cargandoDeuda) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(),
      );
    }

    if (_deudaActual == null) return const SizedBox();

    final data = _deudaActual!.data() as Map<String, dynamic>;

    final tipo = data['tipo'];
    final total = data['total'];
    final pagado = data['pagado'];
    final saldo = data['saldo'];
    final historial = List.from(data['historial'] ?? []);

    DateTime? ultimaFecha;

    if (historial.isNotEmpty) {
      final last = historial.last['fecha'] as Timestamp;
      ultimaFecha = last.toDate();
    }

    return Column(
      children: [
        SizedBox(height: 10),
        Divider(height: 10),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Información de deuda',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 6),

                if (tipo == 'cuotas') ...[
                  Text(
                    'Cuotas: ${historial.length} / ${data['config']?['cuotas']}',
                  ),
                ],

                if (tipo == 'fianza') ...[
                  Text('Pagado: \$${pagado.toInt()} / \$${total.toInt()}'),
                  Text('Saldo: \$${saldo.toInt()}'),
                ],

                if (ultimaFecha != null)
                  Text(
                    'Último pago: ${ultimaFecha.toString().split(' ')[0]}',
                    style: const TextStyle(fontSize: 12),
                  ),

                if (_otrasDeudas.isNotEmpty)
                  TextButton(
                    onPressed: _mostrarSelectorDeudas,
                    child: Text('Otras deudas (${_otrasDeudas.length})'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarSelectorDeudas() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: _otrasDeudas.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return ListTile(
                title: Text('Pedido #${data['numero_pedido']}'),
                subtitle: Text('Saldo: ${data['saldo']}'),
                trailing: const Icon(Icons.chevron_right),

                onTap: () {
                  setState(() {
                    _deudaActual = doc;
                  });

                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
