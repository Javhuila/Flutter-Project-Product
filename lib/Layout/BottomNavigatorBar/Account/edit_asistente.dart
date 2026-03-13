import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditAsistente extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditAsistente({super.key, required this.docId, required this.data});

  @override
  State<EditAsistente> createState() => _EditAsistenteState();
}

class _EditAsistenteState extends State<EditAsistente> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
  }

  void _saveChanges() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.docId)
        .update({'name': _nameController.text.trim()});

    setState(() {
      _isSaving = false;
    });

    messenger.showSnackBar(SnackBar(content: Text('Datos actualizados')));

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Editar Asistente")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Nombre"),
                validator: (value) =>
                    value == null || value.isEmpty ? "Campo requerido" : null,
              ),
              SizedBox(height: 20),
              _isSaving
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveChanges,
                      child: Text("Guardar"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
