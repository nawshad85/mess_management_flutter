import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/models/monthly_summary_model.dart';
import 'package:mess_manager/services/firestore_service.dart';

class SummaryController extends GetxController {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthController _authController = Get.find<AuthController>();
  final MessController _messController = Get.find<MessController>();

  final Rx<MonthlySummaryModel?> currentSummary = Rx<MonthlySummaryModel?>(
    null,
  );
  final RxBool isLoading = false.obs;
  final RxMap<String, double> currentDeposits = <String, double>{}.obs;

  /// Load deposits for a given month from Firestore.
  Future<void> loadDeposits(int year, int month) async {
    final mess = _messController.currentMess.value;
    if (mess == null) return;
    try {
      currentDeposits.value = await _firestoreService.getMonthlyDeposits(
        messId: mess.messId,
        year: year,
        month: month,
      );
    } catch (_) {
      currentDeposits.clear();
    }
  }

  /// Save deposits (manager only). Can be called anytime during the month.
  Future<bool> saveDeposits({
    required int year,
    required int month,
    required Map<String, double> deposits,
  }) async {
    final mess = _messController.currentMess.value;
    final user = _authController.currentUser.value;
    if (mess == null || user == null || !user.isManager) return false;
    try {
      await _firestoreService.saveMonthlyDeposits(
        messId: mess.messId,
        year: year,
        month: month,
        deposits: deposits,
      );
      currentDeposits.value = deposits;
      _authController.showSnackbar('Success', 'Deposits saved');
      return true;
    } catch (_) {
      _authController.showSnackbar(
        'Error',
        'Failed to save deposits',
        isError: true,
      );
      return false;
    }
  }

