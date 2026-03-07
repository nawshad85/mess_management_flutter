import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/models/room_model.dart';
import 'package:mess_manager/services/firestore_service.dart';

class RoomController extends GetxController {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthController _authController = Get.find<AuthController>();
  final MessController _messController = Get.find<MessController>();

  final RxList<RoomModel> rooms = <RoomModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToRooms();
  }

  void _listenToRooms() {
    ever(_messController.currentMess, (mess) {
      if (mess != null) {
        _firestoreService.roomsStream(mess.messId).listen((roomList) {
          rooms.value = roomList;
        });
      }
    });

    final mess = _messController.currentMess.value;
    if (mess != null) {
      _firestoreService.roomsStream(mess.messId).listen((roomList) {
        rooms.value = roomList;
      });
    }
  }

  Future<bool> assignMemberToRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      isLoading.value = true;
      final mess = _messController.currentMess.value!;

      // Check if room is full
      final room = rooms.firstWhere((r) => r.roomId == roomId);
      if (room.isFull && !room.memberIds.contains(userId)) {
        _authController.showSnackbar('Error', 'Room is full', isError: true);
        return false;
      }

      await _firestoreService.assignMemberToRoom(
        messId: mess.messId,
        roomId: roomId,
        userId: userId,
      );

      await _authController.refreshUser();
      _authController.showSnackbar('Success', 'Member assigned to room');
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to assign member',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> setBazarSchedule({
    required String roomId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      isLoading.value = true;
      final mess = _messController.currentMess.value!;

      await _firestoreService.setBazarSchedule(
        messId: mess.messId,
        roomId: roomId,
        startDate: startDate,
        endDate: endDate,
      );

      _authController.showSnackbar('Success', 'Bazar schedule set');
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to set schedule',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> clearBazarSchedule({required String roomId}) async {
    try {
      isLoading.value = true;
      final mess = _messController.currentMess.value!;

      await _firestoreService.clearBazarSchedule(
        messId: mess.messId,
        roomId: roomId,
      );

      _authController.showSnackbar('Success', 'Bazar schedule removed');
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to remove schedule',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> unassignMemberFromRoom({
    required String roomId,
    required String userId,
    required String userName,
  }) async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value;
      final mess = _messController.currentMess.value;

      if (user == null || mess == null || !user.isManager) {
        _authController.showSnackbar(
          'Error',
          'Only the manager can unassign members',
          isError: true,
        );
        return false;
      }

      await _firestoreService.unassignMemberFromRoom(
        messId: mess.messId,
        roomId: roomId,
        userId: userId,
      );

      _authController.showSnackbar(
        'Success',
        '$userName unassigned from room',
      );
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to unassign member',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Check if a user can edit bazar for a room (used for adding new entries)
  bool canEditBazar(String userId, RoomModel room) {
    final user = _authController.currentUser.value;
    if (user == null) return false;
    if (user.isManager) return true;
    return room.isBazarCurrentlyActive && room.memberIds.contains(userId);
  }

  /// Find the room whose bazar schedule covers the given [date].
  RoomModel? findRoomForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    for (final room in rooms) {
      if (room.bazarStartDate == null || room.bazarEndDate == null) continue;
      final start = DateTime(
        room.bazarStartDate!.year,
        room.bazarStartDate!.month,
        room.bazarStartDate!.day,
      );
      final end = DateTime(
        room.bazarEndDate!.year,
        room.bazarEndDate!.month,
        room.bazarEndDate!.day,
      );
      if ((d.isAtSameMomentAs(start) || d.isAfter(start)) &&
          (d.isAtSameMomentAs(end) || d.isBefore(end))) {
        return room;
      }
    }
    return null;
  }

  /// Check if a user can edit an existing bazar entry for a specific [entryDate].
  ///
  /// Rules:
  /// - Manager can always edit any entry.
  /// - A member can edit only if:
  ///   1. They belong to the room whose bazar schedule covers [entryDate].
  ///   2. The [entryDate] is not more than 1 day before today
  ///      (i.e. today or yesterday are editable, 2+ days ago are not).
  bool canEditBazarEntry(String userId, DateTime entryDate) {
    final user = _authController.currentUser.value;
    if (user == null) return false;
    if (user.isManager) return true;

    // Find the room whose bazar schedule covers the entry date
    final room = findRoomForDate(entryDate);
    if (room == null) return false;

    // User must be a member of that room
    if (!room.memberIds.contains(userId)) return false;

    // Date restriction: entry date must be today or at most 1 day before
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);
    final oneDayBefore = today.subtract(const Duration(days: 1));

    return entryDay.isAtSameMomentAs(oneDayBefore) ||
        entryDay.isAfter(oneDayBefore);
  }

  // Get the room a user belongs to
  RoomModel? getUserRoom(String userId) {
    try {
      return rooms.firstWhere((r) => r.memberIds.contains(userId));
    } catch (_) {
      return null;
    }
  }
}
