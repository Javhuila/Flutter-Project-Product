import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Pedidos/pedidos.dart';

import '../Utils/Constans/app_constants.dart';
import 'config_pago.dart';

class EditPedidos extends StatefulWidget {
  final DocumentSnapshot pedido;
  const EditPedidos({super.key, required this.pedido});

  @override
  State<EditPedidos> createState() => _EditPedidosState();
}

class _EditPedidosState extends State<EditPedidos> {
  final _formKey = GlobalKey<FormState>();
  final _formKeySecond = GlobalKey<FormState>();

  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _observacionController = TextEditingController();
  final FocusNode _cantidadFocusNode = FocusNode();
  final FocusNode _otroFocusNode = FocusNode();
  Map<String, dynamic> _preciosEspecialesCliente = {};

  List<Map<String, dynamic>> _productosAgregados = [];
  List<Map<String, dynamic>> _productosStore = [];

  String? _selectedProduct;
  bool _isClienteEspecial = false;
  bool _isLoadingProducts = true;
  String _clienteNombre = '';
  String _fechaPedido = '';

  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;

  String _formaPagoActual = 'entrega';
  Map<String, dynamic>? _pagoActual;

  /// Pago bancario
  String? _entidadBancaria;
  String? _entidadBancariaOtro;

  @override
  void initState() {
    super.initState();
    _inicializarPedido();
    _loadCategories();
  }

  Future<void> _inicializarPedido() async {
    final data = widget.pedido.data() as Map<String, dynamic>;
    _productosAgregados = List<Map<String, dynamic>>.from(
      data['productos'] ?? [],
    );
    _observacionController.text = data['observacion'] ?? '';
    _isClienteEspecial = data['tipo'] == 'Especial';
    _clienteNombre = data['cliente'] ?? '';
    _formaPagoActual = data['forma_pago'] ?? 'entrega';
    _pagoActual = data['pago'];
    final pagoData = data['pago'];

    if (pagoData is Map) {
      final extra = pagoData['extra'];

      if (extra is Map) {
        _entidadBancaria = extra['entidad']?.toString();
        _entidadBancariaOtro = extra['otro']?.toString();
      }
    }
    final fecha = data['fecha'];
    if (fecha is Timestamp) {
      final date = fecha.toDate();
      _fechaPedido =
          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } else {
      _fechaPedido = fecha?.toString() ?? '';
    }

    if (_isClienteEspecial) {
      final clienteSnap = await FirebaseFirestore.instance
          .collection('clientes')
          // cambio a nombreCompleto -> nombre
          .where('nombreCompleto', isEqualTo: _clienteNombre)
          .limit(1)
          .get();
      if (clienteSnap.docs.isNotEmpty) {
        final clienteData = clienteSnap.docs.first.data();
        _preciosEspecialesCliente = Map<String, dynamic>.from(
          clienteData['precio_personalizado'] ?? {},
        );
      }
    }

    // await _loadProductosDesdeFirestore();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _cantidadFocusNode.dispose();
    _otroFocusNode.dispose();
    super.dispose();
  }

