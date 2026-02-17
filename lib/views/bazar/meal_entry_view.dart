import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/controllers/room_controller.dart';
import 'package:mess_manager/controllers/meal_controller.dart';
import 'package:mess_manager/models/meal_entry_model.dart';
import 'package:mess_manager/models/room_model.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class MealEntryView extends StatefulWidget {
  const MealEntryView({super.key});

  @override
  State<MealEntryView> createState() => _MealEntryViewState();
}

class _MealEntryViewState extends State<MealEntryView> {
  final authController = Get.find<AuthController>();
  final messController = Get.find<MessController>();
  final roomController = Get.find<RoomController>();
  final mealController = Get.find<MealController>();

  late DateTime _focusedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  // ── helpers ──────────────────────────────────────────

  /// Find the room whose bazar covers [`selectedDate`].
  RoomModel? _findRoomForDate(DateTime date) {
    for (final room in roomController.rooms) {
      if (room.bazarStartDate == null || room.bazarEndDate == null) continue;
      final start = _dayOnly(room.bazarStartDate!);
      final end = _dayOnly(room.bazarEndDate!);
      final d = _dayOnly(date);
      if ((d.isAtSameMomentAs(start) || d.isAfter(start)) &&
          (d.isAtSameMomentAs(end) || d.isBefore(end))) {
        return room;
      }
    }
    return null;
  }

  bool _canEditForDate(DateTime date) {
    final user = authController.currentUser.value;
    if (user == null) return false;
    if (user.isManager) return true;

    final room = _findRoomForDate(date);
    if (room == null) return false;
    return room.isBazarCurrentlyActive && room.memberIds.contains(user.uid);
  }

  MealEntryModel? _findEntryForDate(DateTime date) {
    final d = _dayOnly(date);
    for (final entry in mealController.mealEntries) {
      if (_dayOnly(entry.date).isAtSameMomentAs(d)) return entry;
    }
    return null;
  }

  bool _hasEntryOnDay(DateTime date) => _findEntryForDate(date) != null;

