import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_project_product/Compras/widgets/precio_historial.dart';
import 'package:flutter_project_product/Service/Cloudinary/image_upload_service.dart';

class AddCompra extends StatefulWidget {
  const AddCompra({super.key});

  @override
  State<AddCompra> createState() => _AddCompraState();
}

enum TipoCompra { normal, flete }

class _AddCompraState extends State<AddCompra> {
  final _formProductosKey = GlobalKey<FormState>();
  final _formInfoKey = GlobalKey<FormState>();

  TipoCompra tipoCompra = TipoCompra.normal;

  StreamSubscription? _productosSub;
  bool _productosCargados = false;

  List<Map<String, dynamic>> listaProductos = [];
  final FocusNode _productoFocusNode = FocusNode();
  Timer? _debounce;
  String _searchText = "";

  List<Map<String, dynamic>> productos = [];
  double totalCompra = 0;

  String? concurrencia = "diario";
  String? destinatario;
  String? productoId;
  String? nombre;
  String? imagen;

  final productoController = TextEditingController();
  final precioController = TextEditingController();
  final precioDefaultController = TextEditingController();
  final cantidadController = TextEditingController();
  final proveedorController = TextEditingController();

  double total = 0;

  @override
  void initState() {
    super.initState();

    _loadProductosCompra();
  }

  Future<void> _loadProductosCompra() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String adminId = userDoc.data()?['adminId'] ?? user.uid;

