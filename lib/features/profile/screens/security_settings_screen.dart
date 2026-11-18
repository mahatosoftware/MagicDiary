import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/security/security.dart';
import '../../../core/services/data_backup_service.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _isLoading = true;
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  int _lockTimeoutMinutes = 5;
  bool _hideSensitiveNotifications = false;

  List<UserDeviceSession> _sessions = [];
  List<VoiceAssistantIntegration> _voiceIntegrations = [];

  @override
  void initState() {
    super.initState();
    _loadSecurityPreferences();
  }

  Future<void> _loadSecurityPreferences() async {
    setState(() => _isLoading = true);
    final storage = ref.read(secureStorageServiceProvider);
    final sessionService = ref.read(sessionManagementServiceProvider);
    final voiceService = ref.read(voiceIntegrationSecurityServiceProvider);
    final user = ref.read(userProfileProvider);

    final appLock = await storage.isAppLockConfigured();
    final biometric = await storage.isBiometricEnabled();
    final timeout = await storage.getLockTimeoutMinutes();
    final hideNotifs = await storage.isHideSensitiveNotifications();

    List<UserDeviceSession> sessions = [];
    List<VoiceAssistantIntegration> voice = [];
    if (user != null) {
      sessions = await sessionService.getSessions(user.uid);
      voice = await voiceService.getIntegrations(user.uid);
    }

    if (mounted) {
      setState(() {
        _appLockEnabled = appLock;
        _biometricEnabled = biometric;
        _lockTimeoutMinutes = timeout;
        _hideSensitiveNotifications = hideNotifs;
        _sessions = sessions;
        _voiceIntegrations = voice;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    final storage = ref.read(secureStorageServiceProvider);
    final audit = ref.read(securityAuditServiceProvider);
    final user = ref.read(userProfileProvider);

    if (value) {
      // Prompt to create a 4-digit PIN
      _showSetPinDialog();
    } else {
      await storage.clearAppLockPin();
      await storage.setBiometricEnabled(false);
      setState(() {
        _appLockEnabled = false;
        _biometricEnabled = false;
      });
      if (user != null) {
        await audit.logSecurityEvent(
          userId: user.uid,
          action: 'app_lock_disabled',
          status: 'success',
        );
      }
    }
  }

  void _showSetPinDialog() {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Set 4-Digit Security PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create a PIN to protect Magic Diary when returning from other apps or background.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: 'Enter 4-Digit PIN',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
                    setDialogState(() => errorText = 'PIN must be exactly 4 digits');
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(() => errorText = 'PINs do not match');
                    return;
                  }

                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  final hash = DataEncryptionService.hashWithSalt(pin);
                  final storage = ref.read(secureStorageServiceProvider);
                  await storage.setAppLockPin(hash);

                  final user = ref.read(userProfileProvider);
                  if (user != null) {
                    await ref.read(securityAuditServiceProvider).logSecurityEvent(
                          userId: user.uid,
                          action: 'app_lock_enabled',
                          status: 'success',
                        );
                  }

                  setState(() => _appLockEnabled = true);
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('App Lock enabled successfully!')),
                    );
                  }
                },
                child: const Text('Save PIN'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportData() async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Identity for Export'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To protect your private diaries and confidential records, please confirm your password before exporting.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Account Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final exportService = ref.read(dataExportSecurityServiceProvider);
                final package = await exportService.generateExportPackage(
                  userId: user.uid,
                  reauthPassword: passwordController.text.trim(),
                );

                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (exportCtx) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.inventory_2_rounded, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('Choose Export Format'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compiled ${package.data.keys.length} diary modules for @${user.username}.\nSelect your preferred backup package format:',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Icon(Icons.archive_rounded, color: Colors.white, size: 20),
                          ),
                          title: const Text('Complete ZIP Backup (.zip)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Includes all raw JSONs, CSV ledger & PDF book', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            Navigator.pop(exportCtx);
                            try {
                              await DataBackupService.shareZipBackup(package: package, profile: user);
                            } catch (err) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP Export Error: $err')));
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade700,
                            child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                          ),
                          title: const Text('Printable PDF Book (.pdf)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Executive report of household, vehicles, bills & ledgers', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            Navigator.pop(exportCtx);
                            try {
                              await DataBackupService.sharePdfBook(package: package, profile: user);
                            } catch (err) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Export Error: $err')));
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.code_rounded, color: Colors.white, size: 20),
                          ),
                          title: const Text('Structured JSON Data (.json)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Single machine-readable file for migration and backup', style: TextStyle(fontSize: 11)),
                          onTap: () async {
                            Navigator.pop(exportCtx);
                            try {
                              await DataBackupService.shareJsonExport(package: package);
                            } catch (err) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('JSON Export Error: $err')));
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(exportCtx), child: const Text('Cancel')),
                    ],
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: ${e.toString().replaceFirst('Exception: ', '')}')),
                );
              }
            },
            child: const Text('Verify & Export'),
          ),
        ],
      ),
    );
  }

  void _showRecentSecurityActivity() {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return FutureBuilder<List<SecurityAuditLog>>(
            future: ref.read(securityAuditServiceProvider).getRecentLogs(user.uid),
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Security Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (logs.isEmpty)
                    const Expanded(child: Center(child: Text('No security events recorded yet.')))
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final log = logs[idx];
                          final isSuccess = log.status == 'success';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                              child: Icon(
                                isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                                color: isSuccess ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),
                            title: Text(log.action.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text(DateFormat('dd MMM yyyy, HH:mm:ss').format(log.timestamp), style: const TextStyle(fontSize: 11)),
                            trailing: Text(log.status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSuccess ? Colors.green.shade700 : Colors.red.shade700)),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Privacy 🛡️'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          // Section 1: Device & App Lock
          const Text('Device & App Lock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline, color: Colors.indigo),
                  title: const Text('PIN App Lock'),
                  subtitle: const Text('Require a 4-digit PIN to open Magic Diary'),
                  value: _appLockEnabled,
                  onChanged: _toggleAppLock,
                ),
                if (_appLockEnabled) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint, color: Colors.teal),
                    title: const Text('Biometric Unlock'),
                    subtitle: const Text('Use Face ID or fingerprint when available'),
                    value: _biometricEnabled,
                    onChanged: (val) async {
                      await ref.read(secureStorageServiceProvider).setBiometricEnabled(val);
                      setState(() => _biometricEnabled = val);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined, color: Colors.orange),
                    title: const Text('Auto-Lock Inactivity Timeout'),
                    subtitle: Text(_lockTimeoutMinutes == 0 ? 'Never' : 'After $_lockTimeoutMinutes minutes of inactivity'),
                    trailing: DropdownButton<int>(
                      value: _lockTimeoutMinutes,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 min')),
                        DropdownMenuItem(value: 5, child: Text('5 mins')),
                        DropdownMenuItem(value: 15, child: Text('15 mins')),
                        DropdownMenuItem(value: 30, child: Text('30 mins')),
                        DropdownMenuItem(value: 0, child: Text('Never')),
                      ],
                      onChanged: (newVal) async {
                        if (newVal != null) {
                          await ref.read(secureStorageServiceProvider).setLockTimeoutMinutes(newVal);
                          setState(() => _lockTimeoutMinutes = newVal);
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section 2: Notification Privacy
          const Text('Notification Privacy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_off_outlined, color: Colors.purple),
              title: const Text('Hide Confidential Previews'),
              subtitle: const Text('Replaces financial balances, loan numbers, and medical names with private generic alerts on your lock screen'),
              value: _hideSensitiveNotifications,
              onChanged: (val) async {
                await ref.read(secureStorageServiceProvider).setHideSensitiveNotifications(val);
                setState(() => _hideSensitiveNotifications = val);
              },
            ),
          ),

          const SizedBox(height: 20),

          // Section 3: Active Device Sessions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Connected Devices & Sessions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              if (_sessions.length > 1)
                TextButton(
                  onPressed: () async {
                    final user = ref.read(userProfileProvider);
                    if (user != null) {
                      await ref.read(sessionManagementServiceProvider).revokeAllOtherSessions(user.uid);
                      await _loadSecurityPreferences();
                    }
                  },
                  child: const Text('Log out all other devices', style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: _sessions.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.devices, color: Colors.blue),
                    title: Text('Current Device Session Active'),
                    subtitle: Text('Encrypted via Firebase token'),
                  )
                : Column(
                    children: _sessions.map((s) {
                      return ListTile(
                        leading: Icon(
                          s.platform == 'ios' ? Icons.phone_iphone : (s.platform == 'android' ? Icons.phone_android : Icons.laptop),
                          color: s.isRevoked ? Colors.grey : (s.isCurrent ? Colors.green : Colors.blue),
                        ),
                        title: Row(
                          children: [
                            Text(s.deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (s.isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                                child: const Text('This Device', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(s.isRevoked ? 'Revoked' : 'Last active: ${DateFormat('dd MMM, HH:mm').format(s.lastActiveAt)}'),
                        trailing: (!s.isCurrent && !s.isRevoked)
                            ? TextButton(
                                onPressed: () async {
                                  final user = ref.read(userProfileProvider);
                                  if (user != null) {
                                    await ref.read(sessionManagementServiceProvider).revokeSession(user.uid, s.id);
                                    await _loadSecurityPreferences();
                                  }
                                },
                                child: const Text('Revoke', style: TextStyle(color: Colors.red)),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 20),

          // Section 4: Voice Assistant Integrations
          const Text('Voice Assistant Integrations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.mic_none_outlined, color: Colors.teal),
                  title: Text('Voice Security Boundaries'),
                  subtitle: Text('Voice assistants are restricted to read-only queries and cannot execute payments or transfers.'),
                ),
                if (_voiceIntegrations.isNotEmpty)
                  ..._voiceIntegrations.map((v) => ListTile(
                        title: Text(v.displayName),
                        subtitle: Text(v.isConnected ? 'Connected' : 'Disconnected'),
                        trailing: v.isConnected
                            ? TextButton(
                                onPressed: () async {
                                  final user = ref.read(userProfileProvider);
                                  if (user != null) {
                                    await ref.read(voiceIntegrationSecurityServiceProvider).disconnectIntegration(user.uid, v.provider);
                                    await _loadSecurityPreferences();
                                  }
                                },
                                child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                              )
                            : null,
                      )),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section 5: Data Management & Audits
          const Text('Data Protection & Compliance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.indigo),
                  title: const Text('Security Audit Trail'),
                  subtitle: const Text('Review recent logins, credential edits, and exports'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: _showRecentSecurityActivity,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: Colors.teal),
                  title: const Text('Export My Data'),
                  subtitle: const Text('Download a structured JSON archive of all your personal diaries'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: _exportData,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: const Text('Delete Account & Purge Data', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Permanently wipe all records, files, and account credentials'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => context.push('/profile/account-settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
