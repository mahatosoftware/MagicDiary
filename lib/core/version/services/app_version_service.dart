import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_version_config.dart';

class AppVersionService {
  final FirebaseFirestore _firestore;

  AppVersionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Real-time stream of the version configuration from Firestore.
  /// Listens to `app_config/version` and falls back if needed.
  Stream<AppVersionConfig> watchVersionConfig() {
    return _firestore
        .collection('app_config')
        .doc('version')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return AppVersionConfig.fromFirestore(snapshot);
      }
      return const AppVersionConfig();
    }).handleError((error) {
      debugPrint('AppVersionService watch note: $error');
      return const AppVersionConfig();
    });
  }

  /// One-time fetch of the version configuration.
  Future<AppVersionConfig> getVersionConfig() async {
    try {
      // 1. Check primary location: app_config/version
      var doc = await _firestore.collection('app_config').doc('version').get();
      if (doc.exists && doc.data() != null) {
        return AppVersionConfig.fromFirestore(doc);
      }

      // 2. Fallback check: config/version
      doc = await _firestore.collection('config').doc('version').get();
      if (doc.exists && doc.data() != null) {
        return AppVersionConfig.fromFirestore(doc);
      }

      // 3. Fallback check: app_config/app_version
      doc = await _firestore.collection('app_config').doc('app_version').get();
      if (doc.exists && doc.data() != null) {
        return AppVersionConfig.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('AppVersionService fetch note: $e');
    }
    return const AppVersionConfig();
  }

  /// Launches the Google Play Store or custom update URL.
  /// Tries the native market:// scheme first, falling back to HTTPS web URL.
  Future<bool> launchUpdateUrl(String? customUrl) async {
    const packageName = 'in.mahato.magicdiary';
    final targetUrl = (customUrl != null && customUrl.trim().isNotEmpty)
        ? customUrl.trim()
        : 'https://play.google.com/store/apps/details?id=$packageName';

    try {
      // If Android, attempt market:// URI first for direct native Play Store app launch
      if (defaultTargetPlatform == TargetPlatform.android) {
        final marketUri = Uri.parse('market://details?id=$packageName');
        if (await canLaunchUrl(marketUri)) {
          final launched = await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      }

      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('AppVersionService launchUpdateUrl error: $e');
    }
    return false;
  }
}
