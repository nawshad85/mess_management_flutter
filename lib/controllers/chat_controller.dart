import 'package:get/get.dart';
import 'package:mess_manager/app/routes/app_routes.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/models/chat_message_model.dart';
import 'package:mess_manager/services/chat_service.dart';
import 'package:mess_manager/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class ChatController extends GetxController {
  final ChatService _chatService = ChatService();
  final AuthController _authController = Get.find<AuthController>();
  final MessController _messController = Get.find<MessController>();
  final Uuid _uuid = const Uuid();
  final NotificationService _notificationService = NotificationService();

  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;

  String? _lastMessageId;
  String? _lastMessId;

  @override
  void onInit() {
    super.onInit();
    _listenToMessages();
  }

  void _listenToMessages() {
    ever(_messController.currentMess, (mess) {
      if (mess != null) {
        _chatService.messagesStream(mess.messId).listen((msgs) {
          _handleIncomingMessages(mess.messId, msgs);
        });
      }
    });

    final mess = _messController.currentMess.value;
    if (mess != null) {
      _chatService.messagesStream(mess.messId).listen((msgs) {
        _handleIncomingMessages(mess.messId, msgs);
      });
    }
  }

  void _handleIncomingMessages(String messId, List<ChatMessageModel> msgs) {
    messages.value = msgs;

    if (msgs.isEmpty) return;

    final latest = msgs.first;

    if (_lastMessId != messId) {
      _lastMessId = messId;
      _lastMessageId = latest.messageId;
      return;
    }

    if (_lastMessageId == null) {
      _lastMessageId = latest.messageId;
      return;
    }

    if (_lastMessageId == latest.messageId) return;

    _lastMessageId = latest.messageId;

    final currentUserId = _authController.currentUser.value?.uid;
    if (latest.senderId == currentUserId) return;

    if (Get.currentRoute == AppRoutes.chat) return;

    final isMentioned =
        currentUserId != null && latest.mentions.contains(currentUserId);

    _notificationService.showMessageNotification(
      title: latest.senderName,
      body: isMentioned ? 'you have been mentioned' : latest.content,
    );
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
        senderName: user.name,
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
