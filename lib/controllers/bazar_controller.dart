import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/controllers/room_controller.dart';
import 'package:mess_manager/models/bazar_model.dart';
import 'package:mess_manager/services/firestore_service.dart';
import 'package:uuid/uuid.dart';

class BazarController extends GetxController {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthController _authController = Get.find<AuthController>();
  final MessController _messController = Get.find<MessController>();
  final RoomController _roomController = Get.find<RoomController>();
  final Uuid _uuid = const Uuid();

  final RxList<BazarModel> bazarEntries = <BazarModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToBazarEntries();
  }

  void _listenToBazarEntries() {
    ever(_messController.currentMess, (mess) {
      if (mess != null) {
        _firestoreService.bazarEntriesStream(mess.messId).listen((entries) {
          bazarEntries.value = entries;
        });
      }
    });

    final mess = _messController.currentMess.value;
    if (mess != null) {
      _firestoreService.bazarEntriesStream(mess.messId).listen((entries) {
        bazarEntries.value = entries;
      });
    }
  }

  Future<bool> addBazarEntry({
    required String roomId,
    required DateTime date,
    required List<BazarItem> items,
  }) async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value!;
      final mess = _messController.currentMess.value!;

      // Permission check
      final room = _roomController.rooms.firstWhere((r) => r.roomId == roomId);
      if (!_roomController.canEditBazar(user.uid, room)) {
        _authController.showSnackbar(
          'Permission Denied',
          'You cannot edit bazar for this room right now',
          isError: true,
        );
        return false;
      }

      final totalCost = items.fold<double>(0, (sum, item) => sum + item.cost);
      final entry = BazarModel(
        entryId: _uuid.v4(),
        roomId: roomId,
        date: date,
        items: items,
        totalCost: totalCost,
        addedBy: user.uid,
      );

      await _firestoreService.addBazarEntry(messId: mess.messId, entry: entry);

      _authController.showSnackbar('Success', 'Bazar entry added');
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to add bazar entry',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateBazarEntry(BazarModel entry) async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value!;
      final mess = _messController.currentMess.value!;

      final room = _roomController.rooms.firstWhere(
        (r) => r.roomId == entry.roomId,
      );
      if (!_roomController.canEditBazar(user.uid, room)) {
        _authController.showSnackbar(
          'Permission Denied',
          'You cannot edit bazar for this room right now',
          isError: true,
        );
        return false;
      }

      await _firestoreService.updateBazarEntry(
        messId: mess.messId,
        entry: entry,
      );

      _authController.showSnackbar('Success', 'Bazar entry updated');
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to update bazar entry',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  double get totalBazarCost =>
      bazarEntries.fold(0, (sum, e) => sum + e.totalCost);
}
