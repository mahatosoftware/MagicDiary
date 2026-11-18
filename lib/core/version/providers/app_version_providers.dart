import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../models/app_version_config.dart';
import '../services/app_version_service.dart';

final appVersionServiceProvider = Provider<AppVersionService>((ref) {
  return AppVersionService();
});

/// Streams the Firebase configuration document in real time
final appVersionConfigStreamProvider = StreamProvider<AppVersionConfig>((ref) {
  final service = ref.watch(appVersionServiceProvider);
  return service.watchVersionConfig();
});

class AppVersionStatus {
  final bool isUpdateRequired;
  final String currentVersion;
  final int currentBuildNumber;
  final String minSupportedVersion;
  final int minSupportedBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final String updateUrl;
  final String updateTitle;
  final String updateMessage;
  final String releaseNotes;

  const AppVersionStatus({
    this.isUpdateRequired = false,
    this.currentVersion = '1.0.0',
    this.currentBuildNumber = 1,
    this.minSupportedVersion = '1.0.0',
    this.minSupportedBuildNumber = 1,
    this.latestVersion = '1.0.0',
    this.latestBuildNumber = 1,
    this.updateUrl = 'https://play.google.com/store/apps/details?id=in.mahato.magicdiary',
    this.updateTitle = 'Update Required',
    this.updateMessage =
        'A critical update for Magic Diary is required. Please update to the latest version to continue using the application.',
    this.releaseNotes = '',
  });
}

/// Evaluates whether the currently running client needs a mandatory force update
final appVersionStatusProvider = Provider<AppVersionStatus>((ref) {
  final appInfoAsync = ref.watch(appInfoProvider);
  final configAsync = ref.watch(appVersionConfigStreamProvider);

  final appInfo = appInfoAsync.value ?? const AppInfo();
  final config = configAsync.value ?? const AppVersionConfig();

  final currentVersion = appInfo.version;
  final currentBuildNumber = int.tryParse(appInfo.buildNumber) ?? 1;

  final isRequired = config.isBelowMinimum(
    currentVersion: currentVersion,
    currentBuildNumber: currentBuildNumber,
  );

  return AppVersionStatus(
    isUpdateRequired: isRequired,
    currentVersion: currentVersion,
    currentBuildNumber: currentBuildNumber,
    minSupportedVersion: config.minSupportedVersion,
    minSupportedBuildNumber: config.minSupportedBuildNumber,
    latestVersion: config.latestVersion,
    latestBuildNumber: config.latestBuildNumber,
    updateUrl: config.updateUrl,
    updateTitle: config.updateTitle,
    updateMessage: config.updateMessage,
    releaseNotes: config.releaseNotes,
  );
});
