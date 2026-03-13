import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> registerAdmin({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification(); // Envía el email de verificación
      }

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email.trim(),
        'name': name.trim(),
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Este correo ya está en uso.';
        case 'invalid-email':
          return 'Correo inválido.';
        case 'weak-password':
          return 'La contraseña es muy débil.';
        case 'operation-not-allowed':
          return 'El registro no está habilitado.';
        default:
          return 'Error al registrar: ${e.message}';
      }
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = _auth.currentUser;
      await user?.reload();

      if (user != null && !user.emailVerified) {
        await _auth.signOut(); // importante para limpiar la sesión
        return 'Debes verificar tu correo antes de iniciar sesión.';
      }

      // Guardar las credenciales en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_email', email.trim());
      await prefs.setString('admin_password', password.trim());

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No existe una cuenta con ese correo.';
        case 'wrong-password':
          return 'Contraseña incorrecta.';
        case 'invalid-email':
          return 'Correo inválido.';
        case 'user-disabled':
          return 'Esta cuenta está deshabilitada.';
        case 'too-many-requests':
          return 'Demasiados intentos. Intenta más tarde.';
        default:
          return 'Error al iniciar sesión: ${e.message}';
      }
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_email');
    await prefs.remove('admin_password');
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Future<String?> createAsistente({
    required String name,
    required String email,
    required String password,
    required String adminId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminEmail = prefs.getString('admin_email');
      final adminPassword = prefs.getString('admin_password');

      if (adminEmail == null || adminPassword == null) {
        return 'No se encontraron las credenciales del admin.';
      }

      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (!userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
      }

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email.trim(),
        'name': name.trim(),
        'role': 'asistente',
        'adminId': adminId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Cerrar sesión del asistente
      await _auth.signOut();

      // Re-iniciar sesión del admin
      await _auth.signInWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Este correo ya está en uso.';
        case 'invalid-email':
          return 'El correo proporcionado no es válido.';
        case 'weak-password':
          return 'La contraseña debe tener al menos 6 caracteres.';
        case 'operation-not-allowed':
          return 'La creación de cuentas no está habilitada.';
        default:
          return 'Error al crear la cuenta del asistente: ${e.message}';
      }
    } catch (e) {
      return 'Error inesperado al crear el asistente: $e';
    }
  }

  Future<String?> resendEmailVerification({
    required String email,
    required String password,
  }) async {
    try {
      // Iniciar sesión temporalmente
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = _auth.currentUser;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await _auth.signOut(); // Cerrar sesión después de enviar
        return null; // Éxito
      } else {
        return 'El correo ya está verificado.';
      }
    } on FirebaseAuthException catch (e) {
      return 'Error: ${e.message}';
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // éxito
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No existe una cuenta con ese correo.';
        case 'invalid-email':
          return 'Correo inválido.';
        default:
          return 'Error: ${e.message}';
      }
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }
}
