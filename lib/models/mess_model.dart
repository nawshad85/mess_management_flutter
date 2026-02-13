import 'package:cloud_firestore/cloud_firestore.dart';

class MessModel {
  final String messId;
  final String name;
  final String managerId;
  final List<String> memberIds;
  final int roomCount;
  final DateTime createdAt;

  MessModel({
    required this.messId,
    required this.name,
    required this.managerId,
    required this.memberIds,
    required this.roomCount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'messId': messId,
      'name': name,
      'managerId': managerId,
      'memberIds': memberIds,
      'roomCount': roomCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MessModel.fromMap(Map<String, dynamic> map) {
    return MessModel(
      messId: map['messId'] ?? '',
      name: map['name'] ?? '',
      managerId: map['managerId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      roomCount: map['roomCount'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  MessModel copyWith({
    String? messId,
    String? name,
    String? managerId,
    List<String>? memberIds,
    int? roomCount,
    DateTime? createdAt,
  }) {
    return MessModel(
      messId: messId ?? this.messId,
      name: name ?? this.name,
      managerId: managerId ?? this.managerId,
      memberIds: memberIds ?? this.memberIds,
      roomCount: roomCount ?? this.roomCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  int get memberCount => memberIds.length;
}
