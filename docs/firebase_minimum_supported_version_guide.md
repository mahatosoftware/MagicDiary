# Firebase Minimum Supported Version Configuration & Implementation Guide

This guide details the end-to-end architecture, configuration, security, and client implementation for enforcing **Minimum Supported Version (App Force Update / Soft Update)** and **Maintenance Mode** in **Magic Diary** using Firebase.

---

## Table of Contents

1. [Architectural Overview & Strategies](#1-architectural-overview--strategies)
2. [Strategy Comparison: Remote Config vs. Cloud Firestore](#2-strategy-comparison-remote-config-vs-cloud-firestore)
3. [Strategy 1: Firebase Remote Config (Recommended)](#3-strategy-1-firebase-remote-config-recommended)
   - [3.1 Parameter Schema & Data Types](#31-parameter-schema--data-types)
   - [3.2 Firebase Console Configuration Steps](#32-firebase-console-configuration-steps)
   - [3.3 Declarative Remote Config Template (JSON)](#33-declarative-remote-config-template-json)
4. [Strategy 2: Cloud Firestore System Document (Zero Extra Dependencies)](#4-strategy-2-cloud-firestore-system-document-zero-extra-dependencies)
   - [4.1 Document Structure & Schema](#41-document-structure--schema)
   - [4.2 Firestore Security Rules](#42-firestore-security-rules)
5. [Semantic Version Comparison Algorithm (SemVer)](#5-semantic-version-comparison-algorithm-semver)
6. [Client Implementation in Magic Diary (Flutter & Riverpod)](#6-client-implementation-in-magic-diary-flutter--riverpod)
   - [6.1 Version Check Models](#61-version-check-models)
   - [6.2 App Version Verification Service](#62-app-version-verification-service)
   - [6.3 Riverpod Provider Integration](#63-riverpod-provider-integration)
   - [6.4 Blocking UI Dialog & Maintenance Screen](#64-blocking-ui-dialog--maintenance-screen)
7. [Release Operations & Playbook](#7-release-operations--playbook)
   - [7.1 Safe Rollout Workflow](#71-safe-rollout-workflow)
   - [7.2 Emergency Rollback Procedure](#72-emergency-rollback-procedure)
8. [Testing & Verification Checklist](#8-testing--verification-checklist)

---

## 1. Architectural Overview & Strategies

As the Magic Diary app evolves (e.g. database schema migrations, end-to-end encryption upgrades, notification worker integrations, deprecation of older API fields), legacy client versions can encounter fatal runtime errors or write malformed data to Firestore.

To prevent issues, we employ two levels of version control:
1. **Force Update (Hard Block)**: If the installed app version is strictly lower than the `min_supported_version`, the app blocks navigation and displays an un-dismissible full-screen modal directing the user to the Google Play Store or Apple App Store.
2. **Recommended Update (Soft Prompt)**: If the installed app version is greater than or equal to the minimum, but lower than the `latest_version`, a dismissible prompt or snackbar informs the user that new features/fixes are available.
3. **Maintenance Mode Kill-Switch**: An instantaneous global or platform-specific kill-switch to temporarily suspend app operations during critical backend maintenance or outage windows.

```
                                ┌─────────────────────────┐
                                │   App Startup / Launch  │
                                └────────────┬────────────┘
                                             │
                                             ▼
                             ┌───────────────────────────────┐
                             │ Fetch Firebase Version Config │
                             └───────────────┬───────────────┘
                                             │
                                             ▼
                                  /─────────────────────\
                                 <  Is Maintenance Mode  >
                                  \      Active?        /
                                   \───────────────────/
                                    │                 │
                             Yes    │                 │  No
                                    ▼                 ▼
                         ┌───────────────────┐    /──────────────────────\
                         │ Show Blocking     │   < Installed Version <    >
                         │ Maintenance UI    │    \   Min Supported?     /
                         └───────────────────┘     \────────────────────/
                                                    │                  │
                                             Yes    │                  │  No
                                                    ▼                  ▼
                                         ┌────────────────────┐   /──────────────────────\
                                         │ Show Blocking Hard │  <  Installed Version <   >
                                         │ Update Modal       │   \   Latest Version?    /
                                         │ (Action: Store URL)│    \────────────────────/
                                         └────────────────────┘     │                  │
                                                             Yes    │                  │  No
                                                                    ▼                  ▼
                                                         ┌──────────────────┐   ┌──────────────┐
                                                         │ Show Dismissible │   │ Allow Normal │
                                                         │ Soft Update Card │   │ App Usage    │
                                                         └──────────────────┘   └──────────────┘
```

---

## 2. Strategy Comparison: Remote Config vs. Cloud Firestore

| Feature | Firebase Remote Config | Cloud Firestore Document |
| :--- | :--- | :--- |
| **Primary Purpose** | Dynamic configuration & feature flags | Real-time database & document storage |
| **Additional Dependencies** | Requires `firebase_remote_config` | Already installed (`cloud_firestore: ^7.1.0`) |
| **Billing / Cost** | **100% Free** (Unlimited fetches) | Standard Firestore read operations per client |
| **Caching & Fetch Latency** | Built-in disk cache, TTL & background fetch | Cached by Firestore SDK client cache |
| **Targeting & Conditions** | Native support for Android, iOS, country, version | Must query or parse conditionally manually |
| **Real-time Push Updates** | Supported via Real-Time Remote Config | Supported natively via Firestore `.snapshots()` |
| **Offline Resilience** | Fallback to in-app defaults if offline | Reads local Firestore offline cache |
| **Recommendation** | **Best for Production** | **Quickest setup without adding new SDKs** |

Both implementations are fully detailed below.

---

## 3. Strategy 1: Firebase Remote Config (Recommended)

### 3.1 Parameter Schema & Data Types

Configure the following parameters in Firebase Remote Config:

| Parameter Key | Data Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `min_supported_version_android` | `String` | `"1.0.0"` | Minimum SemVer version required on Android (`X.Y.Z`). |
| `latest_version_android` | `String` | `"1.0.9"` | Latest live release version on Android Google Play. |
| `min_supported_version_ios` | `String` | `"1.0.0"` | Minimum SemVer version required on iOS (`X.Y.Z`). |
| `latest_version_ios` | `String` | `"1.0.9"` | Latest live release version on Apple App Store. |
| `min_supported_build_android` | `Number` | `1` | Fallback minimum build/versionCode for Android. |
| `min_supported_build_ios` | `Number` | `1` | Fallback minimum build number for iOS. |
| `store_url_android` | `String` | `"https://play.google.com/store/apps/details?id=in.mahato.magicdiary"` | Target update destination link. |
| `store_url_ios` | `String` | `"https://apps.apple.com/app/id0000000000"` | Apple App Store link. |
| `force_update_title` | `String` | `"Update Required"` | Localized/customizable dialog title. |
| `force_update_message` | `String` | `"A new version of Magic Diary is required to ensure data security and synchronization. Please update to continue."` | Explanation message shown to the user. |
| `soft_update_title` | `String` | `"New Update Available"` | Soft update dialog/banner title. |
| `soft_update_message` | `String` | `"Magic Diary has new features and bug fixes. Update today for the best experience."` | Soft update prompt message. |
| `is_maintenance_mode` | `Boolean` | `false` | Global emergency maintenance kill-switch. |
| `maintenance_message` | `String` | `"Magic Diary is currently undergoing scheduled maintenance. Please check back shortly."` | Message shown during maintenance. |

---

### 3.2 Firebase Console Configuration Steps

1. Open the [Firebase Console](https://console.firebase.google.com/) and select the **Magic Diary** project.
2. In the left navigation sidebar, expand **Run** (or **Engage**) and click on **Remote Config**.
3. Click **Add parameter** (or **Create configuration** if first time).
4. Enter each key listed in the schema above with its default value.
5. *(Optional - Platform-Specific Conditions)*:
   - Click **Add condition** -> Name it `Platform Android` -> Set condition to `App is in.mahato.magicdiary (Android)`.
   - Name another condition `Platform iOS` -> Set condition to `App is in.mahato.magicdiary (iOS)`.
   - Under `min_supported_version`, you can add conditional values per platform instead of separate keys.
6. Click **Publish changes** to make the configuration live.

---

### 3.3 Declarative Remote Config Template (JSON)

If using the Firebase CLI or REST API to manage configuration as code, save this template as `firebase_remote_config.json`:

```json
{
  "parameters": {
    "min_supported_version_android": {
      "defaultValue": {
        "value": "1.0.0"
      },
      "description": "Minimum SemVer required for Android users"
    },
    "latest_version_android": {
      "defaultValue": {
        "value": "1.0.9"
      },
      "description": "Latest stable Android release version"
    },
    "min_supported_version_ios": {
      "defaultValue": {
        "value": "1.0.0"
      },
      "description": "Minimum SemVer required for iOS users"
    },
    "latest_version_ios": {
      "defaultValue": {
        "value": "1.0.9"
      },
      "description": "Latest stable iOS release version"
    },
    "store_url_android": {
      "defaultValue": {
        "value": "https://play.google.com/store/apps/details?id=in.mahato.magicdiary"
      },
      "description": "Google Play Store destination"
    },
    "store_url_ios": {
      "defaultValue": {
        "value": "https://apps.apple.com/app/id0000000000"
      },
      "description": "Apple App Store destination"
    },
    "force_update_title": {
      "defaultValue": {
        "value": "Update Required"
      }
    },
    "force_update_message": {
      "defaultValue": {
        "value": "A critical update is required to keep your diaries and records synchronized securely. Please update to the latest version to continue."
      }
    },
    "soft_update_title": {
      "defaultValue": {
        "value": "Update Available"
      }
    },
    "soft_update_message": {
      "defaultValue": {
        "value": "A newer version of Magic Diary is ready with performance improvements and new features."
      }
    },
    "is_maintenance_mode": {
      "defaultValue": {
        "value": "false"
      },
      "description": "Global emergency maintenance lock"
    },
    "maintenance_message": {
      "defaultValue": {
        "value": "Magic Diary services are temporarily undergoing maintenance. Your data is safe. Please check back soon."
      }
    }
  }
}
```

---

## 4. Strategy 2: Cloud Firestore System Document (Zero Extra Dependencies)

If you prefer not to add the `firebase_remote_config` package right now, Magic Diary can use its existing `cloud_firestore` dependency by storing the version configuration in a dedicated system configuration document.

### 4.1 Document Structure & Schema

- **Collection**: `app_config`
- **Document ID**: `version_control`

**Document Field Specifications**:

```json
{
  "minSupportedVersionAndroid": "1.0.0",
  "latestVersionAndroid": "1.0.9",
  "minSupportedBuildAndroid": 1,
  "latestBuildAndroid": 9,
  "minSupportedVersionIos": "1.0.0",
  "latestVersionIos": "1.0.9",
  "minSupportedBuildIos": 1,
  "latestBuildIos": 9,
  "storeUrlAndroid": "https://play.google.com/store/apps/details?id=in.mahato.magicdiary",
  "storeUrlIos": "https://apps.apple.com/app/id0000000000",
  "forceUpdateTitle": "Update Required",
  "forceUpdateMessage": "A new version of Magic Diary is required to ensure data security. Please update to continue.",
  "softUpdateTitle": "Update Available",
  "softUpdateMessage": "A newer version is available. Would you like to update now?",
  "isMaintenanceMode": false,
  "maintenanceMessage": "Magic Diary is currently undergoing scheduled maintenance. Please check back shortly.",
  "updatedAt": "2026-11-19T09:00:00Z"
}
```

---

### 4.2 Firestore Security Rules

To allow any app client (even unauthenticated users on the splash/login screen) to verify version status while strictly prohibiting clients from writing to this configuration:

Add this rule to `firestore.rules`:

```javascript
// System & App Version Configuration Rules
match /app_config/{configId} {
  // Any client can read the version configuration to verify compliance before proceeding
  allow read: if true;
  
  // Only server-side admin SDK (service accounts) can update version requirements
  allow write: if false;
}
```

---

## 5. Semantic Version Comparison Algorithm (SemVer)

> [!WARNING]
> Never compare versions using simple string comparison (e.g. `"1.0.10" < "1.0.9"` evaluates to `true` in string lexicographical order, which would falsely force an update on newer versions!).

Use a structured SemVer parsing algorithm that compares major, minor, patch, and build numbers as integers:

```dart
class SemVer {
  final int major;
  final int minor;
  final int patch;
  final int build;

  const SemVer({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
  });

  /// Parses strings like '1.0.9', 'v1.2.3', '1.0.9+9'
  factory SemVer.parse(String rawVersion, [int rawBuild = 0]) {
    try {
      var cleaned = rawVersion.trim().toLowerCase();
      if (cleaned.startsWith('v')) {
        cleaned = cleaned.substring(1);
      }

      int extractedBuild = rawBuild;
      if (cleaned.contains('+')) {
        final parts = cleaned.split('+');
        cleaned = parts[0];
        extractedBuild = int.tryParse(parts[1]) ?? rawBuild;
      }

      final segments = cleaned.split('.');
      final major = segments.isNotEmpty ? int.tryParse(segments[0]) ?? 0 : 0;
      final minor = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
      final patch = segments.length > 2 ? int.tryParse(segments[2]) ?? 0 : 0;

      return SemVer(
        major: major,
        minor: minor,
        patch: patch,
        build: extractedBuild,
      );
    } catch (_) {
      return const SemVer(major: 0, minor: 0, patch: 0, build: 0);
    }
  }

  /// Returns:
  ///   < 0 if this < other
  ///   == 0 if this == other
  ///   > 0 if this > other
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return build.compareTo(other.build);
  }

  bool isLessThan(SemVer other) => compareTo(other) < 0;
  bool isGreaterThan(SemVer other) => compareTo(other) > 0;
  bool isAtLeast(SemVer other) => compareTo(other) >= 0;
}
```

---

## 6. Client Implementation in Magic Diary (Flutter & Riverpod)

### 6.1 Version Check Models

Create `lib/core/services/version_control/version_models.dart`:

```dart
enum VersionStatus {
  upToDate,
  softUpdateAvailable,
  forceUpdateRequired,
  maintenanceMode,
}

class VersionCheckResult {
  final VersionStatus status;
  final String currentVersion;
  final String targetVersion;
  final String storeUrl;
  final String title;
  final String message;

  const VersionCheckResult({
    required this.status,
    required this.currentVersion,
    required this.targetVersion,
    required this.storeUrl,
    required this.title,
    required this.message,
  });

  bool get isBlocked =>
      status == VersionStatus.forceUpdateRequired ||
      status == VersionStatus.maintenanceMode;

  bool get hasUpdate =>
      status == VersionStatus.forceUpdateRequired ||
      status == VersionStatus.softUpdateAvailable;
}
```

---

### 6.2 App Version Verification Service

Create `lib/core/services/version_control/version_check_service.dart` (Using Firestore or Remote Config):

```dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'version_models.dart';
import 'semver.dart';

class VersionCheckService {
  final FirebaseFirestore _firestore;

  VersionCheckService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<VersionCheckResult> checkVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentSemVer = SemVer.parse(
        packageInfo.version,
        int.tryParse(packageInfo.buildNumber) ?? 0,
      );

      // Fetch config document from Firestore
      final snapshot = await _firestore
          .collection('app_config')
          .doc('version_control')
          .get(const GetOptions(source: Source.serverAndCache));

      if (!snapshot.exists || snapshot.data() == null) {
        return VersionCheckResult(
          status: VersionStatus.upToDate,
          currentVersion: packageInfo.version,
          targetVersion: packageInfo.version,
          storeUrl: '',
          title: '',
          message: '',
        );
      }

      final data = snapshot.data()!;
      final isMaintenance = data['isMaintenanceMode'] as bool? ?? false;
      if (isMaintenance) {
        return VersionCheckResult(
          status: VersionStatus.maintenanceMode,
          currentVersion: packageInfo.version,
          targetVersion: packageInfo.version,
          storeUrl: '',
          title: 'Under Maintenance',
          message: data['maintenanceMessage'] as String? ??
              'Magic Diary is currently undergoing maintenance. Please check back shortly.',
        );
      }

      final isAndroid = Platform.isAndroid;
      final minVersionStr = (isAndroid
          ? data['minSupportedVersionAndroid']
          : data['minSupportedVersionIos']) as String? ?? '1.0.0';
      final minBuildNum = (isAndroid
          ? data['minSupportedBuildAndroid']
          : data['minSupportedBuildIos']) as int? ?? 0;

      final latestVersionStr = (isAndroid
          ? data['latestVersionAndroid']
          : data['latestVersionIos']) as String? ?? minVersionStr;
      final latestBuildNum = (isAndroid
          ? data['latestBuildAndroid']
          : data['latestBuildIos']) as int? ?? minBuildNum;

      final storeUrl = (isAndroid
          ? data['storeUrlAndroid']
          : data['storeUrlIos']) as String? ??
          'https://play.google.com/store/apps/details?id=in.mahato.magicdiary';

      final minSemVer = SemVer.parse(minVersionStr, minBuildNum);
      final latestSemVer = SemVer.parse(latestVersionStr, latestBuildNum);

      // 1. Force update check: current < minSupported
      if (currentSemVer.isLessThan(minSemVer)) {
        return VersionCheckResult(
          status: VersionStatus.forceUpdateRequired,
          currentVersion: packageInfo.version,
          targetVersion: minVersionStr,
          storeUrl: storeUrl,
          title: data['forceUpdateTitle'] as String? ?? 'Update Required',
          message: data['forceUpdateMessage'] as String? ??
              'A critical update is required to continue using Magic Diary.',
        );
      }

      // 2. Soft update check: current < latest
      if (currentSemVer.isLessThan(latestSemVer)) {
        return VersionCheckResult(
          status: VersionStatus.softUpdateAvailable,
          currentVersion: packageInfo.version,
          targetVersion: latestVersionStr,
          storeUrl: storeUrl,
          title: data['softUpdateTitle'] as String? ?? 'Update Available',
          message: data['softUpdateMessage'] as String? ??
              'A new version of Magic Diary is ready with improvements.',
        );
      }

      return VersionCheckResult(
        status: VersionStatus.upToDate,
        currentVersion: packageInfo.version,
        targetVersion: packageInfo.version,
        storeUrl: storeUrl,
        title: '',
        message: '',
      );
    } catch (e) {
      // In case of network errors, fail gracefully to avoid blocking offline users
      return const VersionCheckResult(
        status: VersionStatus.upToDate,
        currentVersion: 'unknown',
        targetVersion: 'unknown',
        storeUrl: '',
        title: '',
        message: '',
      );
    }
  }
}
```

---

### 6.3 Riverpod Provider Integration

In `lib/core/providers/app_providers.dart`:

```dart
final versionCheckServiceProvider = Provider<VersionCheckService>((ref) {
  return VersionCheckService();
});

final versionCheckProvider = FutureProvider<VersionCheckResult>((ref) async {
  final service = ref.watch(versionCheckServiceProvider);
  return await service.checkVersion();
});
```

---

### 6.4 Blocking UI Dialog & Maintenance Screen

To present an inescapable update prompt when `isBlocked` is true:

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'version_models.dart';

class ForceUpdateDialog extends StatelessWidget {
  final VersionCheckResult checkResult;

  const ForceUpdateDialog({Key? key, required this.checkResult}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMaintenance = checkResult.status == VersionStatus.maintenanceMode;

    return PopScope(
      canPop: false, // Prevents Android back button dismissal
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isMaintenance ? Colors.orange.shade50 : Colors.indigo.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMaintenance ? Icons.construction : Icons.system_update_rounded,
                  size: 48,
                  color: isMaintenance ? Colors.orange.shade800 : Colors.indigo.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                checkResult.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                checkResult.message,
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!isMaintenance && checkResult.storeUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text(
                      'Update Now',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse(checkResult.storeUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 7. Release Operations & Playbook

### 7.1 Safe Rollout Workflow

When rolling out a new release (e.g. `1.1.0`):

1. **Step 1: Release to App Stores**:
   - Deploy `1.1.0` to Google Play Store and Apple App Store.
   - Wait until the update is approved and visible live in the store.
2. **Step 2: Update `latest_version` first**:
   - In Firebase (Remote Config or Firestore), set:
     - `latestVersionAndroid = "1.1.0"`
     - `latestVersionIos = "1.1.0"`
   - Users on `1.0.9` will receive a gentle **Soft Update** invitation.
3. **Step 3: Monitor Adoption**:
   - Check Google Play Console / Firebase Crashlytics to monitor how many users have migrated to `1.1.0`.
4. **Step 4: Deprecate Legacy Versions (Force Update)**:
   - Once 80%+ of users have updated, or if an older version contains a critical flaw, raise `min_supported_version` to `"1.1.0"`.
   - Any users remaining on `< 1.1.0` will immediately see the blocking dialog requiring an update.

---

### 7.2 Emergency Rollback Procedure

If a newly enforced `min_supported_version` accidentally breaks access for valid users:

1. **Immediate Action**:
   - Go to Firebase Console -> Remote Config (or Firestore `app_config/version_control`).
   - Immediately lower `min_supported_version` back to the previous safe version (e.g. `"1.0.0"`).
   - Click **Publish**.
2. **Propagation**:
   - Remote Config clients fetch the new values on next fetch interval.
   - Firestore listeners/reads reflect the rollback instantly.
   - The blocking dialog disappears, allowing users back into the app.

---

## 8. Testing & Verification Checklist

- [ ] **SemVer Unit Tests**: Ensure SemVer parser passes edge cases (`1.0.9` vs `1.0.10`, `1.0.0+1` vs `1.0.0+2`, prefixed `v1.0.0`).
- [ ] **Force Update Test**: Set `min_supported_version` above the debug build version and verify the modal cannot be dismissed via back button or clicking outside.
- [ ] **Store Redirection Test**: Tap "Update Now" and confirm it opens the Play Store or App Store page.
- [ ] **Soft Update Test**: Set `latest_version` above current, but `min_supported_version` below current. Verify the user can dismiss the notice and continue using the app.
- [ ] **Maintenance Mode Test**: Toggle `isMaintenanceMode = true` and confirm full app lockout with maintenance message.
- [ ] **Offline Fallback Test**: Disable device network. Verify the app does not freeze or block the user if the version check times out or fails.
- [ ] **Security Rules Test**: Confirm non-admin users cannot write or alter `/app_config/version_control`.
