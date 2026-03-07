import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/utils/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Generate a unique 8-character alphanumeric ID
  Future<String> _generateUniqueId() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    while (true) {
      final id = List.generate(
        8,
        (_) => chars[random.nextInt(chars.length)],
      ).join();

      // Check uniqueness
      final query = await _firestore
          .collection(AppConstants.usersCollection)
          .where('uniqueId', isEqualTo: id)
          .get();
      if (query.docs.isEmpty) return id;
    }
  }

  // Register with email, password, and display name
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
  }) async {
    // Create auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user!;

    // Generate a unique ID for invitations
    final uniqueId = await _generateUniqueId();

    // Create user document in Firestore
    final userModel = UserModel(
      uid: user.uid,
      name: name.trim(),
      uniqueId: uniqueId,
      email: email.trim(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(userModel.toMap());

    return userModel;
  }

  // Login with email and password
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(credential.user!.uid)
        .get();

    if (!doc.exists) {
      throw Exception('User data not found');
    }

    return UserModel.fromMap(doc.data()!);
  }

  // Get current user model from Firestore
  Future<UserModel?> getCurrentUserModel() async {
    if (currentUser == null) return null;

    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid)
        .get();

    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> setManagerPin(String pin) async {
    if (currentUser == null) throw Exception('Not authenticated');
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw Exception('PIN must be 4 to 8 digits');
    }

    final userDocRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid);

    final salt = _auth.currentUser!.uid;
    final hash = _hashPin(pin: pin, salt: salt);

    await userDocRef.update({'managerPinSalt': salt, 'managerPinHash': hash});
  }

  Future<bool> verifyManagerPin(String pin) async {
    if (currentUser == null) return false;

    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(currentUser!.uid)
        .get();
    if (!doc.exists) return false;

    final user = UserModel.fromMap(doc.data()!);
    if (!user.hasManagerPin) return false;

    final hash = _hashPin(pin: pin, salt: user.managerPinSalt!);
    return hash == user.managerPinHash;
  }

  String _hashPin({required String pin, required String salt}) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}
