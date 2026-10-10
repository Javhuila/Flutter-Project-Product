import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'inventario.dart';

class InventariosPage extends StatefulWidget {
  const InventariosPage({super.key});

  @override
  State<InventariosPage> createState() => _InventariosPageState();
}

class _InventariosPageState extends State<InventariosPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _adminId;
  String? _userRole;
  bool _cargandoUsuario = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _cargandoUsuario = false;
        });

        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      String adminId = user.uid;
      String role = 'asistente';

      if (userDoc.exists) {
        final data = userDoc.data();

        role = data?['role']?.toString() ?? 'asistente';

        final adminIdUsuario = data?['adminId'];

        if (adminIdUsuario != null &&
            adminIdUsuario.toString().trim().isNotEmpty) {
          adminId = adminIdUsuario.toString();
        }
      }

      if (!mounted) return;

      setState(() {
        _adminId = adminId;
        _userRole = role;
        _cargandoUsuario = false;
      });
    } catch (e) {
      debugPrint('Error al cargar datos del usuario: $e');

      if (!mounted) return;

      setState(() {
        _cargandoUsuario = false;
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _obtenerInventarios() {
    if (_adminId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('inventarios')
        .where('adminId', isEqualTo: _adminId)
        .where('activo', isEqualTo: true)
        .orderBy('fechaCreacion', descending: false)
        .snapshots();
  }

  Future<void> _crearInventario() async {
    if (_userRole != 'admin') return;

    final formKey = GlobalKey<FormState>();

    final nombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final nombreController = TextEditingController();

        return AlertDialog(
          title: const Text('Nuevo inventario'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nombreController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Nombre del inventario',
                hintText: 'Ej. Productos de tienda',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final texto = value?.trim() ?? '';

                if (texto.isEmpty) {
                  return 'Ingresa un nombre';
                }

                if (texto.length < 2) {
                  return 'El nombre es demasiado corto';
                }

                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, nombreController.text.trim());
                }
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
    await Future<void>.delayed(Duration.zero);

    if (nombre == null || nombre.trim().isEmpty) {
      return;
    }

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final adminId = _adminId;

      if (adminId == null || adminId.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No se pudo identificar el administrador.'),
          ),
        );

        return;
      }

      /*
       * Antes de crear el inventario verificamos si ya existe
       * uno activo con el mismo nombre para este administrador.
       */
      final existentes = await _firestore
          .collection('inventarios')
          .where('adminId', isEqualTo: adminId)
          .where('activo', isEqualTo: true)
          .get();

      final nombreNormalizado = nombre.trim().toLowerCase();

      final existe = existentes.docs.any((doc) {
        final nombreExistente =
            doc.data()['nombre']?.toString().trim().toLowerCase() ?? '';

        return nombreExistente == nombreNormalizado;
      });

      if (existe) {
        if (!mounted) return;

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ya existe un inventario activo con ese nombre.'),
          ),
        );

        return;
      }

      await _firestore.collection('inventarios').add({
        'nombre': nombre.trim(),
        'adminId': adminId,
        'activo': true,
        'mostrarPrecioEmpresa': false,
        'fechaCreacion': Timestamp.now(),
      });

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Inventario creado correctamente.')),
      );
    } catch (e) {
      debugPrint('Error al crear inventario: $e');

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al crear el inventario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _mostrarOpcionesInventario(
    QueryDocumentSnapshot<Map<String, dynamic>> inventario,
  ) async {
    if (_userRole != 'admin') return;

    final nombre = inventario.data()['nombre']?.toString() ?? 'Inventario';

    final opcion = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Renombrar'),
                onTap: () {
                  Navigator.pop(context, 'renombrar');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Desactivar',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context, 'desactivar');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context, 'eliminar');
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (!mounted || opcion == null) return;

    switch (opcion) {
      case 'renombrar':
        await _renombrarInventario(inventario);
        break;

      case 'desactivar':
        await _desactivarInventario(inventario);
        break;

      case 'eliminar':
        await _eliminarInventario(inventario);
        break;
    }
  }

  Future<void> _renombrarInventario(
    QueryDocumentSnapshot<Map<String, dynamic>> inventario,
  ) async {
    final nombreActual = inventario.data()['nombre']?.toString() ?? '';

    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _RenombrarInventarioDialog(nombreActual: nombreActual);
      },
    );

    if (nuevoNombre == null ||
        nuevoNombre.trim().isEmpty ||
        nuevoNombre.trim() == nombreActual.trim()) {
      return;
    }

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final adminId = _adminId;

      if (adminId == null || adminId.isEmpty) {
        return;
      }

      final existentes = await _firestore
          .collection('inventarios')
          .where('adminId', isEqualTo: adminId)
          .where('activo', isEqualTo: true)
          .get();

      final nombreNormalizado = nuevoNombre.trim().toLowerCase();

      final existe = existentes.docs.any((doc) {
        if (doc.id == inventario.id) {
          return false;
        }

        final nombreExistente =
            doc.data()['nombre']?.toString().trim().toLowerCase() ?? '';

        return nombreExistente == nombreNormalizado;
      });

      if (existe) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ya existe otro inventario con ese nombre.'),
          ),
        );
        return;
      }

      await inventario.reference.update({'nombre': nuevoNombre.trim()});

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Inventario actualizado correctamente.')),
      );
    } catch (e) {
      debugPrint('Error al renombrar inventario: $e');

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al renombrar el inventario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _desactivarInventario(
    QueryDocumentSnapshot<Map<String, dynamic>> inventario,
  ) async {
    final nombre = inventario.data()['nombre']?.toString() ?? 'este inventario';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Desactivar inventario'),
          content: Text(
            '¿Deseas desactivar "$nombre"?\n\n'
            'El inventario dejará de aparecer en la lista, '
            'pero sus datos no serán eliminados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Desactivar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await inventario.reference.update({'activo': false});

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Inventario desactivado correctamente.')),
      );
    } catch (e) {
      debugPrint('Error al desactivar inventario: $e');

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al desactivar el inventario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarInventario(
    DocumentSnapshot<Map<String, dynamic>> inventario,
  ) async {
    if (_userRole != 'admin') return;

    final nombre =
        inventario.data()?['nombre']?.toString() ?? 'este inventario';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar inventario'),
          content: Text(
            '¿Estás seguro de eliminar definitivamente "$nombre"?\n\n'
            'Esta acción eliminará también todo el historial de fechas '
            'y los productos registrados en este inventario.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      // Eliminar todas las fechas del inventario
      final fechasSnapshot = await inventario.reference
          .collection('fechas')
          .get();

      for (final fechaDoc in fechasSnapshot.docs) {
        // Eliminar todos los productos de esa fecha
        final productosSnapshot = await fechaDoc.reference
            .collection('productos')
            .get();

        final batch = _firestore.batch();

        for (final productoDoc in productosSnapshot.docs) {
          batch.delete(productoDoc.reference);
        }

        // Eliminar también el documento de la fecha
        batch.delete(fechaDoc.reference);

        await batch.commit();
      }

      // Finalmente eliminar el inventario
      await inventario.reference.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventario eliminado correctamente.')),
      );
    } catch (e) {
      debugPrint('Error al eliminar inventario: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar el inventario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _abrirInventario(
    QueryDocumentSnapshot<Map<String, dynamic>> inventario,
  ) {
    final data = inventario.data();

    final nombre = data['nombre']?.toString() ?? 'Inventario';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            Inventario(inventarioId: inventario.id, nombreInventario: nombre),
      ),
    );
  }

  Widget _construirInventarioCard(
    QueryDocumentSnapshot<Map<String, dynamic>> inventario,
  ) {
    final data = inventario.data();

    final nombre = data['nombre']?.toString().trim().isNotEmpty == true
        ? data['nombre'].toString().trim()
        : 'Sin nombre';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Seleccionar inventario'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_userRole == 'admin')
              IconButton(
                tooltip: 'Opciones',
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  _mostrarOpcionesInventario(inventario);
                },
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          _abrirInventario(inventario);
        },
      ),
    );
  }

  Widget _construirContenido() {
    if (_adminId == null) {
      return RefreshIndicator(
        onRefresh: _cargarDatosUsuario,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('No se pudo identificar el administrador.')),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _obtenerInventarios(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _cargarDatosUsuario,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 150),
                const Icon(Icons.error_outline, size: 55),
                const SizedBox(height: 16),
                const Center(
                  child: Text('No se pudieron cargar los inventarios.'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final inventarios = snapshot.data?.docs ?? [];

        if (inventarios.isEmpty) {
          return RefreshIndicator(
            onRefresh: _cargarDatosUsuario,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                const SizedBox(height: 100),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 20),
                const Text(
                  'No hay inventarios creados',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _userRole == 'admin'
                      ? 'Crea tu primer inventario para comenzar.'
                      : 'El administrador aún no ha creado inventarios.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _cargarDatosUsuario,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            itemCount: inventarios.length,
            itemBuilder: (context, index) {
              return _construirInventarioCard(inventarios[index]);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventarios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_userRole == 'admin')
            IconButton(
              tooltip: 'Nuevo inventario',
              icon: const Icon(Icons.add),
              onPressed: _crearInventario,
            ),
        ],
      ),
      body: _cargandoUsuario
          ? const Center(child: CircularProgressIndicator())
          : _construirContenido(),
      floatingActionButton: _userRole == 'admin'
          ? FloatingActionButton.extended(
              onPressed: _crearInventario,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo inventario'),
            )
          : null,
    );
  }
}

class _RenombrarInventarioDialog extends StatefulWidget {
  final String nombreActual;

  const _RenombrarInventarioDialog({required this.nombreActual});

  @override
  State<_RenombrarInventarioDialog> createState() =>
      _RenombrarInventarioDialogState();
}

class _RenombrarInventarioDialogState
    extends State<_RenombrarInventarioDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.nombreActual);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renombrar inventario'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 50,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            prefixIcon: Icon(Icons.edit_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final texto = value?.trim() ?? '';

            if (texto.isEmpty) {
              return 'Ingresa un nombre';
            }

            if (texto.length < 2) {
              return 'El nombre es demasiado corto';
            }

            return null;
          },
          onFieldSubmitted: (_) => _guardar(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
