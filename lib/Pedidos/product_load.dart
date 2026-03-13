import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Pedidos/config_pago.dart';
import 'package:flutter_project_product/Pedidos/pedidos.dart';

class ProductLoad extends StatefulWidget {
  final String clienteNombre;
  final String fechaPedido;
  final String tipoCliente;
  const ProductLoad({
    super.key,
    required this.clienteNombre,
    required this.fechaPedido,
    required this.tipoCliente,
  });

  @override
  State<ProductLoad> createState() => _ProductLoadState();
}

class _ProductLoadState extends State<ProductLoad> {
  final _formKey = GlobalKey<FormState>();
  final _formKeySecond = GlobalKey<FormState>();

  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _observacionController = TextEditingController();

  String? _selectedproductList;
  List<Map<String, dynamic>> _productosStore = [];
  bool _isLoadingProducts = true;

  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCat = true;

  final List<Map<String, dynamic>> _productosAgregados = [];
  Map<String, dynamic> _preciosEspecialesCliente = {};

  String _formaPago = 'entrega';

  /// Configuración de pagos especiales (cuotas / fianza)
  Map<String, dynamic>? _pagoConfig;

  /// Pago bancario
  String? _entidadBancaria;
  String? _entidadBancariaOtro;

  @override
  void initState() {
    super.initState();
    _prepararDatos();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  Future<void> _prepararDatos() async {
    await _inicializarDatos(); // Espera a que cargue los precios personalizados
    await _loadCategories(); // Luego carga las categorías
  }

  Future<void> _inicializarDatos() async {
    if (widget.tipoCliente == 'Especial') {
      final clienteSnapshot = await FirebaseFirestore.instance
          .collection('clientes')
          .get();

      for (final doc in clienteSnapshot.docs) {
        final data = doc.data();
        final nombre = (data['nombre'] ?? '').toString().trim();
        final apellido = (data['apellido'] ?? '').toString().trim();
        final nombreCompleto = '$nombre $apellido';

        if (nombreCompleto.toLowerCase() ==
            widget.clienteNombre.toLowerCase().trim()) {
          setState(() {
            _preciosEspecialesCliente = Map<String, dynamic>.from(
              data['precio_personalizado'] ?? {},
            );
          });
          break; // Cliente encontrado, salimos del loop
        }
      }
    }
  }

  Future<void> _loadProductosDesdeFirestore(String categoriaNombre) async {
    setState(() {
      _isLoadingProducts = true;
      _productosStore = [];
      _selectedproductList = null;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoadingProducts = false;
      });
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    String adminId = currentUser.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('productos')
        .where('adminId', isEqualTo: adminId)
        .where('categoria', isEqualTo: categoriaNombre)
        .orderBy('nombre')
        .get();

    setState(() {
      _productosStore = snapshot.docs.map((doc) {
        final data = doc.data();
        final productoId = doc.id;

        // Usa el precio especial si el cliente es Especial y existe para ese producto
        double precioFinal;
        if (widget.tipoCliente == 'Especial' &&
            _preciosEspecialesCliente.containsKey(productoId)) {
          precioFinal = (_preciosEspecialesCliente[productoId] as num)
              .toDouble();
        } else {
          precioFinal = (data['precio'] is num)
              ? (data['precio'] as num).toDouble()
              : double.tryParse(data['precio']?.toString() ?? '0') ?? 0;
        }

        return {
          'id': productoId,
          'nombre': data['nombre'] ?? '',
          'contenido': data['contenido'] ?? '',
          'precio': precioFinal,
        };
      }).toList();
      _isLoadingProducts = false;
    });
  }

  Future<void> _loadCategories() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Obtener adminId
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    String adminId = currentUser.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('categorias')
        .where('adminId', isEqualTo: adminId)
        .orderBy('nombre')
        .get();

    setState(() {
      _categories = snapshot.docs
          .map(
            (d) => {
              'id': d.id,
              'nombre': d['nombre'],
              'imagen': d['imagen'],
              'docRef': d.reference,
            },
          )
          .toList();
      _isLoadingCat = false;
    });
  }

