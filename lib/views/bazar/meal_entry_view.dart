import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/controllers/room_controller.dart';
import 'package:mess_manager/controllers/meal_controller.dart';
import 'package:mess_manager/models/meal_entry_model.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class MealEntryView extends StatelessWidget {
  const MealEntryView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final messController = Get.find<MessController>();
    final roomController = Get.find<RoomController>();
    final mealController = Get.find<MealController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Meal Entry')),
      body: Obx(() {
        final user = authController.currentUser.value;
        if (user == null) return const SizedBox.shrink();

        final activeRoom = roomController.rooms
            .where((r) => r.isActiveBazar)
            .firstOrNull;

        if (activeRoom == null) {
          return const Center(
            child: Text(
              'No active bazar period',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        if (!roomController.canEditBazar(user.uid, activeRoom)) {
          return const Center(
            child: Text(
              'You don\'t have permission to edit meals right now',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        final members = messController.messMembers;

        return _MealForm(
          members: members,
          roomId: activeRoom.roomId,
          bazarStartDate: activeRoom.bazarStartDate!,
          bazarEndDate: activeRoom.bazarEndDate!,
          mealController: mealController,
        );
      }),
    );
  }
}

class _MealForm extends StatefulWidget {
  final List members;
  final String roomId;
  final DateTime bazarStartDate;
  final DateTime bazarEndDate;
  final MealController mealController;

  const _MealForm({
    required this.members,
    required this.roomId,
    required this.bazarStartDate,
    required this.bazarEndDate,
    required this.mealController,
  });

  @override
  State<_MealForm> createState() => _MealFormState();
}

class _MealFormState extends State<_MealForm> {
  late Map<String, int> meals;
  late DateTime selectedDate;
  MealEntryModel? existingEntry; // non-null means we're editing

  @override
  void initState() {
    super.initState();
    // Default to today if within range, otherwise bazar end date
    final now = DateTime.now();
    if (now.isAfter(widget.bazarStartDate) &&
        now.isBefore(widget.bazarEndDate.add(const Duration(days: 1)))) {
      selectedDate = DateTime(now.year, now.month, now.day);
    } else {
      selectedDate = DateTime(
        widget.bazarEndDate.year,
        widget.bazarEndDate.month,
        widget.bazarEndDate.day,
      );
    }
    _initMealsForDate();
  }

  void _initMealsForDate() {
    // Look for existing entry on selected date
    existingEntry = _findExistingEntry();

    if (existingEntry != null) {
      // Pre-fill with existing data
      meals = Map.from(existingEntry!.meals);
      // Ensure all members have an entry
      for (final m in widget.members) {
        meals.putIfAbsent(m.uid, () => 0);
      }
    } else {
      // Fresh entry — all members start at 0
      meals = {};
      for (final m in widget.members) {
        meals[m.uid] = 0;
      }
    }
  }

  MealEntryModel? _findExistingEntry() {
    final entries = widget.mealController.mealEntries;
    for (final entry in entries) {
      final entryDate = DateTime(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      if (entryDate.isAtSameMomentAs(selectedDate) &&
          entry.roomId == widget.roomId) {
        return entry;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editing indicator
          if (existingEntry != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note,
                    color: AppTheme.secondaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Editing existing entry for this date',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Date picker — restricted to bazar range
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: widget.bazarStartDate,
                lastDate: widget.bazarEndDate,
                helpText: 'Select date within bazar period',
              );
              if (date != null) {
                setState(() {
                  selectedDate = DateTime(date.year, date.month, date.day);
                  _initMealsForDate();
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMM dd, yyyy').format(selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bazar: ${DateFormat('MMM dd').format(widget.bazarStartDate)} — ${DateFormat('MMM dd').format(widget.bazarEndDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Meals per Person',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Member meal counters
          ...widget.members.map((member) {
            final count = meals[member.uid] ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
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
                      member.username[0].toUpperCase(),
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
                        Text(
                          '@${member.username}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (count > 0)
                          Text(
                            '$count meal${count > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Meal counter
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: AppTheme.errorColor,
                          ),
                          onPressed: count > 0
                              ? () {
                                  setState(() {
                                    meals[member.uid] = count - 1;
                                  });
                                }
                              : null,
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: AppTheme.successColor,
                          ),
                          onPressed: () {
                            setState(() {
                              meals[member.uid] = count + 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          // Save button
          Obx(
            () => SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: widget.mealController.isLoading.value
                    ? null
                    : () async {
                        bool success;
                        if (existingEntry != null) {
                          // Update existing entry
                          final updated = MealEntryModel(
                            entryId: existingEntry!.entryId,
                            date: existingEntry!.date,
                            roomId: existingEntry!.roomId,
                            meals: meals,
                            addedBy: existingEntry!.addedBy,
                            createdAt: existingEntry!.createdAt,
                          );
                          success = await widget.mealController.updateMealEntry(
                            updated,
                          );
                        } else {
                          // Create new entry
                          success = await widget.mealController.addMealEntry(
                            roomId: widget.roomId,
                            date: selectedDate,
                            meals: meals,
                          );
                        }
                        if (success) Get.back();
                      },
                child: widget.mealController.isLoading.value
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        existingEntry != null
                            ? 'Update Meal Entry'
                            : 'Save Meal Entry',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
