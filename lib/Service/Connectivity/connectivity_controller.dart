import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConnectivityController extends GetxController {
  final Connectivity _connectivity = Connectivity();

  var isConnected = true.obs;
  late final StreamSubscription _streamSubscription;
  bool _isDialogOpen = false;
  bool _isOnline = false;

  @override
  void onInit() {
    _checkInternetConnectivity();

    _streamSubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectionChange,
    );
    super.onInit();
  }

  Future<void> _checkInternetConnectivity() async {
    List<ConnectivityResult> connections = await _connectivity
        .checkConnectivity();

    _handleConnectionChange(connections);
  }

  void _handleConnectionChange(List<ConnectivityResult> connections) {
    if (connections.contains(ConnectivityResult.none)) {
      isConnected.value = false;
      _isOnline = false;
      _showNoInternetDialog();
    } else {
      isConnected.value = true;
      _closeDialog();
      if (_isOnline) {
        Get.snackbar(
          'Conectado',
          'Se ha restablecido la conexión a internet',
          colorText: Colors.green[800],
          backgroundColor: Colors.green[200],
          duration: const Duration(seconds: 4),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  void _showNoInternetDialog() {
    // Esta linea previene la multiplicación de la alerta
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    _isOnline = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Sin conexión"),
              const Icon(Icons.wifi_off_outlined),
            ],
          ),
          content: const Text(
            "Estás sin conexión a internet. Por favor, comprueba tu conexión.",
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton(
                onPressed: () {
                  _retryConnection();
                },
                // style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    "Reconectar",
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      // color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      ).then((_) {
        _isDialogOpen = false;
      });
    });
  }

  Future<void> _retryConnection() async {
    List<ConnectivityResult> connections = await _connectivity
        .checkConnectivity();

    if (!connections.contains(ConnectivityResult.none)) {
      isConnected.value = true;
      Get.back();
    } else {
      Get.snackbar(
        'Desconectado',
        'Por favor, revisa tu conexión a internet, nuevamente.',
        colorText: Colors.red[800],
        backgroundColor: Colors.red[200],
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _closeDialog() {
    if (_isDialogOpen) {
      Get.back();
      _isDialogOpen = false;
    }
  }

  @override
  void onClose() {
    _streamSubscription.cancel();

    _closeDialog();
    super.onClose();
  }
}
