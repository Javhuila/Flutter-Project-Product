import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Clientes/add_clientes.dart';
import 'package:flutter_project_product/Clientes/edit_clientes.dart';
import 'package:flutter_project_product/Clientes/gestion_product_client.dart';
import 'package:flutter_project_product/Clientes/info_clientes.dart';

class Clientes extends StatefulWidget {
  const Clientes({super.key});

  @override
  State<Clientes> createState() => _ClientesState();
}

class _ClientesState extends State<Clientes> with TickerProviderStateMixin {
  String? _userRole;
  bool _isLoadingRole = true;

  String _filtroTipo = 'Todos';

  Timer? _debounce;

  final List<String> _filtrosDisponibles = ['Todos', 'Normal', 'Especial'];
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 25;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  late AnimationController _animationController;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  final List<QueryDocumentSnapshot> _allClientes = [];
  List<QueryDocumentSnapshot> _filteredClientes = [];

  final FocusNode _searchFocusNode = FocusNode();

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

  /// Normaliza un texto para comparar sin acentos ni mayúsculas.
  /// Ejemplo: "José Álvarez" -> "jose alvarez"
  String _normalizeText(String text) {
    const withAccents = 'áàäâãéèëêíìïîóòöôõúùüûñÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuunAAAAAEEEEIIIIOOOOOUUUUN';

    String result = text;

    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }

