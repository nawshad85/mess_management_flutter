import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/models/chat_message_model.dart';
import 'package:mess_manager/services/chat_service.dart';
import 'package:uuid/uuid.dart';

class ChatController extends GetxController {
  final ChatService _chatService = ChatService();
  final AuthController _authController = Get.find<AuthController>();
  final MessController _messController = Get.find<MessController>();
  final Uuid _uuid = const Uuid();

  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToMessages();
  }

  void _listenToMessages() {
    ever(_messController.currentMess, (mess) {
      if (mess != null) {
        _chatService.messagesStream(mess.messId).listen((msgs) {
          messages.value = msgs;
        });
      }
    });

    final mess = _messController.currentMess.value;
    if (mess != null) {
      _chatService.messagesStream(mess.messId).listen((msgs) {
        messages.value = msgs;
      });
    }
  }

  Future<void> sendTextMessage(
    String text, {
    List<String> mentions = const [],
  }) async {
    if (text.trim().isEmpty) return;

    try {
      isSending.value = true;
      final user = _authController.currentUser.value!;
      final mess = _messController.currentMess.value!;

      final message = ChatMessageModel(
        messageId: _uuid.v4(),
        senderId: user.uid,
        senderName: user.username,
        content: text.trim(),
        mentions: mentions,
      );

      await _chatService.sendMessage(messId: mess.messId, message: message);
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to send message',
        isError: true,
      );
    } finally {
      isSending.value = false;
    }
  }
}
