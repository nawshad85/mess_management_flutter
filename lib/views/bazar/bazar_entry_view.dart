import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/room_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/controllers/bazar_controller.dart';
import 'package:mess_manager/models/bazar_model.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class BazarEntryView extends StatefulWidget {
  const BazarEntryView({super.key});

  @override
  State<BazarEntryView> createState() => _BazarEntryViewState();
}

class _BazarEntryViewState extends State<BazarEntryView> {
  final bazarController = Get.find<BazarController>();
  final roomController = Get.find<RoomController>();
  final authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bazar')),
      body: Obx(() {
        final entries = bazarController.bazarEntries;
        final user = authController.currentUser.value;
        final activeRoom = roomController.rooms
            .where((r) => r.isActiveBazar)
            .firstOrNull;
        final canAdd =
            user != null &&
            activeRoom != null &&
            roomController.canEditBazar(user.uid, activeRoom);

        if (entries.isEmpty && !canAdd) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_basket_outlined,
                  size: 64,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No bazar entries yet',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Add entry button (shown only to authorized users)
            if (canAdd)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showAddEntryDialog(context, activeRoom.roomId),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Bazar Entry'),
                  ),
                ),
              ),
            ...entries.map(
              (entry) => _BazarEntryCard(
                entry: entry,
                members: Get.find<MessController>().messMembers,
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showAddEntryDialog(BuildContext context, String roomId) {
    final items = <BazarItem>[].obs;
    final nameController = TextEditingController();
    final costController = TextEditingController();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Bazar Entry',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Item input
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(hintText: 'Item name'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '৳ Cost'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty &&
                          costController.text.isNotEmpty) {
                        items.add(
                          BazarItem(
                            name: nameController.text,
                            cost: double.tryParse(costController.text) ?? 0,
                          ),
                        );
                        nameController.clear();
                        costController.clear();
                      }
                    },
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppTheme.primaryColor,
                      size: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Items list
              Obx(
                () => Column(
                  children: items
                      .asMap()
                      .entries
                      .map(
                        (e) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.value.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '৳${e.value.cost.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => items.removeAt(e.key),
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Total & Submit
              Obx(() {
                final total = items.fold<double>(
                  0,
                  (sum, item) => sum + item.cost,
                );
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ৳${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: items.isEmpty
                          ? null
                          : () async {
                              Get.back(); // close sheet immediately
                              await bazarController.addBazarEntry(
                                roomId: roomId,
                                date: DateTime.now(),
                                items: items.toList(),
                              );
                            },
                      child: const Text('Save'),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _BazarEntryCard extends StatelessWidget {
  final BazarModel entry;
  final List members;

  const _BazarEntryCard({required this.entry, required this.members});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('MMM dd').format(entry.date),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getUsername(entry.addedBy),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '৳${entry.totalCost.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...entry.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.circle,
                    size: 6,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                  Text(
                    '৳${item.cost.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getUsername(String uid) {
    try {
      final member = members.firstWhere((m) => m.uid == uid);
      return '@${member.username}';
    } catch (_) {
      return '';
    }
  }
}
