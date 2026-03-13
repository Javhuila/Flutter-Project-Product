import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_product/Auth/login.dart';
import 'package:flutter_project_product/Layout/ini_layout.dart';
import 'package:flutter_project_product/Service/Connectivity/connectivity_controller.dart';
import 'package:get/get.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final ConnectivityController connectivityController;

  @override
  void initState() {
    super.initState();
    // Inicializa el controlador después de las splash
    connectivityController = Get.put(ConnectivityController());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const IniLayout();
        }

        return const Login();
      },
    );
  }
}
