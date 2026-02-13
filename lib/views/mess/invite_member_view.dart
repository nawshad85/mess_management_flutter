import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/app/theme/app_theme.dart';

class InviteMemberView extends StatelessWidget {
  const InviteMemberView({super.key});

  @override
  Widget build(BuildContext context) {
    final usernameController = TextEditingController();
    final messController = Get.find<MessController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Member')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.person_add_rounded,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Invite a member',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Enter their username to send an invitation',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Username',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: usernameController,
              decoration: const InputDecoration(
                hintText: 'Enter username',
                prefixIcon: Icon(
                  Icons.alternate_email,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Obx(
              () => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: messController.isLoading.value
                      ? null
                      : () async {
                          if (usernameController.text.trim().isEmpty) {
                            Get.snackbar('Error', 'Please enter a username');
                            return;
                          }
                          final success = await messController.inviteMember(
                            usernameController.text.trim(),
                          );
                          if (success) {
                            usernameController.clear();
                          }
                        },
                  child: messController.isLoading.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send Invitation'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
