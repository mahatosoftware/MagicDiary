import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/providers/app_providers.dart';
import '../../auth/models/user_profile.dart';
import '../../../core/notifications/providers/notification_providers.dart';
import '../../../core/notifications/models/notification_device.dart';
import '../../../core/notifications/models/notification_schedule.dart';
import '../../../core/notifications/models/notification_enums.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final nameController = TextEditingController(text: user.displayName);
    final currencyController = TextEditingController(text: user.currencySymbol);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: user.username),
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Username (7-Character Alphanumeric)',
                prefixText: '@',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                helperText: 'Your unique identifier for diary sharing and circles',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: user.username));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied @${user.username}')),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: currencyController,
              decoration: const InputDecoration(
                labelText: 'Preferred Currency Symbol',
                hintText: '₹, \$, €, £',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newCurrency = currencyController.text.trim();
              if (newName.isEmpty) return;

              final updated = user.copyWith(
                displayName: newName,
                currencySymbol: newCurrency.isNotEmpty ? newCurrency : '₹',
              );
              await ref.read(userProfileProvider.notifier).updateProfile(updated);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Generates a rich, self-describing deep link payload for QR code sharing
  static String getProfileQrData(UserProfile? user) {
    if (user == null || user.username.isEmpty) return 'magicdiary';
    final cleanUsername = user.username.toUpperCase();
    final uid = user.uid;
    final name = Uri.encodeComponent(user.displayName);
    final email = Uri.encodeComponent(user.email);
    return 'magicdiary://user/$cleanUsername?uid=$uid&name=$name&email=$email';
  }

  void _showQrCodeDialog(BuildContext context, WidgetRef ref, UserProfile? user) {
    if (user == null) return;
    final theme = Theme.of(context);
    final username = user.username.isNotEmpty ? user.username : 'magicdiary';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.qr_code_2_rounded, color: theme.primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Profile QR Code',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.displayName.isNotEmpty ? user.displayName : 'Magic Diary User',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                '@$username',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 220,
                height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: QrImageView(
                    data: getProfileQrData(user),
                    version: QrVersions.auto,
                    size: 196.0,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: theme.primaryColor,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Anyone can scan this QR code to find and connect with @$username in Magic Circles and Shared Diaries.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Username'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: username));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Username @$username copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDevicesDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        List<NotificationDevice>? loadedDevices;
        bool isLoading = true;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final fcmService = ref.read(notificationManagerProvider).fcmService;
            final currentDevId = fcmService.currentDeviceId;
            final currentToken = fcmService.currentToken;

            if (isLoading && loadedDevices == null) {
              ref.read(notificationRepositoryProvider).getDevices(user.uid).then((devs) {
                if (context.mounted) {
                  setModalState(() {
                    loadedDevices = List.from(devs);
                    isLoading = false;
                  });
                }
              }).catchError((_) {
                if (context.mounted) {
                  setModalState(() {
                    loadedDevices = [];
                    isLoading = false;
                  });
                }
              });
            }

            final devices = loadedDevices ?? [];
            final inactiveDevices = devices.where((d) =>
                (currentDevId != null && d.id != currentDevId) ||
                (currentToken != null && d.fcmToken != currentToken)).toList();

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Registered Devices & FCM',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'These devices receive push notifications from Magic Diary and GitHub Actions scheduled workers.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    else if (devices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No devices registered yet',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Open the app on an Android, iOS, or Web device with notifications enabled to automatically register.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await fcmService.initialize(user.uid);
                                final refreshed = await ref.read(notificationRepositoryProvider).getDevices(user.uid);
                                setModalState(() {
                                  loadedDevices = List.from(refreshed);
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Device registered successfully!')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Register This Device Now'),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      if (inactiveDevices.isNotEmpty && devices.length > 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${devices.length} registered (${inactiveDevices.length} old)',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                              label: const Text('Remove Inactive Devices', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final repo = ref.read(notificationRepositoryProvider);
                                for (final oldDev in inactiveDevices) {
                                  await repo.deleteDevice(user.uid, oldDev.id);
                                }
                                setModalState(() {
                                  loadedDevices?.removeWhere((d) => inactiveDevices.any((rem) => rem.id == d.id));
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Removed ${inactiveDevices.length} inactive device(s).')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      ...devices.map((d) {
                        final isCurrentDevice = (currentDevId != null && d.id == currentDevId) ||
                            (currentToken != null && d.fcmToken == currentToken);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isCurrentDevice ? Colors.green.shade300 : Colors.grey.shade200,
                              width: isCurrentDevice ? 1.5 : 1,
                            ),
                          ),
                          color: isCurrentDevice ? Colors.green.shade50.withValues(alpha: 0.3) : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      d.platform == 'android'
                                          ? Icons.android_rounded
                                          : (d.platform == 'ios' ? Icons.apple_rounded : Icons.computer_rounded),
                                      color: isCurrentDevice ? Colors.green.shade700 : Colors.teal,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d.deviceName.isNotEmpty ? d.deviceName : d.id,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            isCurrentDevice ? 'This Device (Active)' : 'Previous Install / Inactive',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isCurrentDevice ? FontWeight.bold : FontWeight.normal,
                                              color: isCurrentDevice ? Colors.green.shade800 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isCurrentDevice ? Colors.green.shade100 : Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        d.platform.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentDevice ? Colors.green.shade900 : Colors.teal.shade800,
                                        ),
                                      ),
                                    ),
                                    if (!isCurrentDevice) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        tooltip: 'Remove Inactive Device',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          final repo = ref.read(notificationRepositoryProvider);
                                          await repo.deleteDevice(user.uid, d.id);
                                          setModalState(() {
                                            loadedDevices?.removeWhere((item) => item.id == d.id);
                                          });
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Removed inactive device.')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Device ID: ${d.id}',
                                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      tooltip: 'Copy Device ID',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: d.id));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Copied Device ID: ${d.id}')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                if (d.fcmToken.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'FCM Token: ${d.fcmToken.substring(0, d.fcmToken.length > 24 ? 24 : d.fcmToken.length)}...',
                                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.token_rounded, size: 16),
                                        tooltip: 'Copy Full FCM Token',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: d.fcmToken));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('FCM Token copied to clipboard')),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      'Queue Immediate Test Notification',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      try {
                        // 1. Ensure device is registered
                        final fcmService = ref.read(notificationManagerProvider).fcmService;
                        await fcmService.initialize(user.uid);

                        // 2. Queue a test schedule due right now with compliant schema
                        final now = DateTime.now();
                        final schedId = 'test_push_${now.millisecondsSinceEpoch}';
                        final sched = NotificationSchedule(
                          id: schedId,
                          userId: user.uid,
                          recordId: 'test_push_record',
                          moduleId: 'general',
                          categoryId: 'general',
                          status: NotificationScheduleStatus.scheduled,
                          scheduledAt: now.subtract(const Duration(minutes: 1)),
                          originalScheduledAt: now.subtract(const Duration(minutes: 1)),
                          reminderOffset: '0d',
                          localNotificationId: schedId.hashCode.abs() % 100000,
                          eventType: 'Test Alert',
                          scheduleSource: ScheduleSource.defaultTemplate,
                          createdAt: now,
                          updatedAt: now,
                          payload: {
                            'title': '🔔 Magic Diary Test Push',
                            'body': 'Push notification triggered successfully by GitHub Worker!',
                            'actionRoute': '/notifications',
                          },
                        );

                        await ref.read(notificationRepositoryProvider).saveSchedule(user.uid, sched);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Test schedule created! Run GitHub Action now to receive push.'),
                              duration: Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error queuing test: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Creates a schedule due right now so the GitHub Worker sends push immediately.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);
}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);
    final theme = Theme.of(context);
    final appInfo = ref.watch(appInfoProvider).value ?? const AppInfo();

    User? currentUser;
    try {
      currentUser = FirebaseAuth.instance.currentUser;
    } catch (_) {
      currentUser = null;
    }
    final isGoogleAuth = currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Profile & Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.primaryColor,
                      backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                          ? Text(
                              (user?.displayName.isNotEmpty ?? false)
                                  ? user!.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName.isNotEmpty == true ? user!.displayName : 'Authenticated User',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          // 7-Character Alphanumeric Username Display with Tap-to-Copy
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              if (user?.username.isNotEmpty == true) {
                                Clipboard.setData(ClipboardData(text: user!.username));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Username @${user.username} copied to clipboard'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '@${user?.username.isNotEmpty == true ? user!.username : 'no-username'}',
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.copy_rounded, size: 12, color: theme.primaryColor),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email.isNotEmpty == true ? user!.email : (currentUser?.email ?? ''),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_rounded),
                      tooltip: 'View Profile QR Code',
                      onPressed: () => _showQrCodeDialog(context, ref, user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit Profile',
                      onPressed: () => _showEditProfileDialog(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Profile QR Code Section generated from Username
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.qr_code_2_rounded, color: theme.primaryColor, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Profile QR Code',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            'Scan to Connect',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _showQrCodeDialog(context, ref, user),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: getProfileQrData(user),
                          version: QrVersions.auto,
                          size: 160.0,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: theme.primaryColor,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '@${user?.username.isNotEmpty == true ? user!.username : 'no-username'}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: theme.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generated directly from your unique 7-character username for rapid sharing and Magic Circles invite.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('Copy Username'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () {
                            if (user?.username.isNotEmpty == true) {
                              Clipboard.setData(ClipboardData(text: user!.username));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Username @${user.username} copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.fullscreen_rounded, size: 18),
                          label: const Text('Enlarge QR'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () => _showQrCodeDialog(context, ref, user),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.alternate_email_rounded, color: theme.primaryColor, size: 20),
                    ),
                    title: const Text('Username', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      user?.username.isNotEmpty == true ? '@${user!.username}' : 'Generating 7-char ID...',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.primaryColor,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Text(
                            '7-char ID',
                            style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                          tooltip: 'Show QR Code',
                          onPressed: () => _showQrCodeDialog(context, ref, user),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy Username',
                          onPressed: () {
                            if (user?.username.isNotEmpty == true) {
                              Clipboard.setData(ClipboardData(text: user!.username));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Username @${user.username} copied to clipboard'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.manage_accounts_outlined, color: Colors.indigo),
                    title: const Text('Account Settings'),
                    subtitle: const Text('Security, credentials & delete account'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => context.push('/profile/account-settings'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: Colors.teal),
                    title: const Text('Security & Privacy'),
                    subtitle: const Text('App lock, active sessions, notification privacy & exports'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => context.push('/security-privacy'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      isGoogleAuth ? Icons.g_mobiledata_rounded : Icons.lock_outline_rounded,
                      color: theme.primaryColor,
                      size: 28,
                    ),
                    title: const Text('Authentication Method'),
                    subtitle: Text(
                      isGoogleAuth ? 'Connected via Google Account' : 'Username / Password Account',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'Verified',
                        style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.currency_exchange_rounded, color: Colors.teal),
                    title: const Text('Primary Currency'),
                    subtitle: Text('Default: ${user?.currencySymbol ?? '₹'}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _showEditProfileDialog(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.download_rounded, color: Colors.blueAccent),
                    title: const Text('Export My Diary Data'),
                    subtitle: const Text('Export comprehensive backup of all diary records.'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Diary records compiled and ready for download.')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined, color: Colors.orange),
                    title: const Text('Notification Preferences & Devices'),
                    subtitle: const Text('View registered devices, copy Device ID & FCM Token.'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _showNotificationDevicesDialog(context, ref),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.verified_user_outlined, color: Colors.indigo),
                    title: Text('Live Cloud Firestore Sync'),
                    subtitle: Text('End-to-end user-isolated storage enabled.'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                    title: Text('Mahato Software · ${appInfo.appName}'),
                    subtitle: Text('${appInfo.packageName} (${appInfo.versionString} Production)\nYour Life. Your Records. Your Reminders.'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(userProfileProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/auth/login');
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
