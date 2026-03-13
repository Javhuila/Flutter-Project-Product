import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project_product/Layout/BottomNavigatorBar/Account/edit_asistente.dart';
import 'package:flutter_project_product/Layout/BottomNavigatorBar/Account/new_account.dart';

class ListAsistente extends StatefulWidget {
  const ListAsistente({super.key});

  @override
  State<ListAsistente> createState() => _ListAsistenteState();
}

class _ListAsistenteState extends State<ListAsistente> {
  final String adminId = FirebaseAuth.instance.currentUser!.uid;
  final int _limit = 4;
  DocumentSnapshot? _firstDoc;
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasNext = true;
  bool _hasPrevious = false;
  List<DocumentSnapshot> _asistentes = [];
  final List<DocumentSnapshot> _pageStack = [];

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  void initState() {
    super.initState();
    _loadAsistentes();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadAsistentes();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAsistentes({bool isNext = true}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'asistente')
        .where('adminId', isEqualTo: adminId)
        .orderBy('createdAt', descending: true)
        .limit(_limit);

    if (isNext && _lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    } else if (!isNext && _pageStack.isNotEmpty) {
      query = query.startAtDocument(_pageStack.last);
    }

    QuerySnapshot snapshot = await query.get();

    if (!isNext && _pageStack.isNotEmpty) {
      _pageStack.removeLast();
    }

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _asistentes = snapshot.docs;
        _lastDoc = snapshot.docs.last;
        _firstDoc = snapshot.docs.first;

        if (isNext) _pageStack.add(_firstDoc!);

        _hasNext = snapshot.docs.length == _limit;
        _hasPrevious = _pageStack.length > 1;
      });
    } else {
      setState(() {
        _hasNext = false;
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _refreshList() async {
    _pageStack.clear();
    _lastDoc = null;
    await _loadAsistentes();
  }

  List<DocumentSnapshot> get _filteredAsistentes {
    if (_searchText.isEmpty) return _asistentes;
    return _asistentes.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchText.toLowerCase()) ||
          email.contains(_searchText.toLowerCase());
    }).toList();
  }

  void _deleteAsistente(String docId) async {
    final messenger = ScaffoldMessenger.of(context);
    await FirebaseFirestore.instance.collection('users').doc(docId).delete();
    setState(() {
      _asistentes.removeWhere((doc) => doc.id == docId);
    });

    messenger.showSnackBar(
      const SnackBar(content: Text('Asistente eliminado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Asistentes'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewAccount(
                    adminId: FirebaseAuth.instance.currentUser!.uid,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_add),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o correo',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchText = val;
                });
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _filteredAsistentes.isEmpty
          ? Center(child: Text('No hay asistentes'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredAsistentes.length,
                    itemBuilder: (context, index) {
                      final doc = _filteredAsistentes[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return ListTile(
                        title: Text(data['name'] ?? 'Sin nombre'),
                        subtitle: Text(data['email'] ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditAsistente(
                                      docId: doc.id,
                                      data: data,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteAsistente(doc.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _hasPrevious
                            ? () => _loadAsistentes(isNext: false)
                            : null,
                        icon: Icon(Icons.arrow_back),
                        label: Text('Anterior'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _hasNext
                            ? () => _loadAsistentes(isNext: true)
                            : null,
                        icon: Icon(Icons.arrow_forward),
                        label: Text('Siguiente'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshList,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