  void _agregarProducto() {
    _cantidadFocusNode.unfocus();
    if (_formKeySecond.currentState!.validate() && _selectedProduct != null) {
      final producto = _productosStore.firstWhere(
        (p) => p['nombre'] == _selectedProduct,
      );
      final precio = producto['precio'] as num;
      final cantidad = int.tryParse(_cantidadController.text) ?? 0;
      final total = precio * cantidad;
      final id = producto['id'];

      setState(() {
        _productosAgregados.add({
          'id': id,
          'nombre': producto['nombre'],
          'precio': precio,
          'cantidad': cantidad,
          'total': total,
        });
        _cantidadController.clear();
        // NO resetear la categoría seleccionada para que siga habilitado el dropdown de productos
        //_selectedCategoryId = null;

        // Reset solo el producto seleccionado para que el dropdown resetee su selección
        _selectedProduct = null;

        // NO vacíes la lista de productos aquí, solo cambia el estado para refrescar
        //_productosStore = [];

        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadProductosDesdeFirestore(String categoriaNombre) async {
    setState(() {
      _isLoadingProducts = true;
      _productosStore = [];
      _selectedProduct = null;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String adminId = currentUser.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('productos')
        .where('adminId', isEqualTo: adminId)
        .where('categoria', isEqualTo: categoriaNombre)
        .orderBy('nombre')
        .get();

    final nuevosProductos = snapshot.docs.map((doc) {
      final data = doc.data();
      final productoId = doc.id;
      final precioBase = (data['precio'] is num)
          ? (data['precio'] as num).toDouble()
          : double.tryParse(data['precio'].toString()) ?? 0;
      double precioFinal = precioBase;

      if (_isClienteEspecial &&
          _preciosEspecialesCliente.containsKey(productoId)) {
        precioFinal = (_preciosEspecialesCliente[productoId] as num).toDouble();
      }

      return {
        'id': productoId,
        'nombre': data['nombre'] ?? '',
        'precio_base': precioBase,
        'precio': precioFinal,
        'contenido': data['contenido'] ?? '',
      };
    }).toList();

    setState(() {
      _productosStore = nuevosProductos;
      _isLoadingProducts = false;

      if (_isClienteEspecial) {
        _productosAgregados = _productosAgregados.map((item) {
          final match = nuevosProductos.firstWhere(
            (p) => p['id'] == item['id'],
            orElse: () => {},
          );
          if (match.isNotEmpty) {
            item['precio'] = match['precio'];
            item['total'] = (item['precio'] as num) * (item['cantidad'] as int);
          }
          return item;
        }).toList();
      }
    });
  }

  Future<void> _loadCategories() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String adminId = currentUser.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('categorias')
        .where('adminId', isEqualTo: adminId)
        .get();

    setState(() {
      _categories = snapshot.docs.map((docx) {
        return {
          'id': docx.id,
          'nombre': docx['nombre'],
          'imagen': docx['imagen'],
        };
      }).toList();
      _isLoadingCategories = false;
    });
  }

  double _calcularTotalProducto() {
    return _productosAgregados.fold<double>(
      0.0,
      (acumulado, item) => acumulado + (item['total'] as num).toDouble(),
    );
  }

  void _eliminarProducto(int index) {
    setState(() {
      _productosAgregados.removeAt(index);
    });
  }

  Future<void> _guardarPedido() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_productosAgregados.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Debe agregar al menos un producto')),
      );
      return;
    }

    try {
      final originalData = widget.pedido.data() as Map<String, dynamic>;

      final formaAnterior = originalData['forma_pago']?.toString() ?? 'entrega';
      final pagoAnterior = originalData['pago'] is Map
          ? Map<String, dynamic>.from(originalData['pago'])
          : null;

      final originalFecha = originalData['fecha'];
      final originalAdminId = originalData['adminId'];

      final creadorId = originalData['creado_por'];
      final creadorNombre = originalData['creado_por_nombre'];

      final nuevoTotal = _calcularTotalProducto();
      Map<String, dynamic>? pagoActualizado = _pagoActual;

      final currentUser = FirebaseAuth.instance.currentUser;

      String editorId = currentUser?.uid ?? '';
      String editorNombre = 'Anónimo';
      String? adminId = originalAdminId;
      String? rolUsuario;

      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();

          if (data != null) {
            editorNombre = data['name'] ?? editorNombre;
            rolUsuario = data['role'];

            if (data['adminId'] != null && originalAdminId == null) {
              adminId = data['adminId'];
            }
          }
        }
      }

      if (rolUsuario == 'asistente') {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No tienes permisos para editar pedidos'),
          ),
        );
        return;
      }

      Map<String, dynamic>? extraPago;

      if (_formaPagoActual == 'entrega') {
        extraPago = {'metodo': 'efectivo'};
      }

