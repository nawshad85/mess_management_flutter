import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/utils/validators.dart';
import 'package:mess_manager/app/routes/app_routes.dart';
import 'package:mess_manager/app/theme/app_theme.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final authController = Get.find<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Header
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_add,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join Mess Manager today',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 40),

                // Form
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: usernameController,
                        validator: Validators.validateUsername,
                        decoration: const InputDecoration(
                          hintText: 'Username',
                          prefixIcon: Icon(
                            Icons.alternate_email,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        validator: Validators.validatePassword,
                        decoration: const InputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icon(
                            Icons.lock_outlined,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        validator: (val) {
                          if (val != passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          hintText: 'Confirm Password',
                          prefixIcon: Icon(
                            Icons.lock_outlined,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Error message
                      Obx(() {
                        if (authController.errorMessage.value.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              authController.errorMessage.value,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),

                      const SizedBox(height: 24),

                      // Register Button
                      Obx(
                        () => SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: authController.isLoading.value
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      final success = await authController
                                          .register(
                                            email: emailController.text,
                                            password: passwordController.text,
                                            username: usernameController.text,
                                          );
                                      if (success) {
                                        Get.offAllNamed(AppRoutes.home);
                                      }
                                    }
                                  },
                            child: authController.isLoading.value
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Create Account'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          GestureDetector(
                            onTap: () => Get.back(),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
