import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final List<String> mentions; // UIDs of mentioned users
  final DateTime createdAt;

  ChatMessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.mentions = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'mentions': mentions,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      content: map['content'] ?? '',
      mentions: List<String>.from(map['mentions'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
