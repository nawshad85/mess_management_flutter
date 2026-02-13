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

  // Check if a user can edit bazar for a room
  bool canEditBazar(String userId, RoomModel room) {
    final user = _authController.currentUser.value;
    if (user == null) return false;
    if (user.isManager) return true;
    return room.isActiveBazar && room.memberIds.contains(userId);
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
