import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

class AuthRepository {
  final fb.FirebaseAuth? _authInstance;
  final FirebaseFirestore? _firestoreInstance;

  AuthRepository({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _authInstance = auth,
        _firestoreInstance = firestore;

  fb.FirebaseAuth get _auth => _authInstance ?? fb.FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

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

  /// Permanently deletes the user's account and all associated data:
  /// 1. Re-authenticates if needed (Google or Email/Password)
  /// 2. Recursively deletes all Cloud Storage files under users/{uid}/
  /// 3. Deletes all Cloud Firestore subcollections and documents under users/{uid}/
  /// 4. Deletes reserved username mapping in usernames/{username}
  /// 5. Deletes user document users/{uid}
  /// 6. Clears local device caches (SharedPreferences, SecureStorage)
  /// 7. Permanently deletes the Firebase Auth account
  Future<void> deleteUserAccountAndData({
    String? password,
    Function(String status)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No active user session found to delete.');
    }
    final uid = user.uid;

    onProgress?.call('Verifying authentication credentials...');

    // 1. Re-authenticate if password is provided or if Google user
    if (password != null && password.isNotEmpty && user.email != null) {
      final cred = fb.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    } else {
      final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
      if (isGoogle) {
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn(
            serverClientId: '290081663609-9af1iqk2uhk3ah244at9sioelhv16rda.apps.googleusercontent.com',
          );
          final googleUser = await googleSignIn.signIn();
          if (googleUser != null) {
            final googleAuth = await googleUser.authentication;
            final cred = fb.GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            await user.reauthenticateWithCredential(cred);
          }
        } catch (e) {
          debugPrint('Google re-authentication attempt notice: $e');
        }
      }
    }

    // 2. Cloud Storage: Purge all uploaded documents, photos, receipts
    onProgress?.call('Purging uploaded documents & cloud files...');
    try {
      final storageRef = FirebaseStorage.instance.ref('users/$uid');
      await _deleteStorageFolder(storageRef);
    } catch (e) {
      debugPrint('Cloud storage purge note (storage may be empty or unconfigured): $e');
    }

    // 3. Cloud Firestore: Purge nested subcollections
    onProgress?.call('Purging diary records & database entries...');
    final userDocRef = _firestore.collection('users').doc(uid);

    // Subcollections with nested child collections
    await _deleteNestedCollection(userDocRef.collection('products'), 'serviceRecords');
    await _deleteNestedCollection(userDocRef.collection('vehicles'), 'serviceRecords');
    await _deleteNestedCollection(userDocRef.collection('properties'), 'propertyMaintenances');

    // Standard subcollections
    final subcollections = [
      'children',
      'schools',
      'academicYears',
      'feeStructures',
      'feeInstallments',
      'feePayments',
      'billAccounts',
      'bills',
      'billPayments',
      'documents',
      'reminders',
      'transactions',
      'investments',
      'householdExpenses',
      'journals',
      'goals',
      'events',
      'financialTransactions',
      'financialObligations',
      'recurringSchedules',
      'financialCategories',
    ];

    for (final subcol in subcollections) {
      await _deleteCollectionDocs(userDocRef.collection(subcol));
    }

    // 4. Delete username claim in 'usernames' collection
    try {
      final usernameDocs = await _firestore
          .collection('usernames')
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in usernameDocs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Username claim deletion note: $e');
    }

    // 5. Delete the user document itself
    try {
      await userDocRef.delete();
    } catch (e) {
      debugPrint('User document deletion note: $e');
    }

    // 6. Clear local caches and secure tokens
    onProgress?.call('Clearing local device caches...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Local SharedPreferences clearance note: $e');
    }

    try {
      const secureStorage = FlutterSecureStorage();
      await secureStorage.deleteAll();
    } catch (e) {
      debugPrint('Local SecureStorage clearance note: $e');
    }

    // 7. Permanently delete Firebase Authentication user
    onProgress?.call('Permanently deleting authentication account...');
    try {
      await user.delete();
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'For security, account deletion requires a recent sign-in. Please log out, log back in, and try deleting your account again.',
        );
      }
      rethrow;
    }

    // Clean up Google sign-in session
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google sign-out note: $e');
    }
  }

  /// Recursively delete files and folders from Firebase Storage
  Future<void> _deleteStorageFolder(Reference ref) async {
    try {
      final result = await ref.listAll();
      for (final item in result.items) {
        try {
          await item.delete();
        } catch (e) {
          debugPrint('Error deleting storage item ${item.fullPath}: $e');
        }
      }
      for (final prefix in result.prefixes) {
        await _deleteStorageFolder(prefix);
      }
    } catch (e) {
      debugPrint('Listing storage error for ${ref.fullPath}: $e');
    }
  }

  /// Batch delete documents in a Firestore subcollection
  Future<void> _deleteCollectionDocs(CollectionReference<Map<String, dynamic>> col) async {
    try {
      final snapshot = await col.get();
      if (snapshot.docs.isEmpty) return;

      WriteBatch batch = _firestore.batch();
      int count = 0;
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }
      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error deleting subcollection ${col.path}: $e');
    }
  }

  /// Delete subcollection that itself contains nested subcollections
  Future<void> _deleteNestedCollection(
    CollectionReference<Map<String, dynamic>> parentCol,
    String childSubColName,
  ) async {
    try {
      final snapshot = await parentCol.get();
      for (final doc in snapshot.docs) {
        await _deleteCollectionDocs(doc.reference.collection(childSubColName));
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting nested collection in ${parentCol.path}: $e');
    }
  }
}
