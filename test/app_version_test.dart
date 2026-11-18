import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_diary/core/version/models/app_version_config.dart';
import 'package:magic_diary/core/version/providers/app_version_providers.dart';
import 'package:magic_diary/core/version/widgets/app_update_gate.dart';

void main() {
  group('AppVersionConfig Semantic Versioning & Comparison Tests', () {
    test('compareSemVer correctly orders versions', () {
      expect(AppVersionConfig.compareSemVer('1.0.7', '1.0.8'), -1);
      expect(AppVersionConfig.compareSemVer('1.0.8', '1.0.8'), 0);
      expect(AppVersionConfig.compareSemVer('1.0.9', '1.0.8'), 1);
      expect(AppVersionConfig.compareSemVer('1.0.10', '1.0.9'), 1);
      expect(AppVersionConfig.compareSemVer('v1.0.7+7', 'v1.0.8+8'), -1);
      expect(AppVersionConfig.compareSemVer('2.0.0', '1.9.99'), 1);
    });

    test('isBelowMinimum returns true when version or build number is below minimum', () {
      const config = AppVersionConfig(
        minSupportedVersion: '1.0.8',
        minSupportedBuildNumber: 8,
        forceUpdate: true,
      );

      // Both version and build number below
      expect(config.isBelowMinimum(currentVersion: '1.0.7', currentBuildNumber: 7), isTrue);

      // Build number below
      expect(config.isBelowMinimum(currentVersion: '1.0.8', currentBuildNumber: 7), isTrue);

      // Equal: supported
      expect(config.isBelowMinimum(currentVersion: '1.0.8', currentBuildNumber: 8), isFalse);

      // Newer: supported
      expect(config.isBelowMinimum(currentVersion: '1.0.9', currentBuildNumber: 9), isFalse);
    });

    test('isBelowMinimum respects forceUpdate flag when false', () {
      const config = AppVersionConfig(
        minSupportedVersion: '2.0.0',
        minSupportedBuildNumber: 20,
        forceUpdate: false,
      );

      // Even if old, if forceUpdate is disabled, do not block
      expect(config.isBelowMinimum(currentVersion: '1.0.7', currentBuildNumber: 7), isFalse);
    });

    test('AppVersionConfig.fromMap parses flexible Firestore schemas', () {
      final map = {
        'minSupportedVersion': '1.0.8',
        'minSupportedBuildNumber': 8,
        'latestVersion': '1.0.9',
        'latestBuildNumber': 9,
        'forceUpdate': true,
        'updateUrl': 'https://play.google.com/store/apps/details?id=in.mahato.magicdiary',
        'updateTitle': 'Critical Update Needed',
        'updateMessage': 'Please update now.',
        'releaseNotes': 'New sharing improvements and bug fixes.',
      };

      final parsed = AppVersionConfig.fromMap(map);
      expect(parsed.minSupportedVersion, '1.0.8');
      expect(parsed.minSupportedBuildNumber, 8);
      expect(parsed.latestVersion, '1.0.9');
      expect(parsed.latestBuildNumber, 9);
      expect(parsed.forceUpdate, isTrue);
      expect(parsed.updateTitle, 'Critical Update Needed');
      expect(parsed.updateMessage, 'Please update now.');
      expect(parsed.releaseNotes, 'New sharing improvements and bug fixes.');
    });
  });

  group('AppUpdateGate UI Tests', () {
    testWidgets('AppUpdateGate displays child when update is not required', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appVersionStatusProvider.overrideWithValue(
              const AppVersionStatus(
                isUpdateRequired: false,
              ),
            ),
          ],
          child: const MaterialApp(
            home: AppUpdateGate(
              child: Scaffold(
                body: Text('Main Application Screen'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Main Application Screen'), findsOneWidget);
      expect(find.text('Update Required'), findsNothing);
    });

    testWidgets('AppUpdateGate intercepts and displays ForceUpdateScreen when update is required', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appVersionStatusProvider.overrideWithValue(
              const AppVersionStatus(
                isUpdateRequired: true,
                currentVersion: '1.0.7',
                currentBuildNumber: 7,
                minSupportedVersion: '1.0.8',
                minSupportedBuildNumber: 8,
                updateTitle: 'Mandatory Update',
                updateMessage: 'Your version of Magic Diary is no longer supported.',
                releaseNotes: 'Security fixes.',
              ),
            ),
          ],
          child: const MaterialApp(
            home: AppUpdateGate(
              child: Scaffold(
                body: Text('Protected Main Application Screen'),
              ),
            ),
          ),
        ),
      );

      // Child should NOT be rendered
      expect(find.text('Protected Main Application Screen'), findsNothing);

      // Force update screen should be displayed
      expect(find.text('Mandatory Update'), findsOneWidget);
      expect(find.text('Your version of Magic Diary is no longer supported.'), findsOneWidget);
      expect(find.text('v1.0.7+7'), findsOneWidget);
      expect(find.text('v1.0.8+8'), findsOneWidget);
      expect(find.text('Security fixes.'), findsOneWidget);
      expect(find.text('Update Magic Diary Now'), findsOneWidget);
    });
  });
}
