import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String messageId;
  final String senderId;
  final String senderName;
  final String type; // 'text', 'image', 'document'
  final String content; // text or download URL
  final String? fileName;
  final DateTime createdAt;

  ChatMessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    this.fileName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type,
      'content': content,
      'fileName': fileName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      type: map['type'] ?? 'text',
      content: map['content'] ?? '',
      fileName: map['fileName'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get isDocument => type == 'document';
}
