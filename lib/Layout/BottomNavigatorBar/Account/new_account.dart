import 'package:flutter/material.dart';

import '../../../Service/auth_service.dart';

class NewAccount extends StatefulWidget {
  final String adminId;
  const NewAccount({super.key, required this.adminId});

  @override
  State<NewAccount> createState() => _NewAccountState();
}

class _NewAccountState extends State<NewAccount> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  void _onSubmit() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String? result = await _authService.createAsistente(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        adminId: widget.adminId,
      );

      setState(() {
        _isLoading = false;
      });

      if (result == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Asistente creado con éxito')),
        );
        navigator.pop();
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Error: $result')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Agregar cuenta")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(hintText: "Nombre"),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Ingrese nombre' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(hintText: "Correo"),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Ingrese correo';
                  final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!regex.hasMatch(val)) return 'Correo inválido';
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(hintText: "Contraseña"),
                obscureText: true,
                validator: (val) => val != null && val.length < 6
                    ? 'Mínimo 6 caracteres'
                    : null,
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _onSubmit,
                      child: Text("Agregar Asistente"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
