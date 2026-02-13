import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/app/routes/app_routes.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:mess_manager/views/mess/mess_dashboard_view.dart';
import 'package:mess_manager/views/bazar/bazar_entry_view.dart';
import 'package:mess_manager/views/bazar/meal_entry_view.dart';
import 'package:mess_manager/views/chat/chat_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final messController = Get.find<MessController>();
    final currentIndex = 0.obs;

    return Obx(() {
      final user = authController.currentUser.value;
      final hasMess = user?.hasMess ?? false;

      // If user has no mess, show the "no mess" screen
      if (!hasMess) {
        return _NoMessView(
          authController: authController,
          messController: messController,
        );
      }

      // User has a mess — show main app with bottom nav
      final pages = [
        const MessDashboardView(),
        const BazarEntryView(),
        const MealEntryView(),
        const ChatView(),
        _ProfileView(authController: authController),
      ];

      return Scaffold(
        body: Obx(() => pages[currentIndex.value]),
        bottomNavigationBar: Obx(
          () => Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex.value,
              onTap: (i) => currentIndex.value = i,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_basket_rounded),
                  label: 'Bazar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.restaurant_rounded),
                  label: 'Meals',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_rounded),
                  label: 'Chat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// Shown when user hasn't joined a mess yet
class _NoMessView extends StatelessWidget {
  final AuthController authController;
  final MessController messController;

  const _NoMessView({
    required this.authController,
    required this.messController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => authController.logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Pending invitations
            Obx(() {
              final invites = messController.pendingInvites;
              if (invites.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📩 Pending Invitations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...invites.map(
                    (invite) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invite['messName'] ?? 'Mess',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'From: ${invite['fromUsername']}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => messController.acceptInvitation(
                              invite['inviteId'],
                            ),
                            icon: const Icon(
                              Icons.check_circle,
                              color: AppTheme.successColor,
                              size: 32,
                            ),
                          ),
                          IconButton(
                            onPressed: () => messController.declineInvitation(
                              invite['inviteId'],
                            ),
                            icon: const Icon(
                              Icons.cancel,
                              color: AppTheme.errorColor,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }),

            // Main actions
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        size: 50,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "You're not in a mess yet",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a new mess or wait for an invitation',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Get.toNamed(AppRoutes.createMess),
                        icon: const Icon(Icons.add),
                        label: const Text('Create a Mess'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple profile tab
class _ProfileView extends StatelessWidget {
  final AuthController authController;

  const _ProfileView({required this.authController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Obx(() {
        final user = authController.currentUser.value;
        if (user == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                child: Text(
                  user.username[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '@${user.username}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: user.isManager
                      ? AppTheme.warningColor.withValues(alpha: 0.2)
                      : AppTheme.secondaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.isManager ? '👑 Mess Manager' : '👤 Member',
                  style: TextStyle(
                    color: user.isManager
                        ? AppTheme.warningColor
                        : AppTheme.secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => authController.logout(),
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppTheme.errorColor,
                  ),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }
}
