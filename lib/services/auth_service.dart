import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/utils/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if username is unique
  Future<bool> isUsernameAvailable(String username) async {
    final query = await _firestore
        .collection(AppConstants.usersCollection)
        .where('username', isEqualTo: username.trim().toLowerCase())
        .get();
    return query.docs.isEmpty;
  }

  // Register with email, password, and unique username
  Future<UserModel> register({
    required String email,
    required String password,
    required String username,
  }) async {
    // Check username availability first
    final available = await isUsernameAvailable(username);
    if (!available) {
      throw Exception('Username is already taken');
    }

    // Create auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user!;

    // Create user document in Firestore
    final userModel = UserModel(
      uid: user.uid,
      username: username.trim().toLowerCase(),
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
}