      if (_formaPagoActual == 'bancario') {
        extraPago = {
          'entidad': _entidadBancaria == 'otro' ? 'otro' : _entidadBancaria,
          'otro': _entidadBancaria == 'otro' ? _entidadBancariaOtro : null,
        };
      }

      if (_formaPagoActual == 'cuotas' && _pagoActual != null) {
        final cantidadCuotas = (_pagoActual!['cuotas'] ?? 0) as int;

        final pagado = (_pagoActual!['pagado'] ?? 0).toDouble();

        pagoActualizado = {
          ..._pagoActual!,
          'tipo': 'cuotas',
          'cuotas': cantidadCuotas,
          'valor_cuota': cantidadCuotas > 0 ? nuevoTotal / cantidadCuotas : 0.0,
          'pagado': pagado,
        };
      }

      if (_formaPagoActual == 'fianza' && _pagoActual != null) {
        final pagado = (_pagoActual!['pagado'] ?? 0).toDouble();

        pagoActualizado = {..._pagoActual!, 'tipo': 'fianza', 'pagado': pagado};
      }

      if (extraPago != null) {
        pagoActualizado = {...?pagoActualizado, 'extra': extraPago};
      }

      final updatedData = {
        'productos': _productosAgregados,
        'productos_contabilizado': _productosAgregados.length,
        'observacion': _observacionController.text.trim(),
        'cantidad_total': _productosAgregados.fold(
          0,
          (add, p) => add + (p['cantidad'] as int),
        ),
        'valor_total': nuevoTotal,
        'forma_pago': _formaPagoActual,
        'pago': pagoActualizado,
        'fecha': originalFecha,
        'creado_por': creadorId,
        'creado_por_nombre': creadorNombre,
        'editado_por': editorId,
        'editado_por_nombre': editorNombre,
        'editado_en': Timestamp.now(),
        if (adminId != null) 'adminId': adminId,
      };

