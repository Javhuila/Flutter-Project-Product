import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProductosAsignadosPage extends StatefulWidget {
  final String inventarioId;
  final String nombreInventario;

  const ProductosAsignadosPage({
    super.key,
    required this.inventarioId,
    required this.nombreInventario,
  });

  @override
  State<ProductosAsignadosPage> createState() => _ProductosAsignadosPageState();
}

class _ProductosAsignadosPageState extends State<ProductosAsignadosPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _buscarController = TextEditingController();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _productos = [];

  String? _adminId;
  String _busqueda = '';
  String _categoria = 'Todos';
  String _clasificacion = 'Todos';

  int _paginaActual = 0;
  final int _productosPorPagina = 15;

  bool _cargando = true;
  bool _procesando = false;

  CollectionReference<Map<String, dynamic>> get _asignacionesRef => _firestore
      .collection('inventarios')
      .doc(widget.inventarioId)
      .collection('productos_asignados');

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No hay un usuario autenticado.');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      final adminId = userDoc.data()?['adminId']?.toString();

      _adminId = adminId != null && adminId.isNotEmpty ? adminId : user.uid;

      await _cargarProductos();
    } catch (e) {
      debugPrint('Error al inicializar asignaciones: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron cargar los productos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _cargarProductos() async {
    final snapshot = await _firestore
        .collection('productos')
        .where('adminId', isEqualTo: _adminId)
        .orderBy('nombre')
        .get();

    _productos = snapshot.docs;
  }

  List<String> get _categorias {
    final valores =
        _productos
            .map((p) => p.data()['categoria']?.toString() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return ['Todos', ...valores];
  }

  List<String> get _clasificaciones {
    final valores =
        _productos
            .map((p) => p.data()['clasificacion']?.toString() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return ['Todos', ...valores];
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _productosFiltrados {
    return _productos.where((producto) {
      final data = producto.data();

      final nombre = data['nombre']?.toString().toLowerCase() ?? '';
      final categoria = data['categoria']?.toString() ?? '';
      final clasificacion = data['clasificacion']?.toString() ?? '';

      final coincideNombre = nombre.contains(_busqueda.toLowerCase());
      final coincideCategoria =
          _categoria == 'Todos' || categoria == _categoria;
      final coincideClasificacion =
          _clasificacion == 'Todos' || clasificacion == _clasificacion;

      return coincideNombre && coincideCategoria && coincideClasificacion;
    }).toList();
  }

  Future<void> _agregarProducto(
    QueryDocumentSnapshot<Map<String, dynamic>> producto,
  ) async {
    if (_procesando) return;

    setState(() => _procesando = true);

    try {
      final data = producto.data();

      await _asignacionesRef.doc(producto.id).set({
        'nombre': data['nombre'] ?? 'Sin nombre',
        'categoria': data['categoria'] ?? '',
        'clasificacion': data['clasificacion'] ?? '',
        'fechaAsignacion': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${data['nombre'] ?? 'Producto'} asignado correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo asignar el producto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _eliminarAsignacion(String productoId, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar producto'),
        content: Text('¿Deseas quitar "$nombre" de este inventario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _asignacionesRef.doc(productoId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asignación eliminada correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al quitar el producto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarTodasLasAsignaciones() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar todas las asignaciones'),
        content: const Text(
          '¿Deseas quitar todos los productos asignados? '
          'El inventario volverá a permitir todos los productos disponibles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar todos'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final snapshot = await _asignacionesRef.get();

      // Firestore permite hasta 500 operaciones por batch.
      for (var i = 0; i < snapshot.docs.length; i += 450) {
        final batch = _firestore.batch();
        final grupo = snapshot.docs.skip(i).take(450);

        for (final doc in grupo) {
          batch.delete(doc.reference);
        }

        await batch.commit();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se eliminaron todas las asignaciones.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar las asignaciones: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtrados = _productosFiltrados;
    final totalPaginas = (filtrados.length / _productosPorPagina).ceil();

    if (totalPaginas == 0) {
      _paginaActual = 0;
    } else if (_paginaActual >= totalPaginas) {
      _paginaActual = totalPaginas - 1;
    }

    final inicio = _paginaActual * _productosPorPagina;
    final fin = (inicio + _productosPorPagina).clamp(0, filtrados.length);
    final productosPagina = filtrados.sublist(inicio, fin);

    return Scaffold(
      appBar: AppBar(title: const Text('Productos asignados')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.nombreInventario,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _buscarController,
              decoration: InputDecoration(
                labelText: 'Buscar producto',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _buscarController.clear();
                    setState(() {
                      _busqueda = '';
                      _paginaActual = 0;
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _busqueda = value.trim();
                  _paginaActual = 0;
                });
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _categoria,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: _categorias.map((valor) {
                      return DropdownMenuItem(
                        value: valor,
                        child: Text(valor, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (valor) {
                      setState(() {
                        _categoria = valor ?? 'Todos';
                        _paginaActual = 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _clasificacion,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Clasificación',
                      border: OutlineInputBorder(),
                    ),
                    items: _clasificaciones.map((valor) {
                      return DropdownMenuItem(
                        value: valor,
                        child: Text(valor, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (valor) {
                      setState(() {
                        _clasificacion = valor ?? 'Todos';
                        _paginaActual = 0;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(
                    'Productos disponibles',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (productosPagina.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('No hay productos que coincidan.'),
                    ),
                  )
                else
                  ...productosPagina.map((producto) {
                    final data = producto.data();

                    return ListTile(
                      title: Text(data['nombre'] ?? 'Sin nombre'),
                      subtitle: Text(
                        '${data['categoria'] ?? 'Sin categoría'} · '
                        '${data['clasificacion'] ?? 'Sin clasificación'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Asignar producto',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _procesando
                            ? null
                            : () => _agregarProducto(producto),
                      ),
                    );
                  }),

                if (totalPaginas > 1)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _paginaActual > 0
                              ? () => setState(() => _paginaActual--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Página ${_paginaActual + 1} de $totalPaginas'),
                        IconButton(
                          onPressed: _paginaActual < totalPaginas - 1
                              ? () => setState(() => _paginaActual++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Productos asignados',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _eliminarTodasLasAsignaciones,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar todos'),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _asignacionesRef.orderBy('nombre').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Error al cargar las asignaciones.'),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final asignados = snapshot.data!.docs;

                    if (asignados.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Este inventario no tiene productos asignados.',
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Producto')),
                          DataColumn(label: Text('Categoría')),
                          DataColumn(label: Text('Clasificación')),
                          DataColumn(label: Text('Acción')),
                        ],
                        rows: asignados.map((doc) {
                          final data = doc.data();

                          return DataRow(
                            cells: [
                              DataCell(Text(data['nombre']?.toString() ?? '')),
                              DataCell(
                                Text(data['categoria']?.toString() ?? ''),
                              ),
                              DataCell(
                                Text(data['clasificacion']?.toString() ?? ''),
                              ),
                              DataCell(
                                IconButton(
                                  tooltip: 'Quitar asignación',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _eliminarAsignacion(
                                    doc.id,
                                    data['nombre']?.toString() ?? 'Producto',
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
