import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Upload chat image
  Future<String> uploadChatImage({
    required String messId,
    required File file,
  }) async {
    final fileName = '${_uuid.v4()}.jpg';
    final ref = _storage.ref().child('chats/$messId/images/$fileName');
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  // Upload chat document
  Future<String> uploadChatDocument({
    required String messId,
    required File file,
    required String originalName,
  }) async {
    final ext = originalName.split('.').last;
    final fileName = '${_uuid.v4()}.$ext';
    final ref = _storage.ref().child('chats/$messId/documents/$fileName');
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }
}
