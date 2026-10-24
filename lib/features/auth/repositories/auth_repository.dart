import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

class AuthRepository {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  fb.User? get currentFirebaseUser => _auth.currentUser;

  Stream<UserProfile?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((fbUser) async {
      if (fbUser == null) {
        return null;
      }
      var profile = await getUserProfile(fbUser.uid);
      if (profile == null) {
        final username = (fbUser.email?.split('@').first ?? 'user')
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
            .toLowerCase();
        profile = UserProfile(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          displayName: fbUser.displayName ?? username,
          username: username,
          photoUrl: fbUser.photoURL,
          currencySymbol: '₹',
          themeMode: 'system',
          enableNotifications: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        try {
          await _firestore.collection('users').doc(fbUser.uid).set(profile.toMap());
        } catch (e) {
          debugPrint('Error creating user profile in Firestore: $e');
        }
      }
      return profile;
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!, uid);
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
    }
    return null;
  }

  /// Sign in with either Email or Username + Password
  Future<UserProfile> signInWithUsernameOrEmail(String identifier, String password) async {
    String emailToUse = identifier.trim();

    // If identifier is not an email, lookup user by username or fallback to internal email domain
    if (!emailToUse.contains('@')) {
      final cleanUsername = emailToUse.toLowerCase();
      try {
        final query = await _firestore
            .collection('users')
            .where('username', isEqualTo: cleanUsername)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          emailToUse = query.docs.first.data()['email'] as String? ?? emailToUse;
        } else {
          emailToUse = '$cleanUsername@magicdiary.internal';
        }
      } catch (e) {
        // Fallback to internal convention
        emailToUse = '$cleanUsername@magicdiary.internal';
      }
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: emailToUse,
      password: password,
    );
    final user = credential.user!;
    var profile = await getUserProfile(user.uid);
    if (profile == null) {
      final username = (user.email?.split('@').first ?? 'user')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
          .toLowerCase();
      profile = UserProfile(
        uid: user.uid,
        email: user.email ?? emailToUse,
        displayName: user.displayName ?? username,
        username: username,
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    }
    return profile;
  }

  /// Standard email / username registration
  Future<UserProfile> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? username,
  }) async {
    final cleanEmail = email.trim();
    final cleanUsername = (username?.trim().isNotEmpty ?? false)
        ? username!.trim().toLowerCase()
        : cleanEmail.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(displayName);

    final profile = UserProfile(
      uid: user.uid,
      email: cleanEmail,
      displayName: displayName,
      username: cleanUsername,
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(user.uid).set(profile.toMap());
    return profile;
  }

  /// Sign in with Google Auth
  Future<UserProfile?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '290081663609-9af1iqk2uhk3ah244at9sioelhv16rda.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User aborted the sign-in modal
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final fb.User? user = userCredential.user;
      if (user == null) return null;

      var profile = await getUserProfile(user.uid);
      if (profile == null) {
        final username = (user.email?.split('@').first ?? 'user')
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
            .toLowerCase();
        profile = UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? username,
          username: username,
          photoUrl: user.photoURL,
          currencySymbol: '₹',
          themeMode: 'system',
          enableNotifications: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(profile.toMap());
      }
      return profile;
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google sign-out note: $e');
    }
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateUserProfile(UserProfile updatedProfile) async {
    await _firestore.collection('users').doc(updatedProfile.uid).update(updatedProfile.toMap());
  }
}
