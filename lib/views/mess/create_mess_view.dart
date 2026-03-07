import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:mess_manager/utils/validators.dart';
import 'package:mess_manager/utils/constants.dart';

class CreateMessView extends StatefulWidget {
  const CreateMessView({super.key});

  @override
  State<CreateMessView> createState() => _CreateMessViewState();
}

class _CreateMessViewState extends State<CreateMessView> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final messController = Get.find<MessController>();

  int roomCount = 2;
  List<int> roomCapacities = [2, 2];

  void _updateRoomCount(int count) {
    if (count < AppConstants.minRooms || count > AppConstants.maxRooms) return;
    setState(() {
      roomCount = count;
      if (roomCapacities.length < count) {
        roomCapacities.addAll(List.filled(count - roomCapacities.length, 2));
      } else {
        roomCapacities = roomCapacities.sublist(0, count);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Mess')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.2),
                      AppTheme.secondaryColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.home_work_rounded,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Set up your mess',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You will be the mess manager',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Mess name
              const Text(
                'Mess Name',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameController,
                validator: Validators.validateMessName,
                decoration: const InputDecoration(
                  hintText: 'e.g. Aftab Nagar Mess',
                  prefixIcon: Icon(
                    Icons.badge_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Number of rooms
              const Text(
                'Number of Rooms',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: roomCount > AppConstants.minRooms
                          ? () => _updateRoomCount(roomCount - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$roomCount',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: roomCount < AppConstants.maxRooms
                          ? () => _updateRoomCount(roomCount + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Room capacities
              const Text(
                'People per Room',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(roomCount, (index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Room ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed:
                            roomCapacities[index] >
                                AppConstants.minPeoplePerRoom
                            ? () {
                                setState(() {
                                  roomCapacities[index]--;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 22),
                        color: AppTheme.secondaryColor,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                      Container(
                        width: 36,
                        alignment: Alignment.center,
                        child: Text(
                          '${roomCapacities[index]}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            roomCapacities[index] <
                                AppConstants.maxPeoplePerRoom
                            ? () {
                                setState(() {
                                  roomCapacities[index]++;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        color: AppTheme.secondaryColor,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 32),

              // Create button
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: messController.isLoading.value
                        ? null
                        : () async {
                            if (formKey.currentState!.validate()) {
                              final success = await messController.createMess(
                                name: nameController.text,
                                roomCount: roomCount,
                                roomCapacities: roomCapacities,
                              );
                              if (success) {
                                Get.back();
                              }
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
                        : const Text('Create Mess'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
