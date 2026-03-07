import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/services/auth_service.dart';
import 'package:mess_manager/services/onesignal_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  final OneSignalService _oneSignalService = OneSignalService();

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
        // Tag device in OneSignal for push notifications
        if (user != null) {
          _oneSignalService.setUserTags(
            uid: user.uid,
            messId: user.messId,
          );
        }
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
    required String name,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final user = await _authService.register(
        email: email,
        password: password,
        name: name,
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
    _oneSignalService.removeUserTags();
    await _authService.logout();
    currentUser.value = null;
    Get.offAllNamed('/login');
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      await _authService.sendPasswordResetEmail(email);
      showSnackbar(
        'Email Sent',
        'Password reset link has been sent to $email. Check your inbox.',
      );
    } catch (e) {
      errorMessage.value = _getResetErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  String _getResetErrorMessage(dynamic e) {
    final msg = e.toString();
    if (msg.contains('user-not-found')) {
      return 'No account found with this email';
    } else if (msg.contains('invalid-email')) {
      return 'Please enter a valid email address';
    }
    return 'Failed to send reset email. Please try again.';
  }

  Future<void> refreshUser() async {
    await _loadCurrentUser();
  }

  Future<bool> setManagerPin(String pin) async {
    try {
      final user = currentUser.value;
      if (user == null || !user.isManager) {
        showSnackbar(
          'Error',
          'Only mess manager can set confirmation PIN',
          isError: true,
        );
        return false;
      }

      await _authService.setManagerPin(pin);
      await refreshUser();
      showSnackbar('Success', 'Confirmation PIN saved');
      return true;
    } catch (e) {
      showSnackbar('Error', e.toString(), isError: true);
      return false;
    }
  }

  Future<bool> verifyManagerPin(String pin) async {
    try {
      final user = currentUser.value;
      if (user == null || !user.isManager) return false;
      return await _authService.verifyManagerPin(pin);
    } catch (_) {
      return false;
    }
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
