import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration for application version enforcement managed via Firebase.
/// Typically stored in Firestore under collection `app_config`, document `version`.
class AppVersionConfig {
  final String minSupportedVersion;
  final int minSupportedBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final bool forceUpdate;
  final String updateUrl;
  final String updateTitle;
  final String updateMessage;
  final String releaseNotes;

  const AppVersionConfig({
    this.minSupportedVersion = '1.0.0',
    this.minSupportedBuildNumber = 1,
    this.latestVersion = '1.0.0',
    this.latestBuildNumber = 1,
    this.forceUpdate = true,
    this.updateUrl = 'https://play.google.com/store/apps/details?id=in.mahato.magicdiary',
    this.updateTitle = 'Update Required',
    this.updateMessage =
        'A critical update for Magic Diary is required. Please update to the latest version to continue using the application.',
    this.releaseNotes = '',
  });

  factory AppVersionConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const AppVersionConfig();
    }

    // Helper for robust string parsing
    String parseString(List<String> keys, String defaultValue) {
      for (final key in keys) {
        final val = data[key];
        if (val != null) {
          final s = val.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
      return defaultValue;
    }

    // Helper for robust int parsing
    int parseInt(List<String> keys, int defaultValue) {
      for (final key in keys) {
        final val = data[key];
        if (val is int) return val;
        if (val != null) {
          final parsed = int.tryParse(val.toString().trim());
          if (parsed != null) return parsed;
        }
      }
      return defaultValue;
    }

    // Helper for bool parsing
    bool parseBool(List<String> keys, bool defaultValue) {
      for (final key in keys) {
        final val = data[key];
        if (val is bool) return val;
        if (val is String) {
          if (val.toLowerCase() == 'true') return true;
          if (val.toLowerCase() == 'false') return false;
        }
      }
      return defaultValue;
    }

    final minVer = parseString(
      ['minSupportedVersion', 'min_supported_version', 'minVersion', 'min_version'],
      '1.0.0',
    );
    final minBuild = parseInt(
      ['minSupportedBuildNumber', 'min_supported_build_number', 'minBuildNumber', 'min_build_number', 'minBuild'],
      1,
    );
    final latestVer = parseString(
      ['latestVersion', 'latest_version', 'newestVersion', 'currentVersion'],
      minVer,
    );
    final latestBuild = parseInt(
      ['latestBuildNumber', 'latest_build_number', 'latestBuild', 'currentBuildNumber'],
      minBuild,
    );
    final force = parseBool(['forceUpdate', 'force_update', 'enforceUpdate', 'required'], true);
    final url = parseString(
      ['updateUrl', 'update_url', 'playStoreUrl', 'storeUrl', 'url'],
      'https://play.google.com/store/apps/details?id=in.mahato.magicdiary',
    );
    final title = parseString(
      ['updateTitle', 'update_title', 'title'],
      'Update Required',
    );
    final message = parseString(
      ['updateMessage', 'update_message', 'message', 'description'],
      'A critical update for Magic Diary is required. Please update to the latest version to continue using the application.',
    );
    final notes = parseString(['releaseNotes', 'release_notes', 'notes', 'changelog'], '');

    return AppVersionConfig(
      minSupportedVersion: minVer,
      minSupportedBuildNumber: minBuild,
      latestVersion: latestVer,
      latestBuildNumber: latestBuild,
      forceUpdate: force,
      updateUrl: url,
      updateTitle: title,
      updateMessage: message,
      releaseNotes: notes,
    );
  }

  factory AppVersionConfig.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppVersionConfig.fromMap(doc.data());
  }

  Map<String, dynamic> toMap() {
    return {
      'minSupportedVersion': minSupportedVersion,
      'minSupportedBuildNumber': minSupportedBuildNumber,
      'latestVersion': latestVersion,
      'latestBuildNumber': latestBuildNumber,
      'forceUpdate': forceUpdate,
      'updateUrl': updateUrl,
      'updateTitle': updateTitle,
      'updateMessage': updateMessage,
      'releaseNotes': releaseNotes,
    };
  }

  /// Evaluates whether the currently running app version or build number is below
  /// the minimum supported version configured in Firebase.
  bool isBelowMinimum({
    required String currentVersion,
    required int currentBuildNumber,
  }) {
    if (!forceUpdate) return false;

    // 1. If minimum build number is set, compare build numbers first
    if (minSupportedBuildNumber > 1 && currentBuildNumber > 0) {
      if (currentBuildNumber < minSupportedBuildNumber) {
        return true;
      }
      if (currentBuildNumber >= minSupportedBuildNumber) {
        // Also check if semantic version is strictly lower
        if (minSupportedVersion.isNotEmpty && minSupportedVersion != '1.0.0') {
          return compareSemVer(currentVersion, minSupportedVersion) < 0;
        }
        return false;
      }
    }

    // 2. Semantic version comparison (e.g. 1.0.7 vs 1.0.8)
    if (minSupportedVersion.isNotEmpty && minSupportedVersion != '1.0.0') {
      return compareSemVer(currentVersion, minSupportedVersion) < 0;
    }

    return false;
  }

  /// Compares two semantic version strings (e.g. "1.0.7" vs "1.0.8").
  /// Returns:
  ///   < 0 if [v1] is older than [v2]
  ///   0 if [v1] equals [v2]
  ///   > 0 if [v1] is newer than [v2]
  static int compareSemVer(String v1, String v2) {
    List<int> parseParts(String v) {
      // Clean string: remove prefixes like 'v', trailing '+build' or '-beta'
      var clean = v.trim().toLowerCase();
      if (clean.startsWith('v')) {
        clean = clean.substring(1);
      }
      if (clean.contains('+')) {
        clean = clean.split('+').first;
      }
      if (clean.contains('-')) {
        clean = clean.split('-').first;
      }
      return clean.split('.').map((p) {
        final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
        return int.tryParse(digits) ?? 0;
      }).toList();
    }

    final p1 = parseParts(v1);
    final p2 = parseParts(v2);

    final maxLength = p1.length > p2.length ? p1.length : p2.length;
    for (int i = 0; i < maxLength; i++) {
      final part1 = i < p1.length ? p1[i] : 0;
      final part2 = i < p2.length ? p2[i] : 0;
      if (part1 < part2) return -1;
      if (part1 > part2) return 1;
    }
    return 0;
  }
}
