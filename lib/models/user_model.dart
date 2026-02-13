import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String? messId;
  final String role; // 'manager' or 'member'
  final String? roomId;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    this.messId,
    this.role = 'member',
    this.roomId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'messId': messId,
      'role': role,
      'roomId': roomId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      messId: map['messId'],
      role: map['role'] ?? 'member',
      roomId: map['roomId'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? username,
    String? email,
    String? messId,
    String? role,
    String? roomId,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      messId: messId ?? this.messId,
      role: role ?? this.role,
      roomId: roomId ?? this.roomId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isManager => role == 'manager';
  bool get hasMess => messId != null && messId!.isNotEmpty;
}
