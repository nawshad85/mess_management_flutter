import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/models/chat_message_model.dart';
import 'package:mess_manager/services/chat_service.dart';
import 'package:mess_manager/services/storage_service.dart';
import 'package:mess_manager/utils/constants.dart';
import 'package:uuid/uuid.dart';

class ChatController extends GetxController {
  final ChatService _chatService = ChatService();
  final StorageService _storageService = StorageService();
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
        type: AppConstants.messageText,
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

  Future<void> sendImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      isSending.value = true;
      final user = _authController.currentUser.value!;
      final mess = _messController.currentMess.value!;

      final downloadUrl = await _storageService.uploadChatImage(
        messId: mess.messId,
        file: File(pickedFile.path),
      );

      final message = ChatMessageModel(
        messageId: _uuid.v4(),
        senderId: user.uid,
        senderName: user.username,
        type: AppConstants.messageImage,
        content: downloadUrl,
        fileName: pickedFile.name,
      );

      await _chatService.sendMessage(messId: mess.messId, message: message);
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to send image',
        isError: true,
      );
    } finally {
      isSending.value = false;
    }
  }

  Future<void> sendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) return;

      isSending.value = true;
      final user = _authController.currentUser.value!;
      final mess = _messController.currentMess.value!;
      final file = File(result.files.first.path!);
      final fileName = result.files.first.name;

      final downloadUrl = await _storageService.uploadChatDocument(
        messId: mess.messId,
        file: file,
        originalName: fileName,
      );

      final message = ChatMessageModel(
        messageId: _uuid.v4(),
        senderId: user.uid,
        senderName: user.username,
        type: AppConstants.messageDocument,
        content: downloadUrl,
        fileName: fileName,
      );

      await _chatService.sendMessage(messId: mess.messId, message: message);
    } catch (e) {
      _authController.showSnackbar(
        'Error',
        'Failed to send document',
        isError: true,
      );
    } finally {
      isSending.value = false;
    }
  }
}
