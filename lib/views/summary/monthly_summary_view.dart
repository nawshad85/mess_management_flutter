import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/controllers/summary_controller.dart';
import 'package:mess_manager/models/monthly_summary_model.dart';
import 'package:mess_manager/app/theme/app_theme.dart';

class MonthlySummaryView extends StatefulWidget {
  const MonthlySummaryView({super.key});

  @override
  State<MonthlySummaryView> createState() => _MonthlySummaryViewState();
}

class _MonthlySummaryViewState extends State<MonthlySummaryView> {
  final summaryController = Get.find<SummaryController>();
  final authController = Get.find<AuthController>();
  final messController = Get.find<MessController>();

  late List<DateTime> _months;
  int _selectedMonthIdx = 0;

  /// Text controllers for per-member fund input (manager only).
  final Map<String, TextEditingController> _fundControllers = {};

  /// Fixed meal minimum state.
  bool _fixedMealEnabled = false;
  final TextEditingController _fixedMealController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = List.generate(3, (i) => DateTime(now.year, now.month - i));
    _loadCurrentMonth();
  }

  @override
  void dispose() {
    for (final c in _fundControllers.values) {
      c.dispose();
    }
    _fixedMealController.dispose();
    super.dispose();
  }

  DateTime get _selectedMonth => _months[_selectedMonthIdx];

  void _loadCurrentMonth() {
    summaryController.loadSummary(_selectedMonth.year, _selectedMonth.month);
    summaryController.loadDeposits(_selectedMonth.year, _selectedMonth.month);
  }

  void _syncFundControllers() {
    final members = messController.messMembers;
    final deposits = summaryController.currentDeposits;
    final existing = summaryController.currentSummary.value;

    for (final m in members) {
      if (!_fundControllers.containsKey(m.uid)) {
        _fundControllers[m.uid] = TextEditingController();
      }
      // Pre-fill: prioritize saved deposits, then fall back to summary
      if (_fundControllers[m.uid]!.text.isEmpty) {
        if (deposits.containsKey(m.uid)) {
          _fundControllers[m.uid]!.text = deposits[m.uid]!.toStringAsFixed(0);
        } else {
          final ms = existing?.members.where((s) => s.uid == m.uid).firstOrNull;
          if (ms != null) {
            _fundControllers[m.uid]!.text = ms.moneyPutIn.toStringAsFixed(0);
          }
        }
      }
    }
    // Sync fixed meal from existing summary
    if (existing?.fixedMeal != null && _fixedMealController.text.isEmpty) {
      _fixedMealEnabled = true;
      _fixedMealController.text = '${existing!.fixedMeal}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Summary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: Obx(() {
              if (summaryController.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                );
              }

              final summary = summaryController.currentSummary.value;
              final isManager =
                  authController.currentUser.value?.isManager ?? false;

              // Always sync controllers for manager
              if (isManager) _syncFundControllers();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fund entry section (manager only)
                    if (isManager) _buildFundEntrySection(summary),

                    // Deposit info for non-managers (when no summary yet)
                    if (!isManager && summary == null)
                      _buildDepositInfoForMembers(),

                    // Summary content
                    if (summary != null) ...[
                      _buildOverviewCard(summary),
                      const SizedBox(height: 16),
                      const Text(
                        'Member Breakdown',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTable(summary),
                      const SizedBox(height: 16),
                      _buildGeneratedInfo(summary),
                    ] else if (!isManager) ...[
                      // Non-manager sees empty state
                      _buildNoSummary(),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Month selector ──────────────────────────────────

  Widget _buildMonthSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.surfaceColor,
      child: Row(
        children: List.generate(_months.length, (i) {
          final m = _months[i];
          final selected = i == _selectedMonthIdx;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedMonthIdx = i);
                // Clear fund controller texts so they re-fill from new summary
                for (final c in _fundControllers.values) {
                  c.clear();
                }
                _fixedMealController.clear();
                _fixedMealEnabled = false;
                _loadCurrentMonth();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryColor : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: selected
                      ? null
                      : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM').format(m),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? Colors.white70
                            : AppTheme.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Fund entry section (manager only) ───────────────

  Widget _buildFundEntrySection(MonthlySummaryModel? summary) {
    final members = messController.messMembers;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.warningColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member Funds',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Enter how much each member put in',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Month badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('MMM yy').format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Per-member fund inputs
          ...members.map((member) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.15,
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
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _fundControllers[member.uid],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: '৳ 0',
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          fontWeight: FontWeight.normal,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Fixed meal box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _fixedMealEnabled
                    ? AppTheme.accentColor.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lock_clock_rounded,
                      color: AppTheme.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Fixed Meal Minimum',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Switch(
                      value: _fixedMealEnabled,
                      activeColor: AppTheme.accentColor,
                      onChanged: (v) => setState(() => _fixedMealEnabled = v),
                    ),
                  ],
                ),
                if (_fixedMealEnabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 28),
                      const Expanded(
                        child: Text(
                          'Members with fewer meals will be counted at this minimum',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _fixedMealController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentColor,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. 20',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.4,
                              ),
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Save Deposits button (save anytime without generating)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final moneyMap = <String, double>{};
                for (final entry in _fundControllers.entries) {
                  moneyMap[entry.key] = double.tryParse(entry.value.text) ?? 0;
                }
                await summaryController.saveDeposits(
                  year: _selectedMonth.year,
                  month: _selectedMonth.month,
                  deposits: moneyMap,
                );
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text(
                'Save Deposits',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.secondaryColor,
                side: const BorderSide(color: AppTheme.secondaryColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Generate / Regenerate button
          Obx(
            () => SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: summaryController.isLoading.value
                    ? null
                    : () async {
                        final moneyMap = <String, double>{};
                        for (final entry in _fundControllers.entries) {
                          moneyMap[entry.key] =
                              double.tryParse(entry.value.text) ?? 0;
                        }
                        int? fixedMeal;
                        if (_fixedMealEnabled) {
                          fixedMeal = int.tryParse(_fixedMealController.text);
                        }
                        await summaryController.generateSummary(
                          year: _selectedMonth.year,
                          month: _selectedMonth.month,
                          moneyPutIn: moneyMap,
                          fixedMeal: fixedMeal,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: summaryController.isLoading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        summary == null
                            ? Icons.auto_awesome_rounded
                            : Icons.refresh_rounded,
                        size: 20,
                      ),
                label: Text(
                  summaryController.isLoading.value
                      ? 'Generating...'
                      : summary == null
                      ? 'Generate Summary'
                      : 'Regenerate Summary',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── No summary state (non-manager) ──────────────────

  Widget _buildNoSummary() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.summarize_outlined,
              size: 56,
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No summary for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The manager has not generated a summary for this month yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Deposit info for non-managers ──────────────────

  Widget _buildDepositInfoForMembers() {
    return Obx(() {
      final deposits = summaryController.currentDeposits;
      if (deposits.isEmpty) return const SizedBox.shrink();

      final currentUid = authController.currentUser.value?.uid;
      final myDeposit = deposits[currentUid] ?? 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.secondaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppTheme.secondaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Your Deposit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '৳${myDeposit.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'This is the amount recorded by the manager for this month',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    });
  }

  // ── Overview card ───────────────────────────────────

  Widget _buildOverviewCard(MonthlySummaryModel summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.2),
            AppTheme.secondaryColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _overviewTile(
            'Total Bazar',
            '৳${summary.totalBazarCost.toStringAsFixed(0)}',
            AppTheme.primaryColor,
          ),
          _vDivider(),
          _overviewTile(
            'Total Meals',
            '${summary.totalMeals}',
            AppTheme.secondaryColor,
          ),
          _vDivider(),
          _overviewTile(
            'Per Meal',
            '৳${summary.costPerMeal.toStringAsFixed(1)}',
            AppTheme.warningColor,
          ),
        ],
      ),
    );
  }

  Widget _overviewTile(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 36,
    color: Colors.white.withValues(alpha: 0.08),
  );

  // ── Generated info ─────────────────────────────────

  Widget _buildGeneratedInfo(MonthlySummaryModel summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            'Generated on ${DateFormat('MMM dd, yyyy – hh:mm a').format(summary.generatedAt)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Data table ──────────────────────────────────────

  Widget _buildTable(MonthlySummaryModel summary) {
    final currentUid = authController.currentUser.value?.uid;

    const headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: AppTheme.textPrimary,
      fontSize: 12,
    );
    const colWidth = 100.0;
    const cellHeight = 44.0;
    final headerBg = AppTheme.primaryColor.withValues(alpha: 0.1);
    final borderColor = Colors.white.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Frozen "Member" column ──
          Column(
            children: [
              Container(
                width: 130,
                height: cellHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: headerBg,
                  border: Border(right: BorderSide(color: borderColor)),
                ),
                child: const Text('Member', style: headerStyle),
              ),
              ...summary.members.map((m) {
                final isMe = m.uid == currentUid;
                return Container(
                  width: 130,
                  height: cellHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppTheme.primaryColor.withValues(alpha: 0.06)
                        : AppTheme.cardColor,
                    border: Border(
                      top: BorderSide(color: borderColor),
                      right: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Text(
                    '@${m.username}',
                    style: TextStyle(
                      color: isMe
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                      fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
          ),

          // ── Scrollable data columns ──
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  Row(
                    children: [
                      _dataHeader(
                        'Deposited',
                        colWidth,
                        cellHeight,
                        headerBg,
                        borderColor,
                      ),
                      _dataHeader(
                        'Meals',
                        colWidth,
                        cellHeight,
                        headerBg,
                        borderColor,
                      ),
                      _dataHeader(
                        'Meal Cost',
                        colWidth,
                        cellHeight,
                        headerBg,
                        borderColor,
                      ),
                      _dataHeader(
                        'To Pay',
                        colWidth,
                        cellHeight,
                        headerBg,
                        borderColor,
                      ),
                      _dataHeader(
                        'To Receive',
                        colWidth,
                        cellHeight,
                        headerBg,
                        borderColor,
                      ),
                    ],
                  ),
                  ...summary.members.map((m) {
                    final isMe = m.uid == currentUid;
                    final style = TextStyle(
                      color: isMe
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    );
                    final rowBg = isMe
                        ? AppTheme.primaryColor.withValues(alpha: 0.06)
                        : AppTheme.cardColor;

                    return Row(
                      children: [
                        _dataCell(
                          '৳${m.moneyPutIn.toStringAsFixed(0)}',
                          colWidth,
                          cellHeight,
                          rowBg,
                          borderColor,
                          style,
                        ),
                        _dataCell(
                          '${m.totalMeals}',
                          colWidth,
                          cellHeight,
                          rowBg,
                          borderColor,
                          style,
                        ),
                        _dataCell(
                          '৳${m.mealCost.toStringAsFixed(1)}',
                          colWidth,
                          cellHeight,
                          rowBg,
                          borderColor,
                          style,
                        ),
                        _dataCell(
                          m.toPay > 0 ? '৳${m.toPay.toStringAsFixed(1)}' : '—',
                          colWidth,
                          cellHeight,
                          rowBg,
                          borderColor,
                          style.copyWith(
                            color: m.toPay > 0
                                ? AppTheme.errorColor
                                : style.color,
                          ),
                        ),
                        _dataCell(
                          m.toReceive > 0
                              ? '৳${m.toReceive.toStringAsFixed(1)}'
                              : '—',
                          colWidth,
                          cellHeight,
                          rowBg,
                          borderColor,
                          style.copyWith(
                            color: m.toReceive > 0
                                ? AppTheme.successColor
                                : style.color,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataHeader(
    String label,
    double width,
    double height,
    Color bg,
    Color borderColor,
  ) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _dataCell(
    String value,
    double width,
    double height,
    Color bg,
    Color borderColor,
    TextStyle style,
  ) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
        ),
      ),
      child: Text(value, style: style),
    );
  }
}
