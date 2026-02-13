import 'package:cloud_firestore/cloud_firestore.dart';

class BazarModel {
  final String entryId;
  final String roomId;
  final DateTime date;
  final List<BazarItem> items;
  final double totalCost;
  final String addedBy;
  final DateTime createdAt;

  BazarModel({
    required this.entryId,
    required this.roomId,
    required this.date,
    required this.items,
    required this.totalCost,
    required this.addedBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'entryId': entryId,
      'roomId': roomId,
      'date': Timestamp.fromDate(date),
      'items': items.map((e) => e.toMap()).toList(),
      'totalCost': totalCost,
      'addedBy': addedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BazarModel.fromMap(Map<String, dynamic> map) {
    return BazarModel(
      entryId: map['entryId'] ?? '',
      roomId: map['roomId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      items:
          (map['items'] as List?)
              ?.map((e) => BazarItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      addedBy: map['addedBy'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class BazarItem {
  final String name;
  final double cost;

  BazarItem({required this.name, required this.cost});

  Map<String, dynamic> toMap() {
    return {'name': name, 'cost': cost};
  }

  factory BazarItem.fromMap(Map<String, dynamic> map) {
    return BazarItem(
      name: map['name'] ?? '',
      cost: (map['cost'] ?? 0).toDouble(),
    );
  }
}
