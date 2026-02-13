import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/models/mess_model.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/services/firestore_service.dart';

class MessController extends GetxController {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthController _authController = Get.find<AuthController>();

  final Rx<MessModel?> currentMess = Rx<MessModel?>(null);
  final RxList<UserModel> messMembers = <UserModel>[].obs;
  final RxList<Map<String, dynamic>> pendingInvites =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initMessData();
    _listenToInvitations();
  }

  void _initMessData() {
    ever(_authController.currentUser, (user) {
      if (user != null && user.hasMess) {
        _loadMess(user.messId!);
      } else {
        currentMess.value = null;
        messMembers.clear();
      }
    });

    // Load immediately if user already exists
    final user = _authController.currentUser.value;
    if (user != null && user.hasMess) {
      _loadMess(user.messId!);
    }
  }

  void _listenToInvitations() {
    ever(_authController.currentUser, (user) {
      if (user != null) {
        _firestoreService.pendingInvitations(user.uid).listen((invites) {
          pendingInvites.value = invites;
        });
      }
    });

    final user = _authController.currentUser.value;
    if (user != null) {
      _firestoreService.pendingInvitations(user.uid).listen((invites) {
        pendingInvites.value = invites;
      });
    }
  }

  Future<void> _loadMess(String messId) async {
    _firestoreService.messStream(messId).listen((mess) {
      currentMess.value = mess;
      if (mess != null) {
        _loadMembers(mess.messId);
      }
    });
  }

  Future<void> _loadMembers(String messId) async {
    final members = await _firestoreService.getMessMembers(messId);
    messMembers.value = members;
  }

  Future<bool> createMess({
    required String name,
    required int roomCount,
    required List<int> roomCapacities,
  }) async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value!;

      final mess = await _firestoreService.createMess(
        name: name,
        managerId: user.uid,
        roomCount: roomCount,
        roomCapacities: roomCapacities,
      );

      currentMess.value = mess;
      await _authController.refreshUser();
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to create mess: $e',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> inviteMember(String username) async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value!;
      final mess = currentMess.value!;

      // Find user by username
      final targetUser = await _firestoreService.getUserByUsername(username);
      if (targetUser == null) {
        _authController.showSnackbar('Error', 'User not found', isError: true);
        return false;
      }

      if (targetUser.hasMess) {
        _authController.showSnackbar(
          'Error',
          'User is already in a mess',
          isError: true,
        );
        return false;
      }

      if (mess.memberIds.length >= 10) {
        _authController.showSnackbar(
          'Error',
          'Mess is full (max 10 members)',
          isError: true,
        );
        return false;
      }

      await _firestoreService.sendInvitation(
        messId: mess.messId,
        messName: mess.name,
        fromUserId: user.uid,
        fromUsername: user.username,
        toUserId: targetUser.uid,
      );

      _authController.showSnackbar('Success', 'Invitation sent to $username');
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to send invitation',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> acceptInvitation(String inviteId) async {
    try {
      final user = _authController.currentUser.value!;
      await _firestoreService.acceptInvitation(inviteId, user.uid);
      await _authController.refreshUser();
      _authController.showSnackbar('Success', 'You joined the mess!');
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to accept invitation',
        isError: true,
      );
    }
  }

  Future<void> declineInvitation(String inviteId) async {
    try {
      await _firestoreService.declineInvitation(inviteId);
      _authController.showSnackbar('Info', 'Invitation declined');
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to decline invitation',
        isError: true,
      );
    }
  }

  Future<bool> resetAllEntries() async {
    try {
      isLoading.value = true;
      final user = _authController.currentUser.value;
      final mess = currentMess.value;

      if (user == null || mess == null || !user.isManager) {
        _authController.showSnackbar(
          'Error',
          'Only the mess manager can reset entries',
          isError: true,
        );
        return false;
      }

      await _firestoreService.resetAllEntries(mess.messId);
      _authController.showSnackbar(
        'Success',
        'All bazar & meal entries have been reset',
      );
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to reset entries',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
