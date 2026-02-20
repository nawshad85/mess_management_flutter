import 'package:cloud_firestore/cloud_firestore.dart';

class MemberSummary {
  final String uid;
  final String username;
  final double moneyPutIn;
  final int totalMeals;
  final double mealCost;
  final double toPay;
  final double toReceive;

  MemberSummary({
    required this.uid,
    required this.username,
    required this.moneyPutIn,
    required this.totalMeals,
    required this.mealCost,
    required this.toPay,
    required this.toReceive,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'moneyPutIn': moneyPutIn,
      'totalMeals': totalMeals,
      'mealCost': mealCost,
      'toPay': toPay,
      'toReceive': toReceive,
    };
  }

  factory MemberSummary.fromMap(Map<String, dynamic> map) {
    return MemberSummary(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      moneyPutIn: (map['moneyPutIn'] ?? 0).toDouble(),
      totalMeals: map['totalMeals'] ?? 0,
      mealCost: (map['mealCost'] ?? 0).toDouble(),
      toPay: (map['toPay'] ?? 0).toDouble(),
      toReceive: (map['toReceive'] ?? 0).toDouble(),
    );
  }
}

class MonthlySummaryModel {
  final int month;
  final int year;
  final String generatedBy;
  final DateTime generatedAt;
  final double totalBazarCost;
  final int totalMeals;
  final double costPerMeal;
  final int? fixedMeal;
  final List<MemberSummary> members;

  MonthlySummaryModel({
    required this.month,
    required this.year,
    required this.generatedBy,
    required this.totalBazarCost,
    required this.totalMeals,
    required this.costPerMeal,
    required this.members,
    this.fixedMeal,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  String get docId => '${year}_$month';

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'year': year,
      'generatedBy': generatedBy,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'totalBazarCost': totalBazarCost,
      'totalMeals': totalMeals,
      'costPerMeal': costPerMeal,
      'fixedMeal': fixedMeal,
      'members': members.map((m) => m.toMap()).toList(),
    };
  }

  factory MonthlySummaryModel.fromMap(Map<String, dynamic> map) {
    return MonthlySummaryModel(
      month: map['month'] ?? 1,
      year: map['year'] ?? 2024,
      generatedBy: map['generatedBy'] ?? '',
      generatedAt: map['generatedAt'] != null
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      totalBazarCost: (map['totalBazarCost'] ?? 0).toDouble(),
      totalMeals: map['totalMeals'] ?? 0,
      costPerMeal: (map['costPerMeal'] ?? 0).toDouble(),
      fixedMeal: map['fixedMeal'],
      members:
          (map['members'] as List?)
              ?.map((m) => MemberSummary.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
