import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Pedidos/product_load.dart';

class AddPedidos extends StatefulWidget {
  const AddPedidos({super.key});

  @override
  State<AddPedidos> createState() => _AddPedidosState();
}

class _AddPedidosState extends State<AddPedidos> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedclienteList;
  String? _tipoClienteSeleccionado;
  Map<String, String> _mapaClientesTipo = {};

  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _fechaGeneralController = TextEditingController();

  List<String> _clienteList = [];
  bool _isLoadingClientes = true;

  final FocusNode _clienteFocusNode = FocusNode();

  String _normalizeText(String text) {
    const withAccents = 'áàäâãéèëêíìïîóòöôõúùüûñÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuunAAAAAEEEEIIIIOOOOOUUUUN';

    String result = text;

    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }

    return result.toLowerCase().trim();
  }

  Future<void> _loadClientes(DateTime fechaSeleccionada) async {
    if (!mounted) return;
    setState(() {
      _isLoadingClientes = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Obtener adminId si el usuario es asistente
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    String adminId = currentUser.uid; // Por defecto, el usuario actual es admin
    if (userDoc.exists && userDoc.data()!.containsKey('adminId')) {
      adminId = userDoc['adminId'];
    }

    // Obtener pedidos en la fecha seleccionada
    final pedidosSnapshot = await FirebaseFirestore.instance
        .collection('pedidos')
        .where(
          'fecha',
          isEqualTo: DateTime(
            fechaSeleccionada.year,
            fechaSeleccionada.month,
            fechaSeleccionada.day,
          ),
        )
        .get();

    final clientesConPedido = pedidosSnapshot.docs
        .map((doc) => doc['cliente'].toString())
        .toSet();

    // Obtener solo los clientes del admin actual
    final clientesSnapshot = await FirebaseFirestore.instance
        .collection('clientes')
        .where('adminId', isEqualTo: adminId)
        .orderBy('nombre')
        .get();

    final todosLosClientes = clientesSnapshot.docs.map((doc) {
      // Obtener nombre y apellido
      final nombre = doc['nombre']?.toString() ?? '';
      final apellido = doc['apellido']?.toString() ?? '';
      return '${nombre.trim()} ${apellido.trim()}'.trim();
    }).toList();

    final mapaTipo = {
      for (var doc in clientesSnapshot.docs)
        '${doc['nombre']} ${doc['apellido']}': (doc['tipo'] ?? 'Normal')
            .toString(),
    };

    // Filtrar clientes que aún no tienen pedido ese día
    final disponibles = todosLosClientes
        .where((nombre) => !clientesConPedido.contains(nombre))
        .toList();

    if (!mounted) return;

    setState(() {
      _clienteList = disponibles;
      _mapaClientesTipo = mapaTipo;
      _isLoadingClientes = false;
      _selectedclienteList = null;
      _tipoClienteSeleccionado = null;
      _clienteController.clear();
    });
  }

  @override
  void initState() {
    super.initState();

    // Obtener la fecha actual
    final DateTime fechaActual = DateTime.now();

    // Formatear la fecha en el formato que usas en el TextFormField
    final String formattedDate =
        "${fechaActual.day}/${fechaActual.month}/${fechaActual.year}";

    // Asignar el texto al controlador
    _fechaGeneralController.text = formattedDate;

    // Llamar a la función que carga los clientes para esa fecha
    _loadClientes(fechaActual);
  }

  @override
  void dispose() {
    _clienteFocusNode.dispose();
    _clienteController.dispose();
    _fechaGeneralController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Realizar Pedido')),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              TextFormField(
                controller: _fechaGeneralController,
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_month_outlined),
                  hintText: "Seleccione una fecha",
                  labelText: "Fecha del pedido",
                ),
                keyboardType: TextInputType.none,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Este campo es obligatorio!!!';
                  }
                  return null;
                },
                onTap: () async {
                  DateTime fechaActual = DateTime.now();
                  DateTime primeraFecha = fechaActual.subtract(
                    const Duration(days: 7),
                  );
                  DateTime ultimaFecha = fechaActual.add(
                    const Duration(days: 7),
                  );

                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: fechaActual,
                    firstDate: primeraFecha,
                    lastDate: ultimaFecha,
                  );

                  if (pickedDate != null) {
                    String formattedDate =
                        "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                    _fechaGeneralController.text = formattedDate;

                    // Llama al método para cargar los clientes disponibles para esa fecha
                    await _loadClientes(pickedDate);
                  }
                },
              ),
              const SizedBox(height: 20),
              if (_isLoadingClientes) ...[
                const CircularProgressIndicator(),
              ] else if (_clienteList.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Seleccione una fecha para cargar clientes o no hay clientes existentes.",
                  ),
                ),
              ] else ...[
                RawAutocomplete<String>(
                  textEditingController: _clienteController,
                  focusNode: _clienteFocusNode,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _clienteList;
                    }
                    return _clienteList.where((String option) {
                      final input = _normalizeText(textEditingValue.text);
                      final candidate = _normalizeText(option);
                      return candidate.contains(input);
                    });
                  },
                  onSelected: (String selection) {
                    setState(() {
                      _selectedclienteList = selection;
                      _tipoClienteSeleccionado =
                          _mapaClientesTipo[selection] ?? 'Normal';
                    });
                  },
                  fieldViewBuilder:
                      (
                        BuildContext context,
                        TextEditingController _,
                        FocusNode _,
                        VoidCallback onFieldSubmitted,
                      ) {
                        return TextFormField(
                          controller: _clienteController,
                          focusNode: _clienteFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Cliente',
                            suffixIcon: Icon(Icons.person_add_alt_1_sharp),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Seleccione o escriba un cliente válido';
                            }
                            final normalizedInput = _normalizeText(value);
                            final found = _clienteList.any(
                              (cliente) =>
                                  _normalizeText(cliente) == normalizedInput,
                            );

                            if (!found) {
                              return 'El cliente no existe en la lista';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _selectedclienteList = value;
                              _tipoClienteSeleccionado =
                                  _mapaClientesTipo[value] ?? 'Normal';
                            });
                          },
                        );
                      },
                  optionsViewBuilder:
                      (
                        BuildContext context,
                        AutocompleteOnSelected<String> onSelected,
                        Iterable<String> options,
                      ) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: SizedBox(
                              height: 300, // Altura máxima del menú
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    //dense: true, Reduce el espacio vertical
                                    visualDensity: VisualDensity
                                        .compact, // Aún más compacto
                                    title: Text(option),
                                    onTap: () {
                                      onSelected(option);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                ),
              ],

              const SizedBox(height: 20),
              if (_tipoClienteSeleccionado != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Tipo de cliente: $_tipoClienteSeleccionado',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 2.0),
                  borderRadius: BorderRadius.circular(30),
                ),
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductLoad(
                            tipoCliente: _tipoClienteSeleccionado!,
                            clienteNombre: _selectedclienteList!,
                            fechaPedido: _fechaGeneralController.text,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "Agregar productos",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