  static DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // ── calendar grid helpers ────────────────────────────

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    return List.generate(
      last.day,
      (i) => DateTime(first.year, first.month, i + 1),
    );
  }

  int _startWeekday(DateTime month) {
    // Monday=1 … Sunday=7 → shift so Mon=0
    return DateTime(month.year, month.month, 1).weekday - 1;
  }

  // ── build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meals')),
      body: Obx(() {
        // trigger rebuild when entries change
        mealController.mealEntries.length;
        roomController.rooms.length;

        return Column(
          children: [
            _buildCalendar(),
            const Divider(height: 1, color: AppTheme.cardColor),
            Expanded(child: _buildDetails()),
          ],
        );
      }),
    );
  }

  // ── calendar widget ──────────────────────────────────

  Widget _buildCalendar() {
    final days = _daysInMonth(_focusedMonth);
    final leadingBlanks = _startWeekday(_focusedMonth);
    final today = _dayOnly(DateTime.now());
    final now = DateTime.now();
    final minMonth = DateTime(now.year, now.month - 3);
    final maxMonth = DateTime(now.year, now.month);
    final canGoBack = _focusedMonth.isAfter(minMonth);
    final canGoForward = _focusedMonth.isBefore(maxMonth);

    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month header with arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: canGoBack
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary.withValues(alpha: 0.3),
                ),
                onPressed: canGoBack
                    ? () {
                        setState(() {
                          _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month - 1,
                          );
                        });
                      }
                    : null,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: canGoForward
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary.withValues(alpha: 0.3),
                ),
                onPressed: canGoForward
                    ? () {
                        setState(() {
                          _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month + 1,
                          );
                        });
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Weekday labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (d) => SizedBox(
                    width: 40,
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),

          // Day cells
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            children: [
              // leading blanks
              for (int i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
              // actual days
              ...days.map((day) {
                final isToday = day.isAtSameMomentAs(today);
                final isSelected =
                    _selectedDate != null &&
                    day.isAtSameMomentAs(_selectedDate!);
                final hasEntry = _hasEntryOnDay(day);
                final bazarRoom = _findRoomForDate(day);
                final isInBazar = bazarRoom != null;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = day);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : isToday
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : isInBazar
                          ? AppTheme.successColor.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && !isSelected
                          ? Border.all(color: AppTheme.primaryColor, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : isInBazar
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        if (hasEntry)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.secondaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // ── details panel (bottom half) ──────────────────────

  Widget _buildDetails() {
    if (_selectedDate == null) {
      return const Center(
        child: Text(
          'Tap a date to view meals',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final entry = _findEntryForDate(_selectedDate!);
    final canEdit = _canEditForDate(_selectedDate!);
    final members = messController.messMembers;
    final room = _findRoomForDate(_selectedDate!);

    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        children: [
          // Date header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.surfaceColor,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate!),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (room != null)
                        Text(
                          'Room ${room.roomNumber} bazar',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                if (entry != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.totalMeals} meals',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Meal list
          Expanded(
            child: entry == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_outlined,
                          size: 48,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No meal entry for this date',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        if (canEdit) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _openEditor(entry: null, room: room),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Meals'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      ...members.map((member) {
                        final count = entry.meals[member.uid] ?? 0;
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
                                radius: 18,
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.2),
                                child: Text(
                                  member.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '@${member.username}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: count > 0
                                      ? AppTheme.primaryColor.withValues(
                                          alpha: 0.15,
                                        )
                                      : AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: count > 0
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Edit button at the bottom
                      if (canEdit) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _openEditor(entry: entry, room: room),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Meals'),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── editor bottom sheet ──────────────────────────────

  void _openEditor({MealEntryModel? entry, RoomModel? room}) {
    final members = messController.messMembers;
    final meals = <String, int>{};

    if (entry != null) {
      meals.addAll(entry.meals);
    }
    for (final m in members) {
      meals.putIfAbsent(m.uid, () => 0);
    }

    Get.bottomSheet(
      _MealEditorSheet(
        members: members,
        meals: meals,
        date: _selectedDate!,
        existingEntry: entry,
        room: room,
        mealController: mealController,
        onSaved: () => setState(() {}), // refresh details
      ),
      isScrollControlled: true,
    );
  }
}

// ── editor bottom sheet widget ───────────────────────

class _MealEditorSheet extends StatefulWidget {
  final List members;
  final Map<String, int> meals;
  final DateTime date;
  final MealEntryModel? existingEntry;
  final RoomModel? room;
  final MealController mealController;
  final VoidCallback onSaved;

  const _MealEditorSheet({
    required this.members,
    required this.meals,
    required this.date,
    required this.existingEntry,
    required this.room,
    required this.mealController,
    required this.onSaved,
  });

  @override
  State<_MealEditorSheet> createState() => _MealEditorSheetState();
}

class _MealEditorSheetState extends State<_MealEditorSheet> {
  late Map<String, int> meals;

  @override
  void initState() {
    super.initState();
    meals = Map.from(widget.meals);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Row(
            children: [
              Icon(
                widget.existingEntry != null ? Icons.edit : Icons.add_circle,
                color: AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.existingEntry != null ? 'Edit Meals' : 'Add Meals',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                DateFormat('MMM dd').format(widget.date),
                style: const TextStyle(
                  color: AppTheme.secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Member counters
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.members.length,
              itemBuilder: (context, index) {
                final member = widget.members[index];
                final count = meals[member.uid] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          member.username[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '@${member.username}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      // Counter
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              iconSize: 20,
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: AppTheme.errorColor,
                              ),
                              onPressed: count > 0
                                  ? () => setState(
                                      () => meals[member.uid] = count - 1,
                                    )
                                  : null,
                            ),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '$count',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              iconSize: 20,
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: AppTheme.successColor,
                              ),
                              onPressed: () =>
                                  setState(() => meals[member.uid] = count + 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Save button
          Obx(
            () => SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: widget.mealController.isLoading.value
                    ? null
                    : () async {
                        bool success;
                        if (widget.existingEntry != null) {
                          final updated = MealEntryModel(
                            entryId: widget.existingEntry!.entryId,
                            date: widget.existingEntry!.date,
                            roomId: widget.existingEntry!.roomId,
                            meals: meals,
                            addedBy: widget.existingEntry!.addedBy,
                            createdAt: widget.existingEntry!.createdAt,
                          );
                          success = await widget.mealController.updateMealEntry(
                            updated,
                          );
                        } else {
                          success = await widget.mealController.addMealEntry(
                            roomId: widget.room?.roomId ?? '',
                            date: widget.date,
                            meals: meals,
                          );
                        }
                        if (success) {
                          widget.onSaved();
                          Get.back();
                        }
                      },
                child: widget.mealController.isLoading.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.existingEntry != null ? 'Update' : 'Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