  /// Load an existing summary from Firestore.
  Future<void> loadSummary(int year, int month) async {
    final mess = _messController.currentMess.value;
    if (mess == null) return;
    try {
      isLoading.value = true;
      currentSummary.value = await _firestoreService.getMonthlySummary(
        messId: mess.messId,
        year: year,
        month: month,
      );
    } catch (_) {
      _authController.showSnackbar(
        'Error',
        'Failed to load summary',
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Generate and save a summary. Admin provides moneyPutIn per member.
  /// If [fixedMeal] is set, members with fewer meals are bumped to that minimum.
  Future<bool> generateSummary({
    required int year,
    required int month,
    required Map<String, double> moneyPutIn, // uid -> amount
    int? fixedMeal,
  }) async {
    final mess = _messController.currentMess.value;
    final user = _authController.currentUser.value;
    if (mess == null || user == null || !user.isManager) return false;

    try {
      isLoading.value = true;

      // Fetch bazar and meal data for the month
      final bazarEntries = await _firestoreService.getBazarEntriesForMonth(
        messId: mess.messId,
        year: year,
        month: month,
      );
      final mealEntries = await _firestoreService.getMealEntriesForMonth(
        messId: mess.messId,
        year: year,
        month: month,
      );

      // Compute totals
      final totalBazarCost = bazarEntries.fold<double>(
        0,
        (s, e) => s + e.totalCost,
      );
      final memberMealCounts = <String, int>{};

      for (final entry in mealEntries) {
        for (final kv in entry.meals.entries) {
          memberMealCounts[kv.key] = (memberMealCounts[kv.key] ?? 0) + kv.value;
        }
      }

      // Apply fixed meal minimum and compute adjusted total meals
      final members = _messController.messMembers;
      final adjustedMealCounts = <String, int>{};
      int adjustedTotalMeals = 0;

      for (final member in members) {
        int actual = memberMealCounts[member.uid] ?? 0;
        int effective = actual;
        if (fixedMeal != null && actual < fixedMeal) {
          effective = fixedMeal;
        }
        adjustedMealCounts[member.uid] = effective;
        adjustedTotalMeals += effective;
      }

      final costPerMeal = adjustedTotalMeals > 0
          ? totalBazarCost / adjustedTotalMeals
          : 0.0;

      // Build per-member summary
      final memberSummaries = <MemberSummary>[];
      for (final member in members) {
        final effectiveMeals = adjustedMealCounts[member.uid] ?? 0;
        final mealCost = effectiveMeals * costPerMeal;
        final putIn = moneyPutIn[member.uid] ?? 0;
        final toPay = mealCost > putIn ? mealCost - putIn : 0.0;
        final toReceive = putIn > mealCost ? putIn - mealCost : 0.0;

        memberSummaries.add(
          MemberSummary(
            uid: member.uid,
            name: member.name,
            moneyPutIn: putIn,
            totalMeals: effectiveMeals,
            mealCost: double.parse(mealCost.toStringAsFixed(2)),
            toPay: double.parse(toPay.toStringAsFixed(2)),
            toReceive: double.parse(toReceive.toStringAsFixed(2)),
          ),
        );
      }

      final summary = MonthlySummaryModel(
        month: month,
        year: year,
        generatedBy: user.uid,
        totalBazarCost: totalBazarCost,
        totalMeals: adjustedTotalMeals,
        costPerMeal: double.parse(costPerMeal.toStringAsFixed(2)),
        fixedMeal: fixedMeal,
        members: memberSummaries,
      );

      await _firestoreService.saveMonthlySummary(
        messId: mess.messId,
        summary: summary,
      );

      currentSummary.value = summary;
      _authController.showSnackbar('Success', 'Monthly summary generated');
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to generate summary',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Manager marks/unmarks a member's payment as settled.
  Future<void> toggleSettlement({
    required String uid,
    required int year,
    required int month,
    required bool paid,
  }) async {
    final mess = _messController.currentMess.value;
    final user = _authController.currentUser.value;
    if (mess == null || user == null || !user.isManager) return;
    try {
      await _firestoreService.updateSettlement(
        messId: mess.messId,
        year: year,
        month: month,
        uid: uid,
        paid: paid,
      );
      // Optimistically update in-memory
      final current = currentSummary.value;
      if (current != null) {
        final updated = Map<String, bool>.from(current.settlements);
        updated[uid] = paid;
        currentSummary.value = MonthlySummaryModel(
          month: current.month,
          year: current.year,
          generatedBy: current.generatedBy,
          generatedAt: current.generatedAt,
          totalBazarCost: current.totalBazarCost,
          totalMeals: current.totalMeals,
          costPerMeal: current.costPerMeal,
          fixedMeal: current.fixedMeal,
          members: current.members,
          settlements: updated,
          actualPayments: current.actualPayments,
        );
      }
    } catch (_) {
      _authController.showSnackbar(
        'Error',
        'Failed to update settlement',
        isError: true,
      );
    }
  }

  /// Delete the monthly summary for a given month (manager only).
  Future<bool> deleteSummary({required int year, required int month}) async {
    final mess = _messController.currentMess.value;
    final user = _authController.currentUser.value;
    if (mess == null || user == null || !user.isManager) return false;

    try {
      isLoading.value = true;
      await _firestoreService.deleteMonthlySummary(
        messId: mess.messId,
        year: year,
        month: month,
      );
      currentSummary.value = null;
      _authController.showSnackbar('Success', 'Monthly summary deleted');
      return true;
    } catch (_) {
      _authController.showSnackbar(
        'Error',
        'Failed to delete summary',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Save the actual amount paid/received for a member (manager only).
  Future<void> updateActualPayment({
    required String uid,
    required int year,
    required int month,
    required double amount,
  }) async {
    final mess = _messController.currentMess.value;
    final user = _authController.currentUser.value;
    if (mess == null || user == null || !user.isManager) return;
    try {
      await _firestoreService.updateActualPayment(
        messId: mess.messId,
        year: year,
        month: month,
        uid: uid,
        amount: amount,
      );
      // Optimistic update
      final current = currentSummary.value;
      if (current != null) {
        final updated = Map<String, double>.from(current.actualPayments);
        updated[uid] = amount;
        currentSummary.value = MonthlySummaryModel(
          month: current.month,
          year: current.year,
          generatedBy: current.generatedBy,
          generatedAt: current.generatedAt,
          totalBazarCost: current.totalBazarCost,
          totalMeals: current.totalMeals,
          costPerMeal: current.costPerMeal,
          fixedMeal: current.fixedMeal,
          members: current.members,
          settlements: current.settlements,
          actualPayments: updated,
        );
      }
      _authController.showSnackbar('Saved', 'Payment recorded');
    } catch (_) {
      _authController.showSnackbar(
        'Error',
        'Failed to save payment',
        isError: true,
      );
    }
  }
}
