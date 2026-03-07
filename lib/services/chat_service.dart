import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_manager/models/chat_message_model.dart';
import 'package:mess_manager/utils/constants.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get real-time message stream
  Stream<List<ChatMessageModel>> messagesStream(String messId) {
    return _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.messagesCollection)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => ChatMessageModel.fromMap(d.data())).toList(),
        );
  }

  // Send a message
  Future<void> sendMessage({
    required String messId,
    required ChatMessageModel message,
  }) async {
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.messagesCollection)
        .doc(message.messageId)
        .set(message.toMap());
  }

  // Mark messages as read by a user
  Future<void> markMessagesAsRead({
    required String messId,
    required String uid,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    final batch = _firestore.batch();
    final col = _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.messagesCollection);

    for (final id in messageIds) {
      batch.update(col.doc(id), {'readBy.$uid': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  // Edit a message's content
  Future<void> editMessage({
    required String messId,
    required String messageId,
    required String newContent,
  }) async {
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.messagesCollection)
        .doc(messageId)
        .update({'content': newContent, 'isEdited': true});
  }

  // Delete a message permanently (no trace)
  Future<void> deleteMessage({
    required String messId,
    required String messageId,
  }) async {
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.messagesCollection)
        .doc(messageId)
        .delete();
  }
}