      final pedidoRef = FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedido.id);

      await pedidoRef.update(updatedData);

      await _procesarDeudaAlEditarPedido(
        formaAnterior,
        _formaPagoActual,
        pagoAnterior,
        nuevoTotal,
        pedidoRef.id,
      );

      messenger.showSnackBar(
        const SnackBar(content: Text('Pedido actualizado correctamente')),
      );

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Pedidos()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error editando pedido: $e');

      messenger.showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  Future<void> _procesarDeudaAlEditarPedido(
    String? formaAnterior,
    String formaNueva,
    Map<String, dynamic>? pagoAnterior,
    double nuevoTotal,
    String pedidoId,
  ) async {
    final fs = FirebaseFirestore.instance;

    final esCreditoAntes =
        formaAnterior == 'cuotas' || formaAnterior == 'fianza';

    final esCreditoAhora = formaNueva == 'cuotas' || formaNueva == 'fianza';

    final deudaId = pagoAnterior?['referencia_pago']?.toString();

    // ================= CONTADO → CRÉDITO =================

    if (!esCreditoAntes && esCreditoAhora) {
      await _crearNuevaDeuda(pedidoId, nuevoTotal, formaNueva);
      return;
    }

    // ================= CRÉDITO → CONTADO =================

    if (esCreditoAntes && !esCreditoAhora) {
      if (deudaId == null || deudaId.isEmpty) {
        debugPrint(
          'Advertencia: el pedido tenía forma de pago '
          '$formaAnterior, pero no tiene referencia de deuda.',
        );
        return;
      }

      final deudaRef = fs.collection('deudas').doc(deudaId);
      final deudaSnapshot = await deudaRef.get();

      if (!deudaSnapshot.exists) {
        debugPrint(
          'Advertencia: no existe la deuda $deudaId '
          'asociada al pedido $pedidoId.',
        );
        return;
      }

      await deudaRef.update({
        'estado': 'cancelado',
        'actualizado_en': Timestamp.now(),
      });
      return;
    }

    // ================= CRÉDITO → CRÉDITO =================

    if (esCreditoAntes && esCreditoAhora) {
      if (deudaId == null || deudaId.isEmpty) {
        debugPrint(
          'Advertencia: el pedido continúa como crédito '
          'pero no tiene referencia de deuda.',
        );

        return;
      }

      final deudaRef = fs.collection('deudas').doc(deudaId);
      final deudaSnapshot = await deudaRef.get();

      if (!deudaSnapshot.exists) {
        debugPrint(
          'Advertencia: la deuda $deudaId no existe '
          'para el pedido $pedidoId.',
        );

        return;
      }

      final data = deudaSnapshot.data()!;
      final pagado = (data['pagado'] ?? 0).toDouble();

      if (nuevoTotal < pagado) {
        throw Exception(
          'El nuevo total (\$${nuevoTotal.toStringAsFixed(2)}) '
          'no puede ser menor al valor ya pagado '
          '(\$${pagado.toStringAsFixed(2)}).',
        );
      }

      final nuevoSaldo = nuevoTotal - pagado;
      final nuevoEstado = nuevoSaldo <= 0 ? 'pagado' : 'activo';

      await deudaRef.update({
        'tipo': formaNueva,
        'total': nuevoTotal,
        'saldo': nuevoSaldo,
        'estado': nuevoEstado,
        'actualizado_en': Timestamp.now(),
      });

      // Mantener sincronizado el resumen del pedido.
      await fs.collection('pedidos').doc(pedidoId).update({
        'pago.resumen.total': nuevoTotal,
        'pago.resumen.saldo': nuevoSaldo,
        'pago.resumen.pagado': pagado,
      });
      return;
    }
  }

  Future<void> _crearNuevaDeuda(
    String pedidoId,
    double total,
    String formaPago,
  ) async {
    final fs = FirebaseFirestore.instance;

    final deudaRef = fs.collection('deudas').doc();

    final deudaData = {
      'pedido_id': pedidoId,
      'tipo': formaPago,
      'total': total,
      'pagado': 0.0,
      'saldo': total,
      'estado': 'activo',
      'historial': [],
      'creado_en': Timestamp.now(),
      'actualizado_en': Timestamp.now(),
    };

    await deudaRef.set(deudaData);

    // actualizar pedido
    await fs.collection('pedidos').doc(pedidoId).update({
      'pago': {
        'tipo': formaPago,
        'referencia_pago': deudaRef.id,
        'resumen': {'total': total, 'pagado': 0, 'saldo': total},
      },
    });
  }

  Future<void> _seleccionarFormaPago(String? nuevaFormaPago) async {
    if (nuevaFormaPago == null) return;

    if (nuevaFormaPago == 'cuotas' || nuevaFormaPago == 'fianza') {
      final configuracion = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfigPago(
            tipoPago: nuevaFormaPago,
            totalPedido: _calcularTotalProducto(),
          ),
        ),
      );

      if (configuracion == null || !mounted) return;

      setState(() {
        _formaPagoActual = nuevaFormaPago;
        _pagoActual = configuracion;
      });

      return;
    }

    setState(() {
      _formaPagoActual = nuevaFormaPago;

      if (nuevaFormaPago == 'entrega') {
        _pagoActual = {'tipo': 'entrega', 'pagado': 0.0};
      } else if (nuevaFormaPago == 'bancario') {
        _pagoActual = {'tipo': 'bancario', 'pagado': 0.0};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editando pedido")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
          child: Column(
            children: [
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Cliente:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        _clienteNombre,
                        softWrap: true,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                mainAxisSize: MainAxisSize.max,
                children: [
                  const Text(
                    "Fecha:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_fechaPedido),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 5),
              const SizedBox(height: 15),
              const Center(child: Text("Editar Productos")),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Form(
                      key: _formKeySecond,
                      child: Column(
                        children: [
                          _isLoadingCategories
                              ? FutureBuilder(
                                  future: Future.delayed(
                                    const Duration(seconds: 3),
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState !=
                                        ConnectionState.done) {
                                      return const CircularProgressIndicator(); // Cargando...
                                    } else if (_categories.isEmpty) {
                                      return const Text(
                                        'No hay categorías disponibles.',
                                      );
                                    } else {
                                      // Ya cargaron las categorías, mostrar el Dropdown
                                      return DropdownButtonFormField<String>(
                                        itemHeight: 80,
                                        isExpanded: true,
                                        initialValue: _selectedCategoryId,
                                        decoration: const InputDecoration(
                                          labelText: 'Categoría',
                                        ),
                                        items: _categories.map((category) {
                                          return DropdownMenuItem<String>(
                                            value: category['id'],
                                            child: Row(
                                              children: [
                                                Image.network(
                                                  category['imagen'],
                                                  width: 24,
                                                  height: 24,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => const Icon(
                                                        Icons.broken_image,
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(category['nombre']),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newCategoryId) {
                                          final category = _categories
                                              .firstWhere(
                                                (cat) =>
                                                    cat['id'] == newCategoryId,
                                              );
                                          setState(() {
                                            _selectedCategoryId = newCategoryId;
                                            _selectedProduct = null;
                                          });
                                          _loadProductosDesdeFirestore(
                                            category['nombre'],
                                          );
                                        },
                                        validator: (value) => value == null
                                            ? 'Selecciona una categoría'
                                            : null,
                                      );
                                    }
                                  },
                                )
                              : DropdownButtonFormField<String>(
                                  initialValue: _selectedCategoryId,
                                  itemHeight: 100,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Categoría',
                                  ),
                                  items: _categories.map((category) {
                                    return DropdownMenuItem<String>(
                                      value: category['id'],
                                      child: Row(
                                        children: [
                                          Image.network(
                                            category['imagen'],
                                            width: 24,
                                            height: 24,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(Icons.broken_image),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(category['nombre']),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newCategoryId) {
                                    final category = _categories.firstWhere(
                                      (cat) => cat['id'] == newCategoryId,
                                    );
                                    setState(() {
                                      _selectedCategoryId = newCategoryId;
                                      _selectedProduct = null;
                                    });
                                    _loadProductosDesdeFirestore(
                                      category['nombre'],
                                    );
                                  },
                                  validator: (value) => value == null
                                      ? 'Selecciona una categoría'
                                      : null,
                                ),
                          const SizedBox(height: 20),
                          _isLoadingProducts
                              ? FutureBuilder(
                                  future: Future.delayed(
                                    const Duration(seconds: 7),
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState !=
                                        ConnectionState.done) {
                                      return const CircularProgressIndicator(); // Esperando...
                                    } else if (_productosStore.isEmpty) {
                                      return const Text(
                                        "Por favor selecciona una categoría para ver productos",
                                      );
                                    } else {
                                      return DropdownButtonFormField<String>(
                                        itemHeight: 80,
                                        isExpanded: true,
                                        initialValue: _selectedProduct,
                                        items: _productosStore.map((product) {
                                          return DropdownMenuItem<String>(
                                            value: product['id'],
                                            child: Text(
                                              "${product['nombre']} - ${product['contenido']} - (\$${product['precio']})",
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newValue) => setState(() {
                                          _selectedProduct = newValue;
                                        }),
                                        decoration: const InputDecoration(
                                          labelText: "Producto",
                                        ),
                                        validator: (value) => value == null
                                            ? 'Selecciona un producto'
                                            : null,
                                      );
                                    }
                                  },
                                )
                              : _productosStore.isEmpty
                              ? const Text(
                                  "No hay productos para esta categoría.",
                                )
                              : DropdownButtonFormField<String>(
                                  initialValue: _selectedProduct,
                                  itemHeight: 100,
                                  isExpanded: true,
                                  items: _productosStore.map((producto) {
                                    return DropdownMenuItem<String>(
                                      value: producto['nombre'],
                                      child: Text(
                                        "${producto['nombre']} - ${producto['contenido']} - (\$${producto['precio']})",
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedProduct = newValue;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    labelText: "Producto",
                                  ),
                                  validator: (value) => value == null
                                      ? 'Selecciona un producto'
                                      : null,
                                ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _cantidadController,
                            focusNode: _cantidadFocusNode,
                            decoration: const InputDecoration(
                              suffixIcon: Icon(Icons.onetwothree_rounded),
                              hintText: "Digita una cantidad",
                              labelText: "Cantidad",
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Este campo es obligatorio!!!';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton(
                            onPressed: _agregarProducto,
                            child: Text("Agregar"),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              border: TableBorder.all(),
                              columns: const [
                                DataColumn(label: Text("Cantidad")),
                                DataColumn(label: Text("Nombre")),
                                DataColumn(label: Text("Precio Regular")),
                                DataColumn(label: Text("Total")),
                                DataColumn(label: Text("Eliminar")),
                              ],
                              rows: _productosAgregados.asMap().entries.map((
                                entry,
                              ) {
                                final index = entry.key;
                                final item = entry.value;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(item['cantidad'].toString())),
                                    DataCell(Text(item['nombre'])),
                                    _isClienteEspecial
                                        ? DataCell(
                                            TextFormField(
                                              key: ValueKey(item),
                                              initialValue: item['precio']
                                                  .toString(),
                                              keyboardType:
                                                  TextInputType.number,
                                              onChanged: (val) {
                                                final nuevo =
                                                    num.tryParse(val) ??
                                                    item['precio'];
                                                setState(() {
                                                  item['precio'] = nuevo;
                                                  item['total'] =
                                                      nuevo * item['cantidad'];
                                                });
                                              },
                                              decoration: const InputDecoration(
                                                suffixIcon: Icon(
                                                  Icons
                                                      .drive_file_rename_outline_outlined,
                                                ),
                                              ),
                                            ),
                                          )
                                        : DataCell(
                                            Text(item['precio'].toString()),
                                          ),
                                    DataCell(Text(item['total'].toString())),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _eliminarProducto(index),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              "El total es de: \$${AppConstants.formatearMoneda(_calcularTotalProducto())}",
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: _formaPagoActual,
                      decoration: const InputDecoration(
                        labelText: 'Forma de pago',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'entrega',
                          child: Text('Pago por entrega'),
                        ),
                        DropdownMenuItem(
                          value: 'bancario',
                          child: Text('Pago bancario'),
                        ),
                        DropdownMenuItem(
                          value: 'cuotas',
                          child: Text('Cuotas'),
                        ),
                        DropdownMenuItem(
                          value: 'fianza',
                          child: Text('Fianza / Crédito'),
                        ),
                      ],
                      onChanged: _seleccionarFormaPago,
                    ),
                    if (_formaPagoActual == 'entrega')
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Método de pago: Efectivo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                    // ------------------------
                    // BANCARIO
                    // ------------------------
                    if (_formaPagoActual == 'bancario') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _entidadBancaria,
                        decoration: const InputDecoration(
                          labelText: 'Entidad bancaria',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'nequi',
                            child: Text('Nequi'),
                          ),
                          DropdownMenuItem(
                            value: 'bancolombia',
                            child: Text('BanColombia'),
                          ),
                          DropdownMenuItem(
                            value: 'davivienda',
                            child: Text('Davivienda'),
                          ),
                          DropdownMenuItem(value: 'otro', child: Text('Otro')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _entidadBancaria = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Seleccione una entidad bancaria';
                          }
                          return null;
                        },
                      ),
                      if (_entidadBancaria == 'otro')
                        TextFormField(
                          focusNode: _otroFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de entidad',
                          ),
                          onChanged: (value) {
                            _entidadBancariaOtro = value;
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Este campo es obligatorio!!!';
                            }
                            return null;
                          },
                        ),
                    ],
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: _guardarPedido,
                      child: Text("Guardar"),
                    ),
                    const SizedBox(height: 145),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
