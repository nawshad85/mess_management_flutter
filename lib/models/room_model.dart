import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String roomId;
  final int roomNumber;
  final int capacity;
  final List<String> memberIds;
  final DateTime? bazarStartDate;
  final DateTime? bazarEndDate;
  final bool isActiveBazar;

  RoomModel({
    required this.roomId,
    required this.roomNumber,
    required this.capacity,
    this.memberIds = const [],
    this.bazarStartDate,
    this.bazarEndDate,
    this.isActiveBazar = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomNumber': roomNumber,
      'capacity': capacity,
      'memberIds': memberIds,
      'bazarStartDate': bazarStartDate != null
          ? Timestamp.fromDate(bazarStartDate!)
          : null,
      'bazarEndDate': bazarEndDate != null
          ? Timestamp.fromDate(bazarEndDate!)
          : null,
      'isActiveBazar': isActiveBazar,
    };
  }

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    return RoomModel(
      roomId: map['roomId'] ?? '',
      roomNumber: map['roomNumber'] ?? 0,
      capacity: map['capacity'] ?? 1,
      memberIds: List<String>.from(map['memberIds'] ?? []),
      bazarStartDate: map['bazarStartDate'] != null
          ? (map['bazarStartDate'] as Timestamp).toDate()
          : null,
      bazarEndDate: map['bazarEndDate'] != null
          ? (map['bazarEndDate'] as Timestamp).toDate()
          : null,
      isActiveBazar: map['isActiveBazar'] ?? false,
    );
  }

  RoomModel copyWith({
    String? roomId,
    int? roomNumber,
    int? capacity,
    List<String>? memberIds,
    DateTime? bazarStartDate,
    DateTime? bazarEndDate,
    bool? isActiveBazar,
  }) {
    return RoomModel(
      roomId: roomId ?? this.roomId,
      roomNumber: roomNumber ?? this.roomNumber,
      capacity: capacity ?? this.capacity,
      memberIds: memberIds ?? this.memberIds,
      bazarStartDate: bazarStartDate ?? this.bazarStartDate,
      bazarEndDate: bazarEndDate ?? this.bazarEndDate,
      isActiveBazar: isActiveBazar ?? this.isActiveBazar,
    );
  }

  bool get isFull => memberIds.length >= capacity;
}
