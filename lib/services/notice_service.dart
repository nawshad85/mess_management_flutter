import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_manager/models/notice_model.dart';
import 'package:mess_manager/utils/constants.dart';

class NoticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Real-time stream of notices, newest first.
  Stream<List<NoticeModel>> noticesStream(String messId) {
    return _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.noticesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => NoticeModel.fromMap(d.data())).toList(),
        );
  }

  /// Post a new notice.
  Future<void> postNotice({
    required String messId,
    required NoticeModel notice,
  }) async {
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.noticesCollection)
        .doc(notice.noticeId)
        .set(notice.toMap());
  }

  /// Delete a notice.
  Future<void> deleteNotice({
    required String messId,
    required String noticeId,
  }) async {
    await _firestore
        .collection(AppConstants.messesCollection)
        .doc(messId)
        .collection(AppConstants.noticesCollection)
        .doc(noticeId)
        .delete();
  }
}