    return result.toLowerCase().trim();
  }

  Future<void> _searchClientes(String query, {bool reset = true}) async {
    setState(() {
      if (reset) {
        _filteredClientes.clear();
        _lastDocument = null;
        _hasMore = true;
      }
      _isLoadingMore = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String adminId = user.uid;
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    Query queryRef = FirebaseFirestore.instance
        .collection('clientes')
        .where('adminId', isEqualTo: adminId);

    // Aplica filtro por tipo
    if (_filtroTipo != 'Todos') {
      queryRef = queryRef.where('tipo', isEqualTo: _filtroTipo);
    }

    // Caso 1: Búsqueda activa (query no vacío)
    if (query.isNotEmpty) {
      // En modo búsqueda, cargamos todos los clientes (sin paginar)
      final snapshot = await queryRef
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();

      List<QueryDocumentSnapshot> resultados = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final nombreCompleto = (data['nombreCompleto'] ?? '')
            .toString()
            .toLowerCase();

        if (_normalizeText(nombreCompleto).contains(_normalizeText(query))) {
          resultados.add(doc);
        }
      }

      setState(() {
        _filteredClientes = resultados;
        _isLoadingMore = false;
        _hasMore = false; // Desactiva paginación durante búsqueda
      });

      return;
    }

    // Caso 2: No hay búsqueda → paginación normal
    if (_lastDocument != null && !reset) {
      queryRef = queryRef.startAfterDocument(_lastDocument!);
    }

    queryRef = queryRef.orderBy('createdAt', descending: true).limit(_pageSize);

    final snapshot = await queryRef.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;

      for (var doc in snapshot.docs) {
        if (!_filteredClientes.any((d) => d.id == doc.id)) {
          _filteredClientes.add(doc);
        }
      }

      if (snapshot.docs.length < _pageSize) {
        _hasMore = false;
      }
    } else {
      _hasMore = false;
    }

    setState(() {
      _isLoadingMore = false;
    });
  }

  void _filterClientes(String query) {
    setState(() {
      _filteredClientes = _allClientes.where((clienteDoc) {
        final cliente = clienteDoc.data() as Map<String, dynamic>;
        final nombre = cliente['nombre']?.toString().toLowerCase() ?? '';
        final apellido = cliente['apellido']?.toString().toLowerCase() ?? '';
        final empresa = cliente['empresa']?.toString().toLowerCase() ?? '';
        final tipo = cliente['tipo'];

        final nombreCompleto = '$nombre $apellido';

        final coincideBusqueda =
            nombreCompleto.contains(query.toLowerCase()) ||
            empresa.contains(query.toLowerCase());

        final coincideFiltro = _filtroTipo == 'Todos' || tipo == _filtroTipo;

        return coincideBusqueda && coincideFiltro;
      }).toList();
    });
  }

  void _eliminarCliente(DocumentSnapshot doc) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("¿Eliminar cliente?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => navigator.pop(true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('clientes')
          .doc(doc.id)
          .delete();
      await _loadClientes(reset: true);

      messenger.showSnackBar(
        const SnackBar(content: Text('Cliente eliminado')),
      );

      _allClientes.remove(doc);
      _filterClientes(_searchController.text);
    }
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      // -1 Izquierda, 0 Derecha. DX
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _loadUserRole();
    _loadClientes();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        if (_searchController.text.isNotEmpty) {
          _searchClientes(_searchController.text, reset: false);
        } else {
          _loadClientes();
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadClientes({bool reset = false}) async {
    if (_isLoadingMore || (!_hasMore && !reset)) return;

    setState(() => _isLoadingMore = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (reset) {
      _allClientes.clear();
      _filteredClientes.clear();
      _lastDocument = null;
      _hasMore = true;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String adminId = user.uid; // valor por defecto
    if (userDoc.exists && userDoc.data()?['adminId'] != null) {
      adminId = userDoc['adminId'];
    }

    Query query = FirebaseFirestore.instance
        .collection('clientes')
        .where('adminId', isEqualTo: adminId)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null && !reset) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
      _allClientes.addAll(snapshot.docs);
    } else {
      _hasMore = false;
    }

    if (snapshot.docs.length < _pageSize) {
      _hasMore = false;
    }

    _filterClientes(_searchController.text);

    setState(() => _isLoadingMore = false);
  }

  // Future<void> _actualizarTodosLosClientes() async {
  //   final confirm = await showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: const Text("Actualizar clientes"),
  //       content: const Text(
  //         "Esto agregará o corregirá el campo 'nombreCompleto' en todos los clientes existentes. ¿Deseas continuar?",
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: const Text("Cancelar"),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           child: const Text("Actualizar"),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirm != true) return;

  //   ScaffoldMessenger.of(
  //     context,
  //   ).showSnackBar(const SnackBar(content: Text('Actualizando clientes...')));

  //   try {
  //     final snapshot = await FirebaseFirestore.instance
  //         .collection('clientes')
  //         .get();

  //     int actualizados = 0;
  //     for (var doc in snapshot.docs) {
  //       final data = doc.data();
  //       final nombre = (data['nombre'] ?? '').toString().trim();
  //       final apellido = (data['apellido'] ?? '').toString().trim();
  //       final nombreCompleto = '$nombre $apellido'.trim();

  //       // Evita sobreescribir si ya está correcto
  //       if (data['nombreCompleto'] != nombreCompleto) {
  //         await doc.reference.update({'nombreCompleto': nombreCompleto});
  //         actualizados++;
  //       }
  //     }

  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           'Actualización completada. $actualizados clientes actualizados.',
  //         ),
  //       ),
  //     );
  //   } catch (e) {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Clientes"),
          actions: _userRole == 'admin'
              ? [
                  IconButton(
                    onPressed: () async {
                      _searchFocusNode.unfocus();

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddClientes()),
                      );

                      if (result == true) {
                        _loadClientes(reset: true);
                      }
                    },
                    icon: const Icon(Icons.person_add_alt, size: 30),
                  ),
                  // IconButton(
                  //   onPressed: _actualizarTodosLosClientes,
                  //   tooltip: 'Actualizar nombreCompleto',
                  //   icon: const Icon(Icons.update, size: 30),
                  // ),
                ]
              : [],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
            child: Column(
              children: [
                SizedBox(height: 20),
                TextFormField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce?.cancel();

                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      _searchClientes(value); // Cada vez que se escribe, busca
                    });
                  },
                  keyboardType: TextInputType.name,
                  style: const TextStyle(
                    fontSize: 20,
                    overflow: TextOverflow.ellipsis,
                  ),
                  decoration: InputDecoration(
                    labelText: "Buscar",
                    hintText: "Buscar clientes",
                    suffixIcon: const Icon(Icons.search_outlined, size: 40),
                    suffixIconColor: Colors.grey,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: InputBorder.none,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: Colors.grey),
                      gapPadding: 10,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: Colors.grey),
                      gapPadding: 10,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 20,
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2.0,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(
                        color: Colors.deepOrange,
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButtonFormField<String>(
                    itemHeight: 80,
                    isExpanded: true,
                    initialValue: _filtroTipo,
                    items: _filtrosDisponibles.map((String tipo) {
                      return DropdownMenuItem<String>(
                        value: tipo,
                        child: Text(tipo),
                      );
                    }).toList(),
                    onChanged: (String? nuevoTipo) {
                      if (nuevoTipo != null) {
                        setState(() {
                          _filtroTipo = nuevoTipo;
                        });
                        _searchClientes(_searchController.text);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 40),
                _filteredClientes.isEmpty
                    ? const Center(
                        child: Text("No hay clientes que coincidan."),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount:
                            _filteredClientes.length +
                            ((_hasMore && _searchController.text.isEmpty)
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index == _filteredClientes.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20.0,
                              ),
                              child: Center(
                                child: GestureDetector(
                                  onTap: _hasMore && !_isLoadingMore
                                      ? _loadClientes
                                      : null,
                                  child: Column(
                                    children: [
                                      if (_isLoadingMore)
                                        const CircularProgressIndicator()
                                      else
                                        const Icon(Icons.download),
                                      const SizedBox(height: 10),
                                      Text(
                                        _hasMore
                                            ? 'Toca para cargar más...'
                                            : 'No hay más clientes.',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          final doc = _filteredClientes[index];
                          final cliente = doc.data() as Map<String, dynamic>;

                          return SlideTransition(
                            position: _offsetAnimation,
                            child: GestureDetector(
                              onTap: () {
                                _searchFocusNode.unfocus();

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        InfoClientes(cliente: doc),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: cliente['tipo'] == 'Especial'
                                      ? Colors.blue.shade400
                                      : Colors.green.shade400,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Nombre: ${cliente['nombreCompleto']}",
                                              style: const TextStyle(
                                                fontSize: 20,
                                              ),
                                            ),
                                            Text(
                                              "Empresa: ${cliente['empresa']}",
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              "Tipo: ${cliente['tipo']}",
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_userRole == 'admin')
                                        PopupMenuButton<int>(
                                          icon: const Icon(
                                            Icons.more_vert,
                                            size: 30,
                                          ),
                                          onSelected: (value) async {
                                            switch (value) {
                                              case 0:
                                                _searchFocusNode.unfocus();

                                                final result =
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            EditClientes(
                                                              cliente: doc,
                                                            ),
                                                      ),
                                                    );
                                                if (result == true) {
                                                  _loadClientes(reset: true);
                                                }
                                                break;

                                              case 1:
                                                if (cliente['tipo'] ==
                                                    'Especial') {
                                                  final preciosPersonalizados =
                                                      Map<String, dynamic>.from(
                                                        cliente['precio_personalizado'] ??
                                                            {},
                                                      );
                                                  _searchFocusNode.unfocus();
                                                  final result = await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          GestionProductClient(
                                                            clienteId: doc.id,
                                                            preciosPersonalizados:
                                                                preciosPersonalizados,
                                                          ),
                                                    ),
                                                  );
                                                  if (result == true) {
                                                    _loadClientes(reset: true);
                                                  }
                                                }
                                                break;

                                              case 2:
                                                _eliminarCliente(doc);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem<int>(
                                              value: 0,
                                              child: ListTile(
                                                leading: Icon(Icons.edit),
                                                title: Text('Editar cliente'),
                                              ),
                                            ),
                                            if (cliente['tipo'] == 'Especial')
                                              const PopupMenuItem<int>(
                                                value: 1,
                                                child: ListTile(
                                                  leading: Icon(Icons.edit),
                                                  title: Text('Editar precios'),
                                                ),
                                              ),
                                            const PopupMenuItem<int>(
                                              value: 2,
                                              child: ListTile(
                                                leading: Icon(Icons.delete),
                                                title: Text('Eliminar'),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 65),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
