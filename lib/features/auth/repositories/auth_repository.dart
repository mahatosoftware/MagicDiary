import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class AuthRepository {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isDemoMode = true; // Default to Demo mode if not logged in to Firebase
  UserProfile? _demoUser;

  AuthRepository() {
    _demoUser = UserProfile(
      uid: 'demo_user_123',
      email: 'demo@magicdiary.app',
      displayName: 'Debasish Mahato',
      photoUrl: null,
      currencySymbol: '₹',
      themeMode: 'system',
      enableNotifications: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    );
  }

  bool get isDemoMode => _isDemoMode;

  void setDemoMode(bool value) {
    _isDemoMode = value;
  }

  fb.User? get currentFirebaseUser => _auth.currentUser;

  Stream<UserProfile?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((fbUser) async {
      if (_isDemoMode || fbUser == null) {
        return _isDemoMode ? _demoUser : null;
      }
      return await getUserProfile(fbUser.uid);
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    if (_isDemoMode && uid == _demoUser?.uid) {
      return _demoUser;
    }
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!, uid);
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }

  Future<UserProfile> signInWithEmail(String email, String password) async {
    if (_isDemoMode) {
      _demoUser = UserProfile(
        uid: 'demo_user_123',
        email: email,
        displayName: email.split('@').first.toUpperCase(),
        currencySymbol: '₹',
        themeMode: 'system',
        enableNotifications: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return _demoUser!;
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    var profile = await getUserProfile(user.uid);
    if (profile == null) {
      profile = UserProfile(
        uid: user.uid,
        email: user.email ?? email,
        displayName: user.displayName ?? email.split('@').first,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    }
    return profile;
  }

  Future<UserProfile> registerWithEmail(String email, String password, String displayName) async {
    if (_isDemoMode) {
      _demoUser = UserProfile(
        uid: 'demo_user_123',
        email: email,
        displayName: displayName,
        currencySymbol: '₹',
        themeMode: 'system',
        enableNotifications: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return _demoUser!;
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(displayName);

    final profile = UserProfile(
      uid: user.uid,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    return profile;
  }

  Future<void> signOut() async {
    if (!_isDemoMode) {
      await _auth.signOut();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (!_isDemoMode) {
      await _auth.sendPasswordResetEmail(email: email);
    }
  }

  Future<void> updateUserProfile(UserProfile updatedProfile) async {
    if (_isDemoMode) {
      _demoUser = updatedProfile;
      return;
    }
    await _firestore.collection('users').doc(updatedProfile.uid).update(updatedProfile.toMap());
  }
}
