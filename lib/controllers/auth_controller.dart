import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/services/auth_service.dart';
import 'package:mess_manager/services/onesignal_service.dart';
import 'package:mess_manager/app/routes/app_routes.dart';

class AuthController extends GetxController {
  AuthController({AuthService? authService, OneSignalService? oneSignalService})
    : _authService = authService ?? AuthService(),
      _oneSignalService = oneSignalService ?? OneSignalService();

  final AuthService _authService;
  final OneSignalService _oneSignalService;
  StreamSubscription<User?>? _authSubscription;
  int _sessionGeneration = 0;
  bool _navigationReady = false;
  String? _pendingRoute;

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool hasResolvedInitialAuthState = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString sessionRestoreError = ''.obs;
  final RxBool isRestoringSession = true.obs;

  @override
  void onInit() {
    super.onInit();
    // The SDK restores its native session. Wait for its first event instead of
    // treating the controller's initially empty profile as a signed-out user.
    _authSubscription = _authService.authStateChanges.listen(
      (_) => unawaited(restoreSession()),
      onError: (Object error) {
        sessionRestoreError.value =
            'Unable to restore your session. Please retry.';
        isRestoringSession.value = false;
        hasResolvedInitialAuthState.value = true;
        _routeTo(AppRoutes.splash);
      },
    );
  }

  @override
  void onReady() {
    super.onReady();
    _navigationReady = true;
    final route = _pendingRoute;
    _pendingRoute = null;
    if (route != null) _routeTo(route);
  }

  void _routeTo(String route) {
    if (!_navigationReady) {
      _pendingRoute = route;
      return;
    }
    final current = Get.currentRoute;
    if (route == AppRoutes.home &&
        !const [
          '',
          AppRoutes.splash,
          AppRoutes.login,
          AppRoutes.register,
          AppRoutes.emailVerification,
        ].contains(current)) {
      return;
    }
    if (current == AppRoutes.register &&
        (route == AppRoutes.login || route == AppRoutes.emailVerification)) {
      return;
    }
    if (current != route) Get.offAllNamed(route);
  }

  Future<void> restoreSession({UserModel? knownProfile}) async {
    final generation = ++_sessionGeneration;
    final firebaseUser = _authService.currentUser;
    isRestoringSession.value = true;
    sessionRestoreError.value = '';
    try {
      if (firebaseUser == null) {
        currentUser.value = null;
        _routeTo(AppRoutes.login);
        return;
      }
      if (currentUser.value?.uid != firebaseUser.uid) currentUser.value = null;
      if (!firebaseUser.emailVerified) {
        // A saved User may still have the pre-verification flag. Refresh it
        // without discarding the signed-in session, including when offline.
        try {
          await firebaseUser.reload();
        } catch (_) {
          // Retain the cached verification state if the network is unavailable.
        }
        if (!_isCurrentSession(generation, firebaseUser.uid)) return;
        if (_authService.currentUser?.emailVerified != true) {
          currentUser.value = null;
          _routeTo(AppRoutes.emailVerification);
          return;
        }
      }
      final user = knownProfile ?? await _authService.getCurrentUserModel();
      if (!_isCurrentSession(generation, firebaseUser.uid)) return;
      if (user == null || user.uid != firebaseUser.uid) {
        throw StateError('The signed-in account profile is unavailable');
      }
      currentUser.value = user;
      _routeTo(AppRoutes.home);
      // Notification setup must never prevent restoring an authenticated UI.
      unawaited(_tagUser(user));
    } catch (error) {
      if (!_isCurrentSession(generation, firebaseUser?.uid)) return;
      sessionRestoreError.value =
          'You are still signed in, but your profile could not be loaded. '
          'Check your connection and retry.';
      _routeTo(AppRoutes.splash);
      debugPrint('Session profile restoration failed (${error.runtimeType}).');
    } finally {
      if (generation == _sessionGeneration) {
        isRestoringSession.value = false;
        hasResolvedInitialAuthState.value = true;
      }
    }
  }

  bool _isCurrentSession(int generation, String? uid) =>
      generation == _sessionGeneration && _authService.currentUser?.uid == uid;

  Future<void> _tagUser(UserModel user) async {
    try {
      await _oneSignalService.setUserTags(uid: user.uid, messId: user.messId);
    } catch (_) {
      debugPrint('Notification tags could not be refreshed.');
    }
  }

  @override
  void onClose() {
    ++_sessionGeneration;
    unawaited(_authSubscription?.cancel() ?? Future<void>.value());
    super.onClose();
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

      await _authService.register(email: email, password: password, name: name);

      // Send verification email
      await _authService.sendVerificationEmail();

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
      await restoreSession(knownProfile: user);
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
    _routeTo(AppRoutes.login);
    try {
      await _oneSignalService.removeUserTags();
    } catch (_) {
      debugPrint('Notification tags could not be cleared.');
    }
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
