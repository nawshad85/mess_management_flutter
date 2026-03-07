import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/models/notice_model.dart';
import 'package:mess_manager/services/notice_service.dart';
import 'package:mess_manager/services/onesignal_service.dart';
import 'package:uuid/uuid.dart';

class NoticeController extends GetxController {
  final NoticeService _noticeService = NoticeService();
  final AuthController _authController = Get.find<AuthController>();
  final MessController _messController = Get.find<MessController>();
  final OneSignalService _oneSignalService = OneSignalService();
  final Uuid _uuid = const Uuid();

  final RxList<NoticeModel> notices = <NoticeModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToNotices();
  }

  void _listenToNotices() {
    ever(_messController.currentMess, (mess) {
      if (mess != null) {
        _noticeService.noticesStream(mess.messId).listen((data) {
          notices.value = data;
        });
      }
    });

    final mess = _messController.currentMess.value;
    if (mess != null) {
      _noticeService.noticesStream(mess.messId).listen((data) {
        notices.value = data;
      });
    }
  }

  /// Post a new notice (manager only).
  Future<bool> postNotice({
    required String title,
    required String content,
  }) async {
    final user = _authController.currentUser.value;
    final mess = _messController.currentMess.value;
    if (user == null || mess == null) return false;

    if (!user.isManager) {
      _authController.showSnackbar(
        'Error',
        'Only the manager can post notices',
        isError: true,
      );
      return false;
    }

    try {
      isLoading.value = true;

      final notice = NoticeModel(
        noticeId: _uuid.v4(),
        title: title.trim(),
        content: content.trim(),
        postedBy: user.uid,
        postedByName: user.name,
      );

      await _noticeService.postNotice(messId: mess.messId, notice: notice);

      // Send push notification to all mess members except the manager
      _oneSignalService.sendChatNotification(
        senderName: '📢 Notice: ${title.trim()}',
        senderId: user.uid,
        content: content.trim(),
        messId: mess.messId,
      );

      _authController.showSnackbar('Success', 'Notice posted');
      return true;
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to post notice',
        isError: true,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete a notice (manager only).
  Future<void> deleteNotice(String noticeId) async {
    final mess = _messController.currentMess.value;
    if (mess == null) return;

    try {
      await _noticeService.deleteNotice(
        messId: mess.messId,
        noticeId: noticeId,
      );
      _authController.showSnackbar('Success', 'Notice deleted');
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to delete notice',
        isError: true,
      );
    }
  }
}
