import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/controllers/room_controller.dart';
import 'package:mess_manager/models/meal_entry_model.dart';
import 'package:mess_manager/services/firestore_service.dart';
import 'package:uuid/uuid.dart';

class MealController extends GetxController {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthController _authController = Get.find<AuthController>();
  final MessController _messController = Get.find<MessController>();
  final RoomController _roomController = Get.find<RoomController>();
  final Uuid _uuid = const Uuid();

  final RxList<MealEntryModel> mealEntries = <MealEntryModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToMealEntries();
  }

  void _listenToMealEntries() {
    ever(_messController.currentMess, (mess) {
      if (mess != null) {
        _firestoreService.mealEntriesStream(mess.messId).listen((entries) {
          mealEntries.value = entries;
        });
      }
    });

    final mess = _messController.currentMess.value;
    if (mess != null) {
      _firestoreService.mealEntriesStream(mess.messId).listen((entries) {
        mealEntries.value = entries;
      });
    }
  }

  Future<bool> addMealEntry({
    required String roomId,
    required DateTime date,
    required Map<String, int> meals,
  }) async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value!;
      final mess = _messController.currentMess.value!;

      // Permission check — managers can always add, others need active room
      if (!user.isManager) {
        final room = _roomController.rooms.firstWhereOrNull(
          (r) => r.roomId == roomId,
        );
        if (room == null || !_roomController.canEditBazar(user.uid, room)) {
          _authController.showSnackbar(
            'Permission Denied',
            'You cannot edit meals for this room right now',
            isError: true,
          );
          return false;
        }
      }

      // Use 'general' if no room covers this date
      final effectiveRoomId = roomId.isEmpty ? 'general' : roomId;

      final entry = MealEntryModel(
        entryId: _uuid.v4(),
        date: date,
        roomId: effectiveRoomId,
        meals: meals,
        addedBy: user.uid,
      );

      await _firestoreService.addMealEntry(messId: mess.messId, entry: entry);

      _authController.showSnackbar('Success', 'Meal entry added');
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to add meal entry',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateMealEntry(MealEntryModel entry) async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value!;
      final mess = _messController.currentMess.value!;

      if (!user.isManager) {
        final room = _roomController.rooms.firstWhereOrNull(
          (r) => r.roomId == entry.roomId,
        );
        if (room == null || !_roomController.canEditBazar(user.uid, room)) {
          _authController.showSnackbar(
            'Permission Denied',
            'You cannot edit meals for this room right now',
            isError: true,
          );
          return false;
        }
      }

      await _firestoreService.updateMealEntry(
        messId: mess.messId,
        entry: entry,
      );

      _authController.showSnackbar('Success', 'Meal entry updated');
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to update meal entry',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  int get totalMeals => mealEntries.fold(0, (sum, e) => sum + e.totalMeals);

  // Get total meals for a specific user
  int getUserTotalMeals(String userId) {
    int total = 0;
    for (final entry in mealEntries) {
      total += entry.meals[userId] ?? 0;
    }
    return total;
  }
}
