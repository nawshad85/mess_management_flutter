import 'package:cloud_firestore/cloud_firestore.dart';

class MealEntryModel {
  final String entryId;
  final DateTime date;
  final String roomId;
  final Map<String, int> meals; // uid -> meal count
  final String addedBy;
  final DateTime createdAt;

  MealEntryModel({
    required this.entryId,
    required this.date,
    required this.roomId,
    required this.meals,
    required this.addedBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'entryId': entryId,
      'date': Timestamp.fromDate(date),
      'roomId': roomId,
      'meals': meals,
      'addedBy': addedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MealEntryModel.fromMap(Map<String, dynamic> map) {
    return MealEntryModel(
      entryId: map['entryId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      roomId: map['roomId'] ?? '',
      meals: Map<String, int>.from(map['meals'] ?? {}),
      addedBy: map['addedBy'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  int get totalMeals => meals.values.fold(0, (sum, v) => sum + v);
}
