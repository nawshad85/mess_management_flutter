import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/models/chat_message_model.dart';
import 'package:mess_manager/services/chat_service.dart';
import 'package:mess_manager/services/onesignal_service.dart';
import 'package:uuid/uuid.dart';

class ChatController extends GetxController {
  final ChatService _chatService = ChatService();
  final AuthController _authController = Get.find<AuthController>();
  final MessController _messController = Get.find<MessController>();
  final Uuid _uuid = const Uuid();
  final OneSignalService _oneSignalService = OneSignalService();

  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;

  String? _lastMessageId;
  String? _lastMessId;
  bool _isMarkingRead = false;

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

    // Track the latest message ID to avoid processing the same message twice.
    if (_lastMessId != messId) {
      _lastMessId = messId;
      _lastMessageId = latest.messageId;
      return;
    }

    if (_lastMessageId == null) {
      _lastMessageId = latest.messageId;
      return;
    }

    _lastMessageId = latest.messageId;

    // Push notifications are now handled entirely by OneSignal,
    // so no local notification is needed here.
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

      // Fire-and-forget: send push notification via OneSignal
      _oneSignalService.sendChatNotification(
        senderName: user.name,
        senderId: user.uid,
        content: text.trim(),
        messId: mess.messId,
        mentions: mentions,
      );
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

  /// Mark all unread messages from other users as read by the current user.
  Future<void> markVisibleMessagesAsRead() async {
    if (_isMarkingRead) return;
    final uid = _authController.currentUser.value?.uid;
    final mess = _messController.currentMess.value;
    if (uid == null || mess == null) return;

    final unread = messages
        .where((m) => m.senderId != uid && !m.readBy.containsKey(uid))
        .map((m) => m.messageId)
        .toList();

    if (unread.isEmpty) return;
    _isMarkingRead = true;
    try {
      await _chatService.markMessagesAsRead(
        messId: mess.messId,
        uid: uid,
        messageIds: unread,
      );
    } finally {
      _isMarkingRead = false;
    }
  }

  /// Check if a message can still be edited (within 30 minutes).
  bool canEditMessage(ChatMessageModel msg) {
    final uid = _authController.currentUser.value?.uid;
    if (uid == null || msg.senderId != uid) return false;
    return DateTime.now().difference(msg.createdAt).inMinutes < 30;
  }

  /// Edit a message's content.
  Future<void> editMessage(String messageId, String newContent) async {
    if (newContent.trim().isEmpty) return;
    final mess = _messController.currentMess.value;
    if (mess == null) return;

    try {
      await _chatService.editMessage(
        messId: mess.messId,
        messageId: messageId,
        newContent: newContent.trim(),
      );
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to edit message',
        isError: true,
      );
    }
  }

  /// Delete a message permanently (no trace left).
  Future<void> deleteMessage(String messageId) async {
    final mess = _messController.currentMess.value;
    if (mess == null) return;

    try {
      await _chatService.deleteMessage(
        messId: mess.messId,
        messageId: messageId,
      );
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to delete message',
        isError: true,
      );
    }
  }
}
