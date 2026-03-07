import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final List<String> mentions; // UIDs of mentioned users
  final Map<String, DateTime> readBy; // uid -> timestamp when read
  final bool isEdited;
  final DateTime createdAt;

  ChatMessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.mentions = const [],
    this.readBy = const {},
    this.isEdited = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'mentions': mentions,
      'readBy': readBy.map((uid, dt) => MapEntry(uid, Timestamp.fromDate(dt))),
      'isEdited': isEdited,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    final rawReadBy = map['readBy'] as Map<String, dynamic>? ?? {};
    return ChatMessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      content: map['content'] ?? '',
      mentions: List<String>.from(map['mentions'] ?? []),
      readBy: rawReadBy.map(
        (uid, ts) =>
            MapEntry(uid, ts is Timestamp ? ts.toDate() : DateTime.now()),
      ),
      isEdited: map['isEdited'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
