import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/controllers/room_controller.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class RoomManagementView extends StatelessWidget {
  const RoomManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final messController = Get.find<MessController>();
    final roomController = Get.find<RoomController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Room Management')),
      body: Obx(() {
        final rooms = roomController.rooms;
        final members = messController.messMembers;
        final isManager = authController.currentUser.value?.isManager ?? false;

        if (!isManager) {
          return const Center(
            child: Text(
              'Only the mess manager can manage rooms',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unassigned members
              _buildUnassignedMembers(members, rooms),
              const SizedBox(height: 24),

              // Rooms
              ...rooms.map(
                (room) => _RoomCard(
                  room: room,
                  members: members,
                  roomController: roomController,
                  messController: messController,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildUnassignedMembers(List members, List rooms) {
    final assignedIds = <String>{};
    for (final room in rooms) {
      assignedIds.addAll(room.memberIds);
    }

    final unassigned = members
        .where((m) => !assignedIds.contains(m.uid))
        .toList();

    if (unassigned.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unassigned Members',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.warningColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: unassigned
              .map(
                (m) => Chip(
                  avatar: CircleAvatar(
                    backgroundColor: AppTheme.warningColor.withValues(
                      alpha: 0.3,
                    ),
                    child: Text(
                      m.username[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                  label: Text('@${m.username}'),
                  backgroundColor: AppTheme.cardColor,
                  labelStyle: const TextStyle(color: AppTheme.textPrimary),
                  side: BorderSide(
                    color: AppTheme.warningColor.withValues(alpha: 0.3),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  final dynamic room;
  final List members;
  final RoomController roomController;
  final MessController messController;

  const _RoomCard({
    required this.room,
    required this.members,
    required this.roomController,
    required this.messController,
  });

  @override
  Widget build(BuildContext context) {
    final roomMembers = members
        .where((m) => room.memberIds.contains(m.uid))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
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
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Room ${room.roomNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${room.memberIds.length}/${room.capacity}',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Room members
          if (roomMembers.isEmpty)
            const Text(
              'No members assigned',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            )
          else
            ...roomMembers.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '@${m.username}',
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Assign member button
          if (!room.isFull)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAssignDialog(context),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Assign Member'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),

          const Divider(height: 24),

          // Bazar schedule
          Row(
            children: [
              const Text(
                'Bazar Schedule',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showDatePicker(context),
                child: const Text('Set Dates'),
              ),
            ],
          ),
          if (room.bazarStartDate != null)
            Text(
              '${DateFormat('MMM dd, yyyy').format(room.bazarStartDate!)} → ${DateFormat('MMM dd, yyyy').format(room.bazarEndDate!)}',
              style: TextStyle(
                color: room.isActiveBazar
                    ? AppTheme.successColor
                    : AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  void _showAssignDialog(BuildContext context) {
    // Find unassigned members
    final allRooms = roomController.rooms;
    final assignedIds = <String>{};
    for (final r in allRooms) {
      assignedIds.addAll(r.memberIds);
    }
    final unassigned = members
        .where((m) => !assignedIds.contains(m.uid))
        .toList();

    if (unassigned.isEmpty) {
      Get.snackbar('Info', 'All members are already assigned to rooms');
      return;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Member',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...unassigned.map(
              (m) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  child: Text(
                    m.username[0].toUpperCase(),
                    style: const TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
                title: Text(
                  '@${m.username}',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () async {
                  Get.back();
                  await roomController.assignMemberToRoom(
                    roomId: room.roomId,
                    userId: m.uid,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final startDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select bazar START date',
    );

    if (startDate == null) return;

    final endDate = await showDatePicker(
      context: context,
      initialDate: startDate.add(const Duration(days: 7)),
      firstDate: startDate,
      lastDate: startDate.add(const Duration(days: 365)),
      helpText: 'Select bazar END date',
    );

    if (endDate == null) return;

    await roomController.setBazarSchedule(
      roomId: room.roomId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
