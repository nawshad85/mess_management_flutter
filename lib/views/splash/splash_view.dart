import 'package:flutter/material.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.restaurant,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Mess Manager',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            Obx(() {
              if (authController.sessionRestoreError.isEmpty) {
                return const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(
                      authController.sessionRestoreError.value,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: authController.isRestoringSession.value
                          ? null
                          : () => authController.restoreSession(),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => authController.logout(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
