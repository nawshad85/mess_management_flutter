import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/room_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/controllers/bazar_controller.dart';
import 'package:mess_manager/models/bazar_model.dart';
import 'package:mess_manager/models/user_model.dart';
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
  final messController = Get.find<MessController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bazar')),
      body: Obx(() {
        final entries = bazarController.bazarEntries.toList(growable: false);
        final members = messController.messMembers.toList(growable: false);
        final user = authController.currentUser.value;
        final now = DateTime.now();
        final currentMonthEntries = entries
            .where(
              (entry) =>
                  entry.date.year == now.year && entry.date.month == now.month,
            )
            .toList(growable: false);
        final currentMonthTotal = currentMonthEntries.fold<double>(
          0,
          (total, entry) => total + entry.totalCost,
        );
        final activeRoom = roomController.rooms
            .where((r) => r.isActiveBazar)
            .firstOrNull;
        final isManager = user?.isManager ?? false;
        final canAdd =
            user != null &&
            (isManager ||
                (activeRoom != null &&
                    roomController.canEditBazar(user.uid, activeRoom)));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCurrentMonthTotalCard(
              total: currentMonthTotal,
              entryCount: currentMonthEntries.length,
              month: now,
            ),
            const SizedBox(height: 16),

            // Add entry button (shown only to authorized users)
            if (canAdd)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddEntryDialog(
                      context,
                      activeRoom?.roomId ?? 'general',
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Bazar Entry'),
                  ),
                ),
              ),
            if (entries.isEmpty)
              _buildEmptyState()
            else
              ...entries.map((entry) {
                final canEdit =
                    user != null &&
                    roomController.canEditBazarEntry(user.uid, entry.date);
                return _BazarEntryCard(
                  entry: entry,
                  members: members,
                  canEdit: canEdit,
                  onEdit: canEdit
                      ? () => _showEditEntryDialog(context, entry)
                      : null,
                  onDelete: canEdit
                      ? () => _confirmDeleteEntry(context, entry)
                      : null,
                );
              }),
          ],
        );
      }),
    );
  }

  Widget _buildCurrentMonthTotalCard({
    required double total,
    required int entryCount,
    required DateTime month,
  }) {
    final entryLabel = entryCount == 1 ? 'entry' : 'entries';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.24),
            AppTheme.secondaryColor.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This Month\'s Bazar Cost',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateFormat('MMMM yyyy').format(month)} • $entryCount $entryLabel',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '৳${total.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 56,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'No bazar entries yet',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
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

  void _showEditEntryDialog(BuildContext context, BazarModel entry) {
    final items = <BazarItem>[...entry.items].obs;
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit Bazar Entry',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
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
                ],
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
                              final updatedEntry = BazarModel(
                                entryId: entry.entryId,
                                roomId: entry.roomId,
                                date: entry.date,
                                items: items.toList(),
                                totalCost: total,
                                addedBy: entry.addedBy,
                                createdAt: entry.createdAt,
                              );
                              await bazarController.updateBazarEntry(
                                updatedEntry,
                              );
                            },
                      child: const Text('Update'),
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

  void _confirmDeleteEntry(BuildContext context, BazarModel entry) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Delete Entry',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete the bazar entry from ${DateFormat('MMM dd').format(entry.date)}?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              await bazarController.deleteBazarEntry(entry);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _BazarEntryCard extends StatelessWidget {
  final BazarModel entry;
  final List<UserModel> members;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _BazarEntryCard({
    required this.entry,
    required this.members,
    this.canEdit = false,
    this.onEdit,
    this.onDelete,
  });

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
              Flexible(
                child: Text(
                  _getUsername(entry.addedBy),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (canEdit) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: AppTheme.errorColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
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
          const Divider(height: 16, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '৳${entry.totalCost.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getUsername(String uid) {
    try {
      final member = members.firstWhere((m) => m.uid == uid);
      return member.name;
    } catch (_) {
      return '';
    }
  }
}