  Future<int> _obtenerSiguienteNumeroPedido() async {
    final counterRef = FirebaseFirestore.instance
        .collection('contadores')
        .doc('pedidos');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      if (!snapshot.exists) {
        transaction.set(counterRef, {'valor': 1});
        return 1;
      }

      final currentValue = snapshot.data()!['valor'] as int;
      final newValue = currentValue + 1;
      transaction.update(counterRef, {'valor': newValue});
      return newValue;
    });
  }

  void _agregarProducto() {
    if (_formKeySecond.currentState!.validate() &&
        _selectedproductList != null) {
      final cantidad = int.tryParse(_cantidadController.text);
      final producto = _productosStore.firstWhere(
        (p) => p['id'] == _selectedproductList,
      );
      final nombre = producto['nombre'];
      final precio = producto['precio'];
      final id = producto['id'];

      if (cantidad != null && cantidad > 0) {
        setState(() {
          _productosAgregados.add({
            'id': id,
            'nombre': nombre,
            'precio': precio,
            'cantidad': cantidad,
            'total': precio * cantidad,
          });
          _cantidadController.clear();
          // NO resetear la categoría seleccionada para que siga habilitado el dropdown de productos
          //_selectedCategoryId = null;

          // Reset solo el producto seleccionado para que el dropdown resetee su selección
          _selectedproductList = null;

          // NO vacíes la lista de productos aquí, solo cambia el estado para refrescar
          //_productosStore = [];

          _isLoadingProducts = false;
        });
      }
    }
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

  Future<void> _mostrarDialogoCarga() async {
    showDialog(
      context: context,
      barrierDismissible: false, // No permitir cerrar tocando fuera
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Flexible(child: Text("Generando pedido...", softWrap: true)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _guardarPedido() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_productosAgregados.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Debe agregar al menos un producto")),
      );
      return;
    }

    Map<String, dynamic>? extraPago;

    if (_formaPago == 'entrega') {
      extraPago = {'metodo': 'efectivo'};
    }

    if (_formaPago == 'bancario') {
      extraPago = {
        'entidad': _entidadBancaria == 'otro' ? 'otro' : _entidadBancaria,
        'otro': _entidadBancaria == 'otro' ? _entidadBancariaOtro : null,
      };
    }

    if ((_formaPago == 'cuotas' || _formaPago == 'fianza') &&
        _pagoConfig == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Debe configurar el pago primero')),
      );
      return;
    }

    DateTime parseFecha(String fechaStr) {
      final partes = fechaStr.split('/');
      final day = int.parse(partes[0]);
      final month = int.parse(partes[1]);
      final year = int.parse(partes[2]);
      return DateTime(year, month, day);
    }

    final numeroPedido = await _obtenerSiguienteNumeroPedido();

    // Obtener UID del usuario actual
    final currentUser = FirebaseAuth.instance.currentUser;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    String adminId = currentUser.uid;
    String nombreUsuario = 'Anónimo';

    if (userDoc.exists) {
      final userData = userDoc.data();
      if (userData != null) {
        nombreUsuario =
            userData['name'] ??
            'Anónimo'; // Obtener nombre del usuario o usar "Anónimo" si no se encuentra
      }
    }

    if (userDoc.exists && userDoc.data()?['role'] == 'asistente') {
      adminId = userDoc.data()?['adminId'] ?? currentUser.uid;
    }

    // Puedes guardarlo en Firebase aquí:
    final pedidosRef = FirebaseFirestore.instance.collection('pedidos').doc();

    final batch = FirebaseFirestore.instance.batch();

    String? pagoPendienteId;

    final pagadoInicial = (_pagoConfig?['pagado'] ?? 0).toDouble();

    if (_formaPago == 'cuotas' || _formaPago == 'fianza') {
      final deudaRef = FirebaseFirestore.instance.collection('deudas').doc();

      pagoPendienteId = deudaRef.id;

      final deudaData = {
        'pedido_id': pedidosRef.id,
        'numero_pedido': numeroPedido,

        'cliente': {'nombre': widget.clienteNombre, 'tipo': widget.tipoCliente},

        'tipo': _formaPago,

        'total': _calcularTotalProducto(),
        'pagado': pagadoInicial,
        'saldo': _calcularTotalProducto() - pagadoInicial,

        'estado': pagadoInicial >= _calcularTotalProducto()
            ? 'pagado'
            : 'activo',

        'historial': pagadoInicial > 0
            ? [
                {
                  'fecha': Timestamp.now(),
                  'monto': pagadoInicial,
                  'tipo': _formaPago == 'cuotas' ? 'cuota' : 'aporte',
                },
              ]
            : [],

        'config': _pagoConfig,

        'creado_en': Timestamp.now(),
        'actualizado_en': Timestamp.now(),
      };

      batch.set(deudaRef, deudaData);
    }

    final pedidoCompleto = {
      'numero_pedido': numeroPedido,
      'cliente': widget.clienteNombre,
      'tipo': widget.tipoCliente,
      'fecha': parseFecha(widget.fechaPedido),
      'observacion': _observacionController.text.trim(),
      'productos': _productosAgregados,
      'productos_contabilizado': _productosAgregados.length,
      'cantidad_total': _productosAgregados.fold(
        0,
        (addSum, p) => addSum + (p['cantidad'] as int),
      ),
      'valor_total': _calcularTotalProducto(),
      'forma_pago': _formaPago,
      'pago': {
        'tipo': _formaPago,
        'referencia_pago': pagoPendienteId,
        'resumen': (_formaPago == 'cuotas' || _formaPago == 'fianza')
            ? {
                'total': _calcularTotalProducto(),
                'pagado': pagadoInicial,
                'saldo': _calcularTotalProducto() - pagadoInicial,
              }
            : null,
        'extra': extraPago,
      },
      'creado_por': currentUser.uid,
      'creado_por_nombre': nombreUsuario,
      'adminId': adminId,
      'entregado': false,
    };

    batch.set(pedidosRef, pedidoCompleto);

    // await pedidosRef.set(pedidoCompleto);
    await batch.commit();

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text("Pedido guardado exitosamente")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Pedidos()),
      (Route<dynamic> route) => false,
    );

    setState(() {
      // _formaPago = null;
      _productosAgregados.clear();
      _observacionController.clear();
      _formaPago = 'entrega';
      _pagoConfig = null;
    });
  }

  // Map<String, dynamic> _construirPagoData() {
  //   switch (_formaPago) {
  //     case 'entrega':
  //       return {'tipo': 'entrega', 'metodo': 'efectivo'};

  //     case 'bancario':
  //       return {
  //         'tipo': 'bancario',
  //         'entidad': _entidadBancaria == 'otro'
  //             ? _entidadBancariaOtro
  //             : _entidadBancaria,
  //       };

  //     case 'cuotas':
  //     case 'fianza':
  //       return _pagoConfig!;

  //     default:
  //       return {};
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cargar Productos")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
          child: Column(
            children: [
              SizedBox(height: 15),
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
                        widget.clienteNombre,
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
                children: [
                  const Text(
                    "Tipo:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(widget.tipoCliente),
                ],
              ),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const Text(
                    "Fecha:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(widget.fechaPedido),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 5),
              const SizedBox(height: 15),
              const Center(child: Text("Agregar Productos")),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Form(
                      key: _formKeySecond,
                      child: Column(
                        children: [
                          _isLoadingCat
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
                                                CachedNetworkImage(
                                                  imageUrl:
                                                      category['imagen'] ?? '',
                                                  width: 24,
                                                  height: 24,
                                                  placeholder: (context, url) =>
                                                      const SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          const Icon(
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
                                            _selectedproductList = null;
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
                                          CachedNetworkImage(
                                            imageUrl: category['imagen'] ?? '',
                                            width: 24,
                                            height: 24,
                                            placeholder: (context, url) =>
                                                const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(
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
                                    final category = _categories.firstWhere(
                                      (cat) => cat['id'] == newCategoryId,
                                    );
                                    setState(() {
                                      _selectedCategoryId = newCategoryId;
                                      _selectedproductList = null;
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
                                        initialValue: _selectedproductList,
                                        items: _productosStore.map((product) {
                                          return DropdownMenuItem<String>(
                                            value: product['id'],
                                            child: Text(
                                              "${product['nombre']} - ${product['contenido']} - (\$${product['precio']})",
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newValue) => setState(() {
                                          _selectedproductList = newValue;
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
                                  itemHeight: 100,
                                  isExpanded: true,
                                  initialValue: _selectedproductList,
                                  items: _productosStore.map((product) {
                                    return DropdownMenuItem<String>(
                                      value: product['id'],
                                      child: Text(
                                        "${product['nombre']} - ${product['contenido']} - (\$${product['precio']})",
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) => setState(() {
                                    _selectedproductList = newValue;
                                  }),
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
                              columns: [
                                DataColumn(label: Text("Cantidad")),
                                DataColumn(label: Text("Nombre")),
                                DataColumn(label: Text("Precio Regular")),
                                DataColumn(label: Text("Total")),
                                DataColumn(label: Text("Eliminar")),
                              ],
                              rows: _productosAgregados.asMap().entries.map((
                                entry,
                              ) {
                                int index = entry.key;
                                var item = entry.value;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(item['cantidad'].toString())),
                                    DataCell(Text(item['nombre'])),
                                    widget.tipoCliente == 'Especial'
                                        ? DataCell(
                                            TextFormField(
                                              initialValue: item['precio']
                                                  .toString(),
                                              keyboardType:
                                                  TextInputType.number,
                                              onChanged: (value) {
                                                final nuevoPrecio =
                                                    double.tryParse(value) ??
                                                    item['precio'];
                                                setState(() {
                                                  item['precio'] = nuevoPrecio;
                                                  item['total'] =
                                                      nuevoPrecio *
                                                      item['cantidad'];
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
                                        icon: Icon(
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
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              "El total es de: \$${_calcularTotalProducto().toStringAsFixed(2)}",
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _observacionController,
                      decoration: const InputDecoration(
                        suffixIcon: Icon(Icons.wechat_sharp),
                        hintText: "Escriba una observacion",
                        labelText: "Observacion",
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: _formaPago,
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
                          child: Text('Fianza / Credito'),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;

                        // CUOTAS o FIANZA → pantalla aparte
                        if (value == 'cuotas' || value == 'fianza') {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConfigPago(
                                tipoPago: value,
                                totalPedido: _calcularTotalProducto(),
                              ),
                            ),
                          );

                          if (result == null) {
                            // IMPORTANTE
                            setState(() {
                              _formaPago = 'entrega';
                              _pagoConfig = null;
                            });
                            return;
                          }

                          setState(() {
                            _formaPago = value;
                            _pagoConfig = result;
                          });
                        } else {
                          // ENTREGA o BANCARIO
                          setState(() {
                            _formaPago = value;
                            _pagoConfig = null;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Seleccione una forma de pago';
                        }
                        return null;
                      },
                    ),
                    if (_formaPago == 'entrega')
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
                    if (_formaPago == 'bancario') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: "nequi",
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
                      onPressed: () async {
                        await _mostrarDialogoCarga();
                        await Future.delayed(const Duration(seconds: 3));
                        await _guardarPedido();
                      },
                      child: Text("Guardar"),
                    ),
                    const SizedBox(height: 45),
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
