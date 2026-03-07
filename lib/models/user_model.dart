import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String uniqueId;
  final String email;
  final String? messId;
  final String role; // 'manager' or 'member'
  final String? roomId;
  final String? managerPinHash;
  final String? managerPinSalt;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.uniqueId,
    required this.email,
    this.messId,
    this.role = 'member',
    this.roomId,
    this.managerPinHash,
    this.managerPinSalt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'uniqueId': uniqueId,
      'email': email,
      'messId': messId,
      'role': role,
      'roomId': roomId,
      'managerPinHash': managerPinHash,
      'managerPinSalt': managerPinSalt,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? map['username'] ?? '',
      uniqueId: map['uniqueId'] ?? '',
      email: map['email'] ?? '',
      messId: map['messId'],
      role: map['role'] ?? 'member',
      roomId: map['roomId'],
      managerPinHash: map['managerPinHash'],
      managerPinSalt: map['managerPinSalt'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? uniqueId,
    String? email,
    String? messId,
    String? role,
    String? roomId,
    String? managerPinHash,
    String? managerPinSalt,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      uniqueId: uniqueId ?? this.uniqueId,
      email: email ?? this.email,
      messId: messId ?? this.messId,
      role: role ?? this.role,
      roomId: roomId ?? this.roomId,
      managerPinHash: managerPinHash ?? this.managerPinHash,
      managerPinSalt: managerPinSalt ?? this.managerPinSalt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isManager => role == 'manager';
  bool get hasMess => messId != null && messId!.isNotEmpty;
  bool get hasManagerPin =>
      managerPinHash != null &&
      managerPinHash!.isNotEmpty &&
      managerPinSalt != null &&
      managerPinSalt!.isNotEmpty;
}
