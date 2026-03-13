import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Auth/sign_up.dart';
import 'package:flutter_project_product/Layout/ini_layout.dart';

import '../Service/auth_service.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool isPasswordHidden = true;

  bool _showResendVerification = false;
  String _unverifiedEmail = '';
  String _unverifiedPassword = '';

  Timer? _resendTimer;
  int _resendCountdown = 0;

  void _startResendCountdown() {
    const int waitSeconds = 60;

    setState(() {
      _resendCountdown = waitSeconds;
    });

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  void _login() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _showResendVerification = false;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final errorMessage = await _authService.login(
        email: email,
        password: password,
      );

      if (errorMessage == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Inicio de sesión con éxito")),
        );
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const IniLayout()),
        );
      } else {
        if (errorMessage.contains('verificar tu correo')) {
          if (!mounted) return;

          setState(() {
            _showResendVerification = true;
            _unverifiedEmail = email;
            _unverifiedPassword = password;
          });
        }

        messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resendVerificationEmail() async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
    });

    final errorMessage = await _authService.resendEmailVerification(
      email: _unverifiedEmail,
      password: _unverifiedPassword,
    );

    if (errorMessage == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Correo de verificación reenviado.")),
      );
      _startResendCountdown();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showResetPasswordDialog() {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Recuperar contraseña"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Ingresa tu correo y recibirás un enlace para restablecer tu contraseña.",
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Correo electrónico",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => navigator.pop(),
            ),
            ElevatedButton(
              child: const Text("Enviar"),
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty ||
                    !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Correo inválido")),
                  );
                  return;
                }

                navigator.pop(); // Cierra el diálogo

                setState(() {
                  _isLoading = true;
                });

                final errorMessage = await _authService.sendPasswordResetEmail(
                  email,
                );

                if (errorMessage == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Correo de recuperación enviado."),
                    ),
                  );
                } else {
                  messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
                }

                setState(() {
                  _isLoading = false;
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _verificarManualmente() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Autenticación directa, sin pasar por AuthService
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await user.reload();

        messenger.showSnackBar(
          const SnackBar(content: Text("Correo de verificación enviado.")),
        );

        // NO navegar automáticamente si aún no está verificado
        // Esperas que el usuario confirme el correo manualmente
      } else if (user != null && user.emailVerified) {
        // Ya estaba verificado, ir a la app directamente
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const IniLayout()),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Image.asset("images/3094352.jpg"),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu correo';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Correo inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: isPasswordHidden,
                    decoration: InputDecoration(
                      labelText: 'Contrasena',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            isPasswordHidden = !isPasswordHidden;
                          });
                        },
                        icon: Icon(
                          isPasswordHidden
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_emailController.text.trim() ==
                      'valbuenahuila123@gmail.com')
                    ElevatedButton(
                      onPressed: _verificarManualmente,
                      child: const Text("Verificar manualmente esta cuenta"),
                    ),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _login();
                              }
                            },
                            child: const Text('Iniciar sesion'),
                          ),
                        ),
                  const SizedBox(height: 16),

                  if (_showResendVerification)
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          "¿No recibiste el correo de verificación?",
                          style: TextStyle(fontSize: 16),
                        ),
                        if (_resendCountdown > 0)
                          Text(
                            'Espera $_resendCountdown segundos para reenviar',
                            style: const TextStyle(color: Colors.grey),
                          )
                        else
                          TextButton(
                            onPressed: _resendVerificationEmail,
                            child: const Text(
                              "Reenviar correo de verificación",
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 5,
                      children: [
                        const Text(
                          "No tienes una cuenta? ",
                          style: TextStyle(fontSize: 18),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const SignUp()),
                            );
                          },
                          child: const Text(
                            "Registrate aqui",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showResetPasswordDialog();
                      },
                      child: const Text(
                        "¿Olvidaste tu contraseña?",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
