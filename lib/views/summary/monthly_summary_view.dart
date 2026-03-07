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

  /// Text controllers for per-member actual payment input (manager only).
  final Map<String, TextEditingController> _paymentControllers = {};

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
    for (final c in _paymentControllers.values) {
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
          _fundControllers[m.uid]!.text = deposits[m.uid]!.toStringAsFixed(1);
        } else {
          final ms = existing?.members.where((s) => s.uid == m.uid).firstOrNull;
          if (ms != null) {
            _fundControllers[m.uid]!.text = ms.moneyPutIn.toStringAsFixed(1);
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

  /// Pre-fills payment input controllers from saved actualPayments data.
  void _syncPaymentControllers(MonthlySummaryModel summary) {
    for (final m in summary.members) {
      _paymentControllers.putIfAbsent(m.uid, () => TextEditingController());
      final ctrl = _paymentControllers[m.uid]!;
      final actual = summary.actualPayments[m.uid] ?? 0;
      // Bounced members (overpaid into the other section) need a clean input
      // so the manager enters only the net return amount, not the total.
      final isBounced =
          (m.toPay > 0 && actual > m.toPay) ||
          (m.toReceive > 0 && actual > m.toReceive);
      if (isBounced) {
        // always clear so the manager enters the NET return amount fresh
        ctrl.clear();
      } else if (ctrl.text.isEmpty && actual > 0) {
        ctrl.text = actual.toStringAsFixed(1);
      }
    }
  }

  /// Unfocuses keyboard, parses input, and persists the actual payment amount.
  Future<void> _saveActualPayment(String uid) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final amount = double.tryParse(_paymentControllers[uid]?.text ?? '') ?? 0;
    await summaryController.updateActualPayment(
      uid: uid,
      year: _selectedMonth.year,
      month: _selectedMonth.month,
      amount: amount,
    );
  }

  /// Compact badge showing payment status based on actual vs required amounts.
  Widget _buildAmountStatusBadge(
    double actual,
    double required_, {
    required bool isPaySection,
  }) {
    if (required_ <= 0) return const SizedBox.shrink();
    const epsilon = 0.05;
    final bool isFull = actual >= required_ - epsilon;
    final bool isPartial = actual > epsilon && !isFull;
    final Color color;
    final IconData icon;
    final String label;
    if (isPaySection) {
      if (isFull) {
        color = AppTheme.successColor;
        icon = Icons.check_circle_rounded;
        label = 'Paid';
      } else if (isPartial) {
        color = AppTheme.warningColor;
        icon = Icons.timelapse_rounded;
        label = 'Partial';
      } else {
        color = AppTheme.errorColor;
        icon = Icons.radio_button_unchecked_rounded;
        label = 'Unpaid';
      }
    } else {
      if (isFull) {
        color = AppTheme.successColor;
        icon = Icons.check_circle_rounded;
        label = 'Received';
      } else if (isPartial) {
        color = AppTheme.accentColor;
        icon = Icons.timelapse_rounded;
        label = 'Partial';
      } else {
        color = AppTheme.textSecondary;
        icon = Icons.schedule_rounded;
        label = 'Pending';
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Shared row widget used by both settlement and receive-back sections.
  Widget _buildTransactionRow({
    required String uid,
    required String name,
    required bool isMe,
    required bool showInput,
    required String subLabel,
    required double actual,
    required double requiredAmount,
    required bool isPaySection,
    required Color rowBg,
    required Color borderColor,
    Function()? onSave,
  }) {
    _paymentControllers.putIfAbsent(uid, () => TextEditingController());
    final effectiveSave = onSave ?? () => _saveActualPayment(uid);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: avatar + name + "you" badge
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'you',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: sub-label (amount info)
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Text(
              subLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Row 3: input field + save button + status badge
          Row(
            children: [
              const SizedBox(width: 42),
              if (showInput) ...[
                Expanded(
                  child: TextField(
                    controller: _paymentControllers[uid],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                    onSubmitted: (_) => effectiveSave(),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      hintText: '৳ amount',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => effectiveSave(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppTheme.successColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ] else
                const Spacer(),
              _buildAmountStatusBadge(
                actual,
                requiredAmount,
                isPaySection: isPaySection,
              ),
            ],
          ),
        ],
      ),
    );
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
              if (summary != null) _syncPaymentControllers(summary);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Manager: editable fund entry + save/generate buttons
                    if (isManager) _buildFundEntrySection(summary),

                    // All users: read-only contributions list
                    // (shown to members always; manager already has the
                    //  editable version above, so skip duplicate for them)
                    if (!isManager) _buildMemberContributions(),

                    // Detailed summary — visible to ALL once generated
                    if (summary != null) ...[
                      const SizedBox(height: 16),
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
                      _buildReceiveBackSection(summary),
                      const SizedBox(height: 16),
                      _buildSettlementsSection(summary),
                      const SizedBox(height: 16),
                      _buildGeneratedInfo(summary),
                      if (isManager) ...[
                        const SizedBox(height: 16),
                        _buildDeleteSummaryButton(),
                      ],
                    ] else if (!isManager) ...[
                      const SizedBox(height: 8),
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
                for (final c in _paymentControllers.values) {
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
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
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
                      member.name,
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
                FocusManager.instance.primaryFocus?.unfocus();
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

  // ── Member contributions (read-only, visible to all non-managers) ─────────

  Widget _buildMemberContributions() {
    return Obx(() {
      final members = messController.messMembers;
      final deposits = summaryController.currentDeposits;
      final currentUid = authController.currentUser.value?.uid;

      return Container(
        margin: const EdgeInsets.only(bottom: 4),
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
            // Header
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Member Contributions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Amount contributed by each member this month',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (deposits.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No contributions recorded yet',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              )
            else
              ...members.map((member) {
                final amount = deposits[member.uid] ?? 0;
                final isMe = member.uid == currentUid;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppTheme.primaryColor.withValues(alpha: 0.07)
                        : AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isMe
                        ? Border.all(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.25,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isMe
                            ? AppTheme.primaryColor.withValues(alpha: 0.25)
                            : AppTheme.primaryColor.withValues(alpha: 0.12),
                        child: Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          member.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isMe
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isMe
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isMe)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'you',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      Text(
                        '৳${amount.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: amount > 0
                              ? AppTheme.secondaryColor
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
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
            '৳${summary.totalBazarCost.toStringAsFixed(1)}',
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
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

  // ── Receive-back list ─────────────────────────────

  Widget _buildReceiveBackSection(MonthlySummaryModel summary) {
    final isManager = authController.currentUser.value?.isManager ?? false;
    final currentUid = authController.currentUser.value?.uid;

    // toReceive members not yet fully paid back
    final toReceiveItems = summary.members
        .where((m) => m.toReceive > 0)
        .where(
          (m) => (summary.actualPayments[m.uid] ?? 0) <= m.toReceive + 0.05,
        )
        .toList();

    // toPay members who overpaid → deserve the excess back
    final overpaidItems = summary.members
        .where(
          (m) =>
              m.toPay > 0 &&
              (summary.actualPayments[m.uid] ?? 0) > m.toPay + 0.05,
        )
        .toList();

    if (toReceiveItems.isEmpty && overpaidItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No member has extra money to receive back this month.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final expectedTotal = [
      ...toReceiveItems.map((m) => m.toReceive),
      ...overpaidItems.map((m) {
        final actual = summary.actualPayments[m.uid] ?? 0;
        return actual - m.toPay;
      }),
    ].fold<double>(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: AppTheme.successColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Money To Receive Back',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                'Total ৳${expectedTotal.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Normal toReceive members
          ...toReceiveItems.map((m) {
            final actual = summary.actualPayments[m.uid] ?? 0;
            final remaining = m.toReceive - actual;
            final isMe = m.uid == currentUid;
            final isFullyReceived =
                actual >= m.toReceive - 0.05 && m.toReceive > 0;
            final isPartial = actual > 0.05 && !isFullyReceived;
            return _buildTransactionRow(
              uid: m.uid,
              name: m.name,
              isMe: isMe,
              showInput: isManager,
              subLabel: isFullyReceived
                  ? 'Received ৳${m.toReceive.toStringAsFixed(1)}'
                  : isPartial
                  ? 'Paid back ৳${actual.toStringAsFixed(1)}, ৳${remaining.toStringAsFixed(1)} left'
                  : 'Gets ৳${m.toReceive.toStringAsFixed(1)} back',
              actual: actual,
              requiredAmount: m.toReceive,
              isPaySection: false,
              rowBg: isFullyReceived
                  ? AppTheme.successColor.withValues(alpha: 0.06)
                  : isMe
                  ? AppTheme.primaryColor.withValues(alpha: 0.06)
                  : AppTheme.backgroundColor,
              borderColor: isFullyReceived
                  ? AppTheme.successColor.withValues(alpha: 0.2)
                  : isMe
                  ? AppTheme.primaryColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
            );
          }),
          // Overpaid members — moved here from settlements
          ...overpaidItems.map((m) {
            final actual = summary.actualPayments[m.uid] ?? 0;
            final excess = actual - m.toPay;
            final isMe = m.uid == currentUid;
            return _buildTransactionRow(
              uid: m.uid,
              name: m.name,
              isMe: isMe,
              showInput: isManager,
              subLabel:
                  'Overpaid ৳${actual.toStringAsFixed(1)} (needed ৳${m.toPay.toStringAsFixed(1)}) — gets ৳${excess.toStringAsFixed(1)} back',
              actual: 0,
              requiredAmount: excess,
              isPaySection: false,
              rowBg: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              onSave: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                final entered =
                    double.tryParse(_paymentControllers[m.uid]?.text ?? '') ??
                    0;
                if (entered <= 0) return;
                // Subtract the refund given from actual so actual == toPay means settled
                final newActual = (actual - entered).clamp(
                  0.0,
                  double.infinity,
                );
                await summaryController.updateActualPayment(
                  uid: m.uid,
                  year: _selectedMonth.year,
                  month: _selectedMonth.month,
                  amount: newActual,
                );
                _paymentControllers[m.uid]?.clear();
              },
            );
          }),
        ],
      ),
    );
  }

  // ── Payment settlements ────────────────────────────

  Widget _buildSettlementsSection(MonthlySummaryModel summary) {
    final isManager = authController.currentUser.value?.isManager ?? false;
    final currentUid = authController.currentUser.value?.uid;

    // toPay members who haven't yet overpaid
    final toPayItems = summary.members
        .where((m) => m.toPay > 0)
        .where((m) => (summary.actualPayments[m.uid] ?? 0) <= m.toPay + 0.05)
        .toList();

    // toReceive members who were overpaid back → now owe the excess
    final overReturnedItems = summary.members
        .where(
          (m) =>
              m.toReceive > 0 &&
              (summary.actualPayments[m.uid] ?? 0) > m.toReceive + 0.05,
        )
        .toList();

    if (toPayItems.isEmpty && overReturnedItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.successColor.withValues(alpha: 0.2),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppTheme.successColor,
              size: 20,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Everyone is settled up this month!',
                style: TextStyle(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final paidCount = toPayItems
        .where((m) => (summary.actualPayments[m.uid] ?? 0) >= m.toPay)
        .length;
    final totalCount = toPayItems.length + overReturnedItems.length;

    return Container(
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
                  Icons.handshake_rounded,
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
                      'Payment Settlements',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Track who has paid what they owe',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Progress badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: paidCount == totalCount
                      ? AppTheme.successColor.withValues(alpha: 0.15)
                      : AppTheme.warningColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$paidCount/$totalCount settled',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: paidCount == totalCount
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Normal toPay members
          ...toPayItems.map((m) {
            final actual = summary.actualPayments[m.uid] ?? 0;
            final remaining = m.toPay - actual;
            final isMe = m.uid == currentUid;
            final isPaid = actual >= m.toPay - 0.05 && m.toPay > 0;
            final isPartial = actual > 0.05 && !isPaid;
            return _buildTransactionRow(
              uid: m.uid,
              name: m.name,
              isMe: isMe,
              showInput: isManager,
              subLabel: isPaid
                  ? 'Fully paid ৳${m.toPay.toStringAsFixed(1)}'
                  : isPartial
                  ? 'Paid ৳${actual.toStringAsFixed(1)}, ৳${remaining.toStringAsFixed(1)} remaining'
                  : 'Owes ৳${m.toPay.toStringAsFixed(1)}',
              actual: actual,
              requiredAmount: m.toPay,
              isPaySection: true,
              rowBg: isPaid
                  ? AppTheme.successColor.withValues(alpha: 0.06)
                  : isMe
                  ? AppTheme.errorColor.withValues(alpha: 0.06)
                  : AppTheme.backgroundColor,
              borderColor: isPaid
                  ? AppTheme.successColor.withValues(alpha: 0.2)
                  : isMe
                  ? AppTheme.errorColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
            );
          }),
          // Over-returned members — moved here from receive section
          ...overReturnedItems.map((m) {
            final actual = summary.actualPayments[m.uid] ?? 0;
            final excess = actual - m.toReceive;
            final isMe = m.uid == currentUid;
            return _buildTransactionRow(
              uid: m.uid,
              name: m.name,
              isMe: isMe,
              showInput: isManager,
              subLabel:
                  'Received ৳${actual.toStringAsFixed(1)} back (needed ৳${m.toReceive.toStringAsFixed(1)}) — owes ৳${excess.toStringAsFixed(1)} back',
              actual: 0,
              requiredAmount: excess,
              isPaySection: true,
              rowBg: AppTheme.warningColor.withValues(alpha: 0.05),
              borderColor: AppTheme.warningColor.withValues(alpha: 0.15),
              onSave: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                final entered =
                    double.tryParse(_paymentControllers[m.uid]?.text ?? '') ??
                    0;
                if (entered <= 0) return;
                // Subtract the returned amount from actual so actual == toReceive means settled
                final newActual = (actual - entered).clamp(
                  0.0,
                  double.infinity,
                );
                await summaryController.updateActualPayment(
                  uid: m.uid,
                  year: _selectedMonth.year,
                  month: _selectedMonth.month,
                  amount: newActual,
                );
                _paymentControllers[m.uid]?.clear();
              },
            );
          }),
        ],
      ),
    );
  }

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

  // ── Delete summary button (manager only) ─────────

  Widget _buildDeleteSummaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => _confirmDeleteSummary(),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorColor,
          side: const BorderSide(color: AppTheme.errorColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete Summary'),
      ),
    );
  }

  void _confirmDeleteSummary() {
    final month = _selectedMonth;
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Delete Summary',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete the summary for ${DateFormat('MMMM yyyy').format(month)}? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              await summaryController.deleteSummary(
                year: month.year,
                month: month.month,
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
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
                    m.name,
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
                          '৳${m.moneyPutIn.toStringAsFixed(1)}',
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
