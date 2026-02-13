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
}
