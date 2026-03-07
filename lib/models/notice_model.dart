import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String noticeId;
  final String title;
  final String content;
  final String postedBy; // uid of the manager
  final String postedByName;
  final DateTime createdAt;

  NoticeModel({
    required this.noticeId,
    required this.title,
    required this.content,
    required this.postedBy,
    required this.postedByName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'noticeId': noticeId,
      'title': title,
      'content': content,
      'postedBy': postedBy,
      'postedByName': postedByName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NoticeModel.fromMap(Map<String, dynamic> map) {
    return NoticeModel(
      noticeId: map['noticeId'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      postedBy: map['postedBy'] ?? '',
      postedByName: map['postedByName'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