    _productosSub = FirebaseFirestore.instance
        .collection('productos')
        .where('adminId', isEqualTo: adminId)
        .snapshots()
        .listen((snapshot) {
          listaProductos = snapshot.docs.map((doc) {
            final data = doc.data();

            return {
              "id": doc.id,
              "nombre": data['nombre'] ?? '',
              "imagen": data['imagen'] ?? '',
            };
          }).toList();

          setState(() {
            _productosCargados = true;
          });
        });
  }

  String _normalizeText(String text) {
    const withAccents = 'áàäâãéèëêíìïîóòöôõúùüûñÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuunAAAAAEEEEIIIIOOOOOUUUUN';

    String result = text;

    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }

    return result.toLowerCase().trim();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchText = value;
      });
    });
  }

  Map<String, dynamic> inicializarCantidades(String concurrencia) {
    switch (concurrencia) {
      case "diario":
        return {"0": 0};

      case "semanal":
        return {for (int i = 0; i < 7; i++) "$i": 0};

      case "mensual":
        return {for (int i = 0; i < 4; i++) "$i": 0};

      case "anual":
        return {for (int i = 0; i < 12; i++) "$i": 0};

      default:
        return {"0": 0};
    }
  }

  int _obtenerIndiceActual(String concurrencia) {
    final now = DateTime.now();

    switch (concurrencia) {
      case "diario":
        return 0;

      case "semanal":
        return now.weekday - 1;

      case "mensual":
        final primerDia = DateTime(now.year, now.month, 1);
        final offset = primerDia.weekday - 1;

        final indice = ((now.day + offset - 1) / 7).floor();

        final totalCeldas = DateTime(now.year, now.month + 1, 0).day + offset;
        final totalSemanas = (totalCeldas / 7).ceil();

        return indice.clamp(0, totalSemanas - 1);

      case "anual":
        return now.month - 1;

      default:
        return 0;
    }
  }

  void _agregarProducto(
    String id,
    String nombre,
    double precio,
    double precioDefault,
    int cantidad,
  ) {
    if (concurrencia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona la concurrencia primero")),
      );
      return;
    }

    final indexTiempo = _obtenerIndiceActual(concurrencia!);
    final total = precio * cantidad;

    setState(() {
      final index = productos.indexWhere((p) => p['productoId'] == id);

      if (index != -1) {
        productos[index]['cantidades'] ??= inicializarCantidades(concurrencia!);

        final actual =
            productos[index]['cantidades'][indexTiempo.toString()] ?? 0;

        productos[index]['cantidades'][indexTiempo.toString()] =
            actual + cantidad;

        productos[index]['valor_total'] += total;
      } else {
        final cantidades = inicializarCantidades(concurrencia!);

        cantidades[indexTiempo.toString()] = cantidad;
        productos.add({
          "productoId": id,
          "nombre": nombre,
          "tipo_compra": tipoCompra.name,
          "precio_compra": precio,
          if (tipoCompra == TipoCompra.flete)
            "precio_por_defecto": precioDefault,
          "cantidades": cantidades,
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
    productoController.dispose();
    _productoFocusNode.dispose();
    _productosSub?.cancel();
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
              spacing: 14,
              children: [
                ToggleButtons(
                  isSelected: [
                    tipoCompra == TipoCompra.normal,
                    tipoCompra == TipoCompra.flete,
                  ],
                  onPressed: (index) {
                    setState(() {
                      tipoCompra = TipoCompra.values[index];

                      precioController.clear();
                      precioDefaultController.clear();
                      cantidadController.clear();
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text("Normal"),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text("Con flete"),
                    ),
                  ],
                ),
                Center(child: Text("Frecuencia de la compra")),
                DropdownButtonFormField<String>(
                  initialValue: concurrencia,
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.dynamic_feed_sharp),
                  ),
                  hint: Text("Frecuencia"),
                  items: ["diario", "semanal", "mensual", "anual"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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
                Divider(height: 3),
                if (!_productosCargados) const CircularProgressIndicator(),
                Center(child: Text("Productos y precios")),
                _buildAutocomplete(),
                if (tipoCompra == TipoCompra.flete)
                  PrecioAutocompleteField(
                    controller: precioDefaultController,
                    typeBoard: TextInputType.number,
                    onChanged: () {},
                    labelTextInput: "Precio base",
                    ultimateIcon: Icon(Icons.monetization_on_outlined),
                    storageKey: "historial_precio_base",
                  ),
                // TextFormField(
                //   controller: precioDefaultController,
                //   decoration: const InputDecoration(
                //     labelText: "Precio base",
                //     suffixIcon: Icon(Icons.monetization_on_outlined),
                //   ),
                //   keyboardType: TextInputType.number,
                // ),
                PrecioAutocompleteField(
                  controller: precioController,
                  typeBoard: TextInputType.number,
                  onChanged: _calcularTotal,
                  labelTextInput: "Precio compra",
                  ultimateIcon: Icon(Icons.monetization_on_sharp),
                  storageKey: "historial_precio_compra",
                ),
                TextFormField(
                  controller: cantidadController,
                  decoration: const InputDecoration(
                    labelText: "Cantidad",
                    suffixIcon: Icon(Icons.onetwothree_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _calcularTotal(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Campo obligatorio";
                    }
                    if (int.tryParse(value) == null) return "Número inválido";
                    return null;
                  },
                ),

                ElevatedButton(
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
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

                    final esFlete = tipoCompra == TipoCompra.flete;

                    if (precio <= 0 || cantidad <= 0) return;

                    if (esFlete && precioDefault <= 0) return;

                    if (tipoCompra == TipoCompra.flete) {
                      await PrecioHistorial.guardarPrecio(
                        "historial_precio_base",
                        precioDefaultController.text,
                      );
                    }

                    await PrecioHistorial.guardarPrecio(
                      "historial_precio_compra",
                      precioController.text,
                    );
                    // print("Guardando precio: ${precioController.text}");

                    _agregarProducto(
                      productoId!,
                      nombre!,
                      precio,
                      tipoCompra == TipoCompra.flete ? precioDefault : 0,
                      cantidad,
                    );

                    // limpiar inputs
                    setState(() {
                      precioController.clear();
                      cantidadController.clear();
                      productoController.clear();
                      precioDefaultController.clear();
                      productoId = null;
                      nombre = null;
                      imagen = null;
                    });
                  },
                  child: Text("Agregar producto"),
                ),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(),
                    columns: const [
                      DataColumn(label: Text("Producto")),
                      DataColumn(label: Text("Cant")),
                      DataColumn(label: Text("Total")),
                      DataColumn(label: Text("Acción")),
                    ],
                    rows: productos.map((p) {
                      int cantidadTotal = 0;

                      (p['cantidades'] as Map<String, dynamic>).forEach((
                        key,
                        value,
                      ) {
                        cantidadTotal += (value as int);
                      });
                      return DataRow(
                        cells: [
                          DataCell(Text(p['nombre'])),
                          DataCell(Text(cantidadTotal.toString())),
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
                Divider(height: 5),
                Form(
                  key: _formInfoKey,
                  child: Column(
                    spacing: 8,
                    children: [
                      Center(child: Text("Otros datos")),
                      TextFormField(
                        controller: proveedorController,
                        decoration: const InputDecoration(
                          labelText: "Proveedor",
                          suffixIcon: Icon(Icons.person_4_sharp),
                        ),
                      ),

                      TextFormField(
                        decoration: InputDecoration(
                          labelText: "Destinatario",
                          suffixIcon: Icon(Icons.emoji_people_rounded),
                        ),
                        onChanged: (value) => destinatario = value,
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
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutocomplete() {
    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: productoController,
      focusNode: _productoFocusNode,
      displayStringForOption: (option) => option['nombre'],

      optionsBuilder: (TextEditingValue textEditingValue) {
        if (_searchText.isEmpty) {
          return listaProductos;
        }

        return listaProductos.where((Map<String, dynamic> option) {
          final input = _normalizeText(textEditingValue.text);
          final candidate = _normalizeText(option['nombre']);
          return candidate.contains(input);
        });
      },

      onSelected: (Map<String, dynamic> seleccion) {
        setState(() {
          productoId = seleccion['id'];
          nombre = seleccion['nombre'];
          imagen = seleccion['imagen'];
        });
      },

      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            labelText: "Producto",
            suffixIcon: Icon(Icons.checklist_rtl_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (_) =>
              productoId == null ? 'Selecciona o escriba un producto' : null,
        );
      },

      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              height: 250,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final producto = options.elementAt(index);
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final imageUrl = producto['imagen'];

                  return ListTile(
                    leading: (imageUrl != null && imageUrl.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: getOptimizedCloudinaryUrl(imageUrl),
                              filterQuality: FilterQuality.low,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 150),
                              fadeOutDuration: const Duration(
                                milliseconds: 100,
                              ),
                              memCacheHeight: (40 * dpr.toInt()),
                              memCacheWidth: (40 * dpr.toInt()),
                              useOldImageOnUrlChange: true,
                              placeholder: (_, _) =>
                                  const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image, size: 40),
                              cacheManager: CustomCacheManager.instance,
                            ),
                          )
                        : const Icon(Icons.image_not_supported, size: 40),
                    title: Text(producto['nombre']),
                    onTap: () => onSelected(producto),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class PrecioAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final TextInputType typeBoard;
  final Widget? ultimateIcon;
  final String labelTextInput;
  final String storageKey;

  const PrecioAutocompleteField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.typeBoard,
    required this.ultimateIcon,
    required this.labelTextInput,
    required this.storageKey,
  });

  @override
  State<PrecioAutocompleteField> createState() =>
      _PrecioAutocompleteFieldState();
}

class _PrecioAutocompleteFieldState extends State<PrecioAutocompleteField> {
  List<Map<String, dynamic>> historial = [];

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void didUpdateWidget(covariant PrecioAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    historial = await PrecioHistorial.obtenerHistorial(widget.storageKey);
    // print("Historial cargado: $historial");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue value) {
        if (historial.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }

        // Mostrar todos si está vacío
        if (value.text.isEmpty) {
          return historial;
        }

        return historial.where(
          (item) => item["valor"].toString().toLowerCase().contains(
            value.text.toLowerCase(),
          ),
        );
      },
      displayStringForOption: (option) => option["valor"],
      onSelected: (selection) {
        widget.controller.text = selection["valor"];
        widget.onChanged();
      },

      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.text != widget.controller.text) {
            controller.value = TextEditingValue(
              text: widget.controller.text,
              selection: TextSelection.collapsed(
                offset: widget.controller.text.length,
              ),
            );
          }
        });

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: widget.typeBoard,
          decoration: InputDecoration(
            labelText: widget.labelTextInput,
            suffixIcon: widget.ultimateIcon,
          ),
          onTap: () async {
            await _cargarHistorial();
            controller.value = TextEditingValue(
              text: controller.text,
              selection: TextSelection.collapsed(
                offset: controller.text.length,
              ),
            );
          },
          onChanged: (value) async {
            widget.controller.text = value;
            widget.onChanged();
          },
          onFieldSubmitted: (value) async {
            await PrecioHistorial.guardarPrecio(widget.storageKey, value);
            await _cargarHistorial();
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Campo obligatorio";
            }
            if (double.tryParse(value) == null) {
              return "Número inválido";
            }
            return null;
          },
        );
      },

      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);

                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(option["valor"]),
                    trailing: Text(
                      "Usado ${option["count"]}x",
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class CustomCacheManager {
  static const key = 'customCacheKey';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
