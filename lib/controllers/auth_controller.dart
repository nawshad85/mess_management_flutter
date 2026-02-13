import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/services/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Listen to Firebase auth state changes
    FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser != null) {
        // User is signed in — load their Firestore profile
        final user = await _authService.getCurrentUserModel();
        currentUser.value = user;
        // Navigate to home if on splash, login, or register
        if (Get.currentRoute == '/' ||
            Get.currentRoute == '/login' ||
            Get.currentRoute == '/register') {
          Get.offAllNamed('/home');
        }
      } else {
        // User is signed out
        currentUser.value = null;
        if (Get.currentRoute != '/login' && Get.currentRoute != '/register') {
          Get.offAllNamed('/login');
        }
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUserModel();
    currentUser.value = user;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final user = await _authService.register(
        email: email,
        password: password,
        username: username,
      );
      currentUser.value = user;
      return true;
    } catch (e) {
      errorMessage.value = _getErrorMessage(e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final user = await _authService.login(email: email, password: password);
      currentUser.value = user;
      return true;
    } catch (e) {
      errorMessage.value = _getErrorMessage(e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser.value = null;
    Get.offAllNamed('/login');
  }

  Future<void> refreshUser() async {
    await _loadCurrentUser();
  }

  String _getErrorMessage(dynamic e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use')) {
      return 'This email is already registered';
    } else if (msg.contains('wrong-password') ||
        msg.contains('invalid-credential')) {
      return 'Invalid email or password';
    } else if (msg.contains('user-not-found')) {
      return 'No account found with this email';
    } else if (msg.contains('weak-password')) {
      return 'Password is too weak';
    } else if (msg.contains('Username is already taken')) {
      return 'This username is already taken';
    }
    return 'Something went wrong. Please try again.';
  }

  void showSnackbar(String title, String message, {bool isError = false}) {
    Get.snackbar(
      title,
      message,
      backgroundColor: isError
          ? Colors.red.withValues(alpha: 0.8)
          : Colors.green.withValues(alpha: 0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }
}
