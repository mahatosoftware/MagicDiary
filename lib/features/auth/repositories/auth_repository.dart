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

  /// Checks whether a username already exists in the database.
  Future<bool> isUsernameTaken(String username) async {
    return UserProfile.isUsernameTaken(username, firestore: _firestore);
  }

  /// Generates a unique 7-character username by regenerating until a non-existing username is found in the db.
  Future<String> generateUniqueUsername({
    int maxAttempts = 100,
    Future<bool> Function(String username)? isTakenFn,
  }) async {
    return UserProfile.generateUniqueUsername(
      firestore: _firestore,
      maxAttempts: maxAttempts,
      isTakenFn: isTakenFn ?? isUsernameTaken,
    );
  }

  Stream<UserProfile?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((fbUser) async {
      if (fbUser == null) {
        return null;
      }
      var profile = await getUserProfile(fbUser.uid);
      if (profile == null) {
        final username = await generateUniqueUsername();
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
          await reserveUsername(username, fbUser.uid, displayName: profile.displayName, email: profile.email);
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
        final profile = UserProfile.fromMap(doc.data()!, uid);
        if (profile.username.trim().isEmpty || UserProfile.hasConfusingChars(profile.username)) {
          final newUsername = await generateUniqueUsername();
          final updated = profile.copyWith(username: newUsername);
          try {
            await _firestore.collection('users').doc(uid).update({'username': newUsername});
            await reserveUsername(newUsername, uid, displayName: profile.displayName, email: profile.email);
          } catch (e) {
            debugPrint('Note backfilling username: $e');
          }
          return updated;
        } else {
          // Self-heal & ensure username is in public /usernames collection for fast O(1) lookup
          reserveUsername(profile.username, uid, displayName: profile.displayName, email: profile.email);
        }
        return profile;
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
      final upperUsername = emailToUse.replaceAll('@', '').toUpperCase();
      final lowerUsername = emailToUse.replaceAll('@', '').toLowerCase();
      try {
        var query = await _firestore
            .collection('users')
            .where('username', isEqualTo: upperUsername)
            .limit(1)
            .get();
        if (query.docs.isEmpty && upperUsername != lowerUsername) {
          query = await _firestore
              .collection('users')
              .where('username', isEqualTo: lowerUsername)
              .limit(1)
              .get();
        }
        if (query.docs.isNotEmpty) {
          emailToUse = query.docs.first.data()['email'] as String? ?? emailToUse;
        } else {
          emailToUse = '$upperUsername@magicdiary.internal';
        }
      } catch (e) {
        // Fallback to internal convention
        emailToUse = '$upperUsername@magicdiary.internal';
      }
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: emailToUse,
      password: password,
    );
    final user = credential.user!;
    var profile = await getUserProfile(user.uid);
    if (profile == null) {
      final username = await generateUniqueUsername();
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
      await reserveUsername(username, user.uid, displayName: profile.displayName, email: profile.email);
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
    String cleanUsername;
    if (username != null && username.trim().isNotEmpty) {
      cleanUsername = username.trim().toUpperCase().replaceAll('0', '').replaceAll('O', '');
      // If the provided username is too short or already exists in DB, regenerate until unique
      if (cleanUsername.length < 3 || await isUsernameTaken(cleanUsername)) {
        cleanUsername = await generateUniqueUsername();
      }
    } else {
      cleanUsername = await generateUniqueUsername();
    }

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
    await reserveUsername(cleanUsername, user.uid, displayName: displayName, email: cleanEmail);
    return profile;
  }

  /// Sign in with Google Auth
  Future<UserProfile?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          // User aborted the sign-in modal
          return null;
        }
        rethrow;
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final fb.User? user = userCredential.user;
      if (user == null) return null;

      var profile = await getUserProfile(user.uid);
      if (profile == null) {
        final username = await generateUniqueUsername();
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
        await reserveUsername(username, user.uid, displayName: profile.displayName, email: profile.email);
      }
      return profile;
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      rethrow;
    }
  }

  Future<void> reserveUsername(
    String username,
    String uid, {
    String? displayName,
    String? email,
  }) async {
    final clean = username.trim().toUpperCase();
    if (clean.isEmpty) return;
    try {
      final data = <String, dynamic>{
        'uid': uid,
        'username': clean,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (displayName != null && displayName.trim().isNotEmpty) {
        data['displayName'] = displayName.trim();
      }
      if (email != null && email.trim().isNotEmpty) {
        data['email'] = email.trim().toLowerCase();
      }

      await _firestore.collection('usernames').doc(clean).set(data, SetOptions(merge: true));
      // Also alias lowercase doc for case-insensitive lookup compatibility
      if (clean != clean.toLowerCase()) {
        try {
          await _firestore.collection('usernames').doc(clean.toLowerCase()).set(data, SetOptions(merge: true));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Username reservation note: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
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
    if (updatedProfile.username.isNotEmpty) {
      reserveUsername(
        updatedProfile.username,
        updatedProfile.uid,
        displayName: updatedProfile.displayName,
        email: updatedProfile.email,
      );
    }
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
          final googleUser = await GoogleSignIn.instance.authenticate();
          final googleAuth = googleUser.authentication;
          final cred = fb.GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
          );
          await user.reauthenticateWithCredential(cred);
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
      await GoogleSignIn.instance.signOut();
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
