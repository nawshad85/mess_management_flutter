import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/controllers/room_controller.dart';
import 'package:mess_manager/controllers/bazar_controller.dart';
import 'package:mess_manager/controllers/meal_controller.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/app/routes/app_routes.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class MessDashboardView extends StatelessWidget {
  const MessDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final messController = Get.find<MessController>();
    final roomController = Get.find<RoomController>();
    final bazarController = Get.find<BazarController>();
    final mealController = Get.find<MealController>();

    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(messController.currentMess.value?.name ?? 'Dashboard'),
        ),
        actions: [
          Obx(() {
            if (authController.currentUser.value?.isManager == true) {
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.person_add_rounded),
                    onPressed: () => Get.toNamed(AppRoutes.inviteMember),
                    tooltip: 'Invite Member',
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () => Get.toNamed(AppRoutes.roomManagement),
                    tooltip: 'Manage Rooms',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.restart_alt_rounded,
                      color: AppTheme.errorColor,
                    ),
                    onPressed: () =>
                        _showResetConfirmation(context, messController),
                    tooltip: 'Reset All Entries',
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Obx(() {
              final totalCost = bazarController.totalBazarCost;
              final totalMeals = mealController.totalMeals;
              final costPerMeal = totalMeals > 0 ? totalCost / totalMeals : 0.0;

              return Row(
                children: [
                  _StatCard(
                    title: 'Total Bazar',
                    value: '৳${totalCost.toStringAsFixed(0)}',
                    icon: Icons.shopping_cart_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    title: 'Total Meals',
                    value: '$totalMeals',
                    icon: Icons.restaurant_rounded,
                    color: AppTheme.secondaryColor,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    title: 'Per Meal',
                    value: '৳${costPerMeal.toStringAsFixed(1)}',
                    icon: Icons.calculate_rounded,
                    color: AppTheme.accentColor,
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),

            // Monthly Summary shortcut
            GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.monthlySummary),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.warningColor.withValues(alpha: 0.15),
                      AppTheme.accentColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.summarize_rounded,
                        color: AppTheme.warningColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Summary',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Financial breakdown per member',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Notice Board shortcut
            GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.noticeBoard),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.15),
                      AppTheme.secondaryColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notice Board',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Announcements from the manager',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Members section
            const Text(
              'Members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              final members = messController.messMembers;
              final isManager =
                  authController.currentUser.value?.isManager == true;
              if (members.isEmpty) {
                return const Text(
                  'No members yet',
                  style: TextStyle(color: AppTheme.textSecondary),
                );
              }
              final totalCost = bazarController.totalBazarCost;
              final totalMeals = mealController.totalMeals;
              final costPerMeal = totalMeals > 0 ? totalCost / totalMeals : 0.0;

              return Column(
                children: members.map((member) {
                  final room = roomController.getUserRoom(member.uid);
                  final userMeals = mealController.getUserTotalMeals(
                    member.uid,
                  );
                  final userCost = userMeals * costPerMeal;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryColor.withValues(
                            alpha: 0.2,
                          ),
                          child: Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      member.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (member.isManager)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '👑',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                room != null
                                    ? 'Room ${room.roomNumber}'
                                    : 'Unassigned',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: room != null
                                      ? AppTheme.secondaryColor
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$userMeals meals',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '৳${userCost.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: AppTheme.warningColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (isManager && !member.isManager) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _showRemoveMemberConfirmation(
                              context,
                              messController,
                              member,
                            ),
                            tooltip: 'Remove Member',
                            icon: const Icon(
                              Icons.person_remove_rounded,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            }),

            const SizedBox(height: 24),

            // Rooms & Bazar section
            const Text(
              'Rooms & Bazar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              final rooms = roomController.rooms;
              if (rooms.isEmpty) {
                return const Text(
                  'No rooms configured',
                  style: TextStyle(color: AppTheme.textSecondary),
                );
              }
              return Column(
                children: rooms.map((room) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: room.isBazarCurrentlyActive
                          ? Border.all(color: AppTheme.successColor, width: 2)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Room ${room.roomNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${room.memberIds.length}/${room.capacity}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            if (room.isBazarCurrentlyActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '🟢 Active Now',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.successColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (room.bazarStartDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${DateFormat('MMM dd').format(room.bazarStartDate!)} - ${DateFormat('MMM dd').format(room.bazarEndDate!)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmation(
    BuildContext context,
    MessController messController,
  ) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text(
              'Reset All Entries',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete all bazar entries, meal entries, and '
          'reset all room bazar schedules.\n\nThis action cannot be undone!',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _closeDialogSafely();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              await _closeDialogSafely();
              await Future.delayed(const Duration(milliseconds: 100));
              final pin = await _askForConfirmationPin(context);
              if (pin == null) return;
              await messController.resetAllEntries(confirmationPin: pin);
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberConfirmation(
    BuildContext context,
    MessController messController,
    UserModel member,
  ) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Row(
          children: [
            Icon(Icons.person_remove_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text(
              'Remove Member',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Remove ${member.name} from this mess?\n\nThis will also unassign them from any room.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _closeDialogSafely();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              await _closeDialogSafely();
              await Future.delayed(const Duration(milliseconds: 100));
              final pin = await _askForConfirmationPin(context);
              if (pin == null) return;
              await messController.removeMember(member, confirmationPin: pin);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askForConfirmationPin(BuildContext context) async {
    final authController = Get.find<AuthController>();
    final pinController = TextEditingController();
    String? enteredPin;

    await Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Enter Confirmation PIN',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: const InputDecoration(
            hintText: 'Manager PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _closeDialogSafely();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
                authController.showSnackbar(
                  'Error',
                  'PIN must be 4 to 8 digits',
                  isError: true,
                );
                return;
              }
              enteredPin = pin;
              await _closeDialogSafely();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    await Future.delayed(const Duration(milliseconds: 120));
    pinController.dispose();
    return enteredPin;
  }

  Future<void> _closeDialogSafely() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 80));
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
