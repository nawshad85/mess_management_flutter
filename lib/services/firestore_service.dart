import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/models/mess_model.dart';
import 'package:mess_manager/models/room_model.dart';
import 'package:mess_manager/models/bazar_model.dart';
import 'package:mess_manager/models/meal_entry_model.dart';
import 'package:mess_manager/models/monthly_summary_model.dart';
import 'package:mess_manager/utils/constants.dart';
import 'package:uuid/uuid.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ============== USER OPERATIONS ==============

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final query = await _firestore
        .collection(AppConstants.usersCollection)
        .where('username', isEqualTo: username.trim().toLowerCase())
        .get();
    if (query.docs.isEmpty) return null;
    return UserModel.fromMap(query.docs.first.data());
  }

  Future<void> updateUser(UserModel user) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .update(user.toMap());
  }

  Stream<UserModel?> userStream(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!) : null);
  }

  // ============== MESS OPERATIONS ==============

  Future<MessModel> createMess({
    required String name,
    required String managerId,
    required int roomCount,
    required List<int> roomCapacities,
  }) async {
    final messId = _uuid.v4();

    final mess = MessModel(
      messId: messId,
      name: name,
      managerId: managerId,
      memberIds: [managerId],
      roomCount: roomCount,
    );

    // Create the mess document
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .set(mess.toMap());

    // Create room subcollections
    for (int i = 0; i < roomCount; i++) {
      final roomId = _uuid.v4();
      final room = RoomModel(
        roomId: roomId,
        roomNumber: i + 1,
        capacity: roomCapacities[i],
      );
      await _firestore
          .collection(AppConstants.messesCollection)
          .doc(messId)
          .collection(AppConstants.roomsCollection)
          .doc(roomId)
          .set(room.toMap());
    }

    // Update the manager's user document
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(managerId)
        .update({'messId': messId, 'role': AppConstants.roleManager});

    return mess;
  }

  Future<MessModel?> getMess(String messId) async {
    final doc = await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .get();
    if (!doc.exists) return null;
    return MessModel.fromMap(doc.data()!);
  }

  Stream<MessModel?> messStream(String messId) {
    return _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .snapshots()
        .map((doc) => doc.exists ? MessModel.fromMap(doc.data()!) : null);
  }

  // ============== INVITATION OPERATIONS ==============

  Future<void> sendInvitation({
    required String messId,
    required String messName,
    required String fromUserId,
    required String fromUsername,
    required String toUserId,
  }) async {
    final inviteId = _uuid.v4();
    await _firestore
        .collection(AppConstants.invitationsCollection)
        .doc(inviteId)
        .set({
          'inviteId': inviteId,
          'messId': messId,
          'messName': messName,
          'fromUserId': fromUserId,
          'fromUsername': fromUsername,
          'toUserId': toUserId,
          'status': 'pending',
          'createdAt': Timestamp.now(),
        });
  }

  Stream<List<Map<String, dynamic>>> pendingInvitations(String userId) {
    return _firestore
        .collection(AppConstants.invitationsCollection)
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> acceptInvitation(String inviteId, String userId) async {
    final inviteDoc = await _firestore
        .collection(AppConstants.invitationsCollection)
        .doc(inviteId)
        .get();

    if (!inviteDoc.exists) throw Exception('Invitation not found');
    final data = inviteDoc.data()!;
    final messId = data['messId'] as String;

    // Update invitation status
    await _firestore
        .collection(AppConstants.invitationsCollection)
        .doc(inviteId)
        .update({'status': 'accepted'});

    // Add user to mess
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .update({
          'memberIds': FieldValue.arrayUnion([userId]),
        });

    // Update user document
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'messId': messId, 'role': AppConstants.roleMember});
  }

  Future<void> declineInvitation(String inviteId) async {
    await _firestore
        .collection(AppConstants.invitationsCollection)
        .doc(inviteId)
        .update({'status': 'declined'});
  }

  // ============== ROOM OPERATIONS ==============

  Stream<List<RoomModel>> roomsStream(String messId) {
    return _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.roomsCollection)
        .orderBy('roomNumber')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => RoomModel.fromMap(d.data())).toList(),
        );
  }

  Future<List<RoomModel>> getRooms(String messId) async {
    final snap = await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.roomsCollection)
        .orderBy('roomNumber')
        .get();
    return snap.docs.map((d) => RoomModel.fromMap(d.data())).toList();
  }

  Future<void> assignMemberToRoom({
    required String messId,
    required String roomId,
    required String userId,
  }) async {
    // Remove from any existing room first
    final rooms = await getRooms(messId);
    for (final room in rooms) {
      if (room.memberIds.contains(userId)) {
        await _firestore
            .collection(AppConstants.messesCollection)
            .doc(messId)
            .collection(AppConstants.roomsCollection)
            .doc(room.roomId)
            .update({
              'memberIds': FieldValue.arrayRemove([userId]),
            });
      }
    }

    // Add to the new room
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.roomsCollection)
        .doc(roomId)
        .update({
          'memberIds': FieldValue.arrayUnion([userId]),
        });

    // Update user's roomId
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'roomId': roomId});
  }

  Future<void> setBazarSchedule({
    required String messId,
    required String roomId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Deactivate all other rooms' bazar
    final rooms = await getRooms(messId);
    for (final room in rooms) {
      if (room.roomId != roomId && room.isActiveBazar) {
        await _firestore
            .collection(AppConstants.messesCollection)
            .doc(messId)
            .collection(AppConstants.roomsCollection)
            .doc(room.roomId)
            .update({'isActiveBazar': false});
      }
    }

    // Set the bazar schedule for the selected room
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.roomsCollection)
        .doc(roomId)
        .update({
          'bazarStartDate': Timestamp.fromDate(startDate),
          'bazarEndDate': Timestamp.fromDate(endDate),
          'isActiveBazar': true,
        });
  }

  // ============== BAZAR OPERATIONS ==============

  Future<void> addBazarEntry({
    required String messId,
    required BazarModel entry,
  }) async {
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.bazarEntriesCollection)
        .doc(entry.entryId)
        .set(entry.toMap());
  }

  Future<void> updateBazarEntry({
    required String messId,
    required BazarModel entry,
  }) async {
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.bazarEntriesCollection)
        .doc(entry.entryId)
        .update(entry.toMap());
  }

  Stream<List<BazarModel>> bazarEntriesStream(String messId) {
    return _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.bazarEntriesCollection)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => BazarModel.fromMap(d.data())).toList(),
        );
  }

  // ============== MEAL OPERATIONS ==============

  Future<void> addMealEntry({
    required String messId,
    required MealEntryModel entry,
  }) async {
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.mealEntriesCollection)
        .doc(entry.entryId)
        .set(entry.toMap());
  }

  Future<void> updateMealEntry({
    required String messId,
    required MealEntryModel entry,
  }) async {
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.mealEntriesCollection)
        .doc(entry.entryId)
        .update(entry.toMap());
  }

  Stream<List<MealEntryModel>> mealEntriesStream(String messId) {
    return _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.mealEntriesCollection)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => MealEntryModel.fromMap(d.data())).toList(),
        );
  }

  // ============== MEMBER LIST ==============

  Future<List<UserModel>> getMessMembers(String messId) async {
    final mess = await getMess(messId);
    if (mess == null) return [];

    final members = <UserModel>[];
    for (final uid in mess.memberIds) {
      final user = await getUser(uid);
      if (user != null) members.add(user);
    }
    return members;
  }

  // ============== RESET OPERATIONS ==============

  Future<void> resetAllEntries(String messId) async {
    final batch = _firestore.batch();

    // Delete all bazar entries
    final bazarSnap = await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.bazarEntriesCollection)
        .get();
    for (final doc in bazarSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete all meal entries
    final mealSnap = await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.mealEntriesCollection)
        .get();
    for (final doc in mealSnap.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    // Reset all room bazar schedules
    final rooms = await getRooms(messId);
    for (final room in rooms) {
      await _firestore
          .collection(AppConstants.messesCollection)
          .doc(messId)
          .collection(AppConstants.roomsCollection)
          .doc(room.roomId)
          .update({
            'isActiveBazar': false,
            'bazarStartDate': null,
            'bazarEndDate': null,
          });
    }
  }

  // ============== MONTHLY SUMMARY OPERATIONS ==============

  Future<void> saveMonthlySummary({
    required String messId,
    required MonthlySummaryModel summary,
  }) async {
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.monthlySummariesCollection)
        .doc(summary.docId)
        .set(summary.toMap());
  }

  Future<MonthlySummaryModel?> getMonthlySummary({
    required String messId,
    required int year,
    required int month,
  }) async {
    final docId = '${year}_$month';
    final doc = await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.monthlySummariesCollection)
        .doc(docId)
        .get();
    if (!doc.exists) return null;
    return MonthlySummaryModel.fromMap(doc.data()!);
  }

  Future<List<BazarModel>> getBazarEntriesForMonth({
    required String messId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final snap = await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.bazarEntriesCollection)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => BazarModel.fromMap(d.data())).toList();
  }

  Future<List<MealEntryModel>> getMealEntriesForMonth({
    required String messId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final snap = await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.mealEntriesCollection)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => MealEntryModel.fromMap(d.data())).toList();
  }

  // ============== MONTHLY DEPOSITS ==============

  Future<void> saveMonthlyDeposits({
    required String messId,
    required int year,
    required int month,
    required Map<String, double> deposits, // uid -> amount
  }) async {
    final docId = '${year}_$month';
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection('monthlyDeposits')
        .doc(docId)
        .set({'deposits': deposits, 'updatedAt': Timestamp.now()});
  }

  Future<Map<String, double>> getMonthlyDeposits({
    required String messId,
    required int year,
    required int month,
  }) async {
    final docId = '${year}_$month';
    final doc = await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection('monthlyDeposits')
        .doc(docId)
        .get();
    if (!doc.exists) return {};
    final raw = doc.data()?['deposits'] as Map<String, dynamic>? ?? {};
    return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }
}
