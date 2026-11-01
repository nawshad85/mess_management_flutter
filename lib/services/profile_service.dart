import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_manager/utils/constants.dart';

/// Keeps private profiles and their minimal display/lookup copies in one batch.
class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> queueUpdate(
    WriteBatch batch,
    String uid,
    Map<String, dynamic> updates,
  ) async {
    final profileRef = _firestore
        .collection(AppConstants.memberProfilesCollection)
        .doc(uid);
    final profile = await profileRef.get();
    if (!profile.exists) {
      throw StateError('Member profile is unavailable. Please update the app.');
    }
    final code = profile.data()!['uniqueId'] as String;
    batch.update(
      _firestore.collection(AppConstants.usersCollection).doc(uid),
      updates,
    );
    final shared = Map<String, dynamic>.fromEntries(
      updates.entries.where(
        (entry) =>
            const ['name', 'messId', 'role', 'roomId'].contains(entry.key),
      ),
    );
    if (shared.isNotEmpty) batch.update(profileRef, shared);
    final lookup = Map<String, dynamic>.fromEntries(
      shared.entries.where(
        (entry) => const ['name', 'messId'].contains(entry.key),
      ),
    );
    if (lookup.isNotEmpty) {
      batch.update(
        _firestore.collection(AppConstants.inviteCodesCollection).doc(code),
        lookup,
      );
    }
  }
}
