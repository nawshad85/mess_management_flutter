import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/app/theme/app_theme.dart';

class InviteMemberView extends StatelessWidget {
  const InviteMemberView({super.key});

  @override
  Widget build(BuildContext context) {
    final idController = TextEditingController();
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
                    'Enter their Unique ID to send an invitation.\nThey can find it on their Profile page.',
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
              'Member Unique ID',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: idController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. A3F7K9X2',
                prefixIcon: Icon(
                  Icons.fingerprint_rounded,
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
                          if (idController.text.trim().isEmpty) {
                            Get.snackbar('Error', 'Please enter a Unique ID');
                            return;
                          }
                          final success = await messController.inviteMember(
                            idController.text.trim(),
                          );
                          if (success) {
                            idController.clear();
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
