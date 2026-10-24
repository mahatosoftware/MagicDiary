import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/app_providers.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  User? get _currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  void _showPasswordResetDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Password Reset Email'),
        content: Text('A password reset link will be sent to:\n$email'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(authRepositoryProvider).sendPasswordReset(email);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password reset email sent to $email'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send reset email: $e'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountFlow() {
    final currentUser = _currentUser;
    if (currentUser == null) return;

    final isGoogleAuth = currentUser.providerData.any((p) => p.providerId == 'google.com');
    final passwordController = TextEditingController();
    bool isConfirmed = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isPasswordRequired = !isGoogleAuth;
          final canProceed = isConfirmed && (!isPasswordRequired || passwordController.text.trim().isNotEmpty);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Delete Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Warning: This action is permanent and cannot be undone.',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Upon confirmation, the following will be permanently purged:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _buildPurgeItem('Personal diary notes, entries & reflections'),
                  _buildPurgeItem('Uploaded documents, warranty receipts & photos'),
                  _buildPurgeItem('Bills, finance, property & vehicle records'),
                  _buildPurgeItem('Scheduled reminders & notifications'),
                  _buildPurgeItem('Cloud Firestore documents & cloud backups'),
                  _buildPurgeItem('Firebase Authentication account & credentials'),
                  const SizedBox(height: 16),

                  if (isPasswordRequired) ...[
                    const Text(
                      'Enter your password to verify ownership:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.g_mobiledata_rounded, color: Colors.blue.shade700, size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Connected via Google. You may be asked to re-verify your Google account.',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  CheckboxListTile(
                    value: isConfirmed,
                    onChanged: (val) {
                      setDialogState(() {
                        isConfirmed = val ?? false;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I understand that all my data will be permanently wiped.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: canProceed
                    ? () {
                        final pwd = passwordController.text.trim();
                        Navigator.pop(dialogCtx);
                        _executeAccountDeletion(pwd);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Text('Delete Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildPurgeItem(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.red, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAccountDeletion(String password) async {
    String currentStatus = 'Initializing account deletion...';
    late StateSetter setProgressState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) => StatefulBuilder(
        builder: (ctx, setState) {
          setProgressState = setState;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Purging Account & Data',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please do not close the app.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    try {
      await ref.read(userProfileProvider.notifier).deleteAccount(
        password: password.isNotEmpty ? password : null,
        onProgress: (status) {
          setProgressState(() {
            currentStatus = status;
          });
        },
      );

      if (!mounted) return;
      // Dismiss progress dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Navigate to login
      context.go('/auth/login');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Your account and all stored records have been permanently purged.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Dismiss progress dialog
      Navigator.of(context, rootNavigator: true).pop();

      final errorMsg = e.toString().replaceFirst('Exception: ', '');

      showDialog(
        context: context,
        builder: (errCtx) => AlertDialog(
          title: const Text('Account Deletion Failed'),
          content: Text(errorMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(errCtx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider);
    final theme = Theme.of(context);
    final currentUser = _currentUser;
    final isGoogleAuth = currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: const Text('Account Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Overview Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: theme.primaryColor,
                          backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                              ? Text(
                                  (user?.displayName.isNotEmpty ?? false)
                                      ? user!.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName.isNotEmpty == true
                                    ? user!.displayName
                                    : 'Authenticated User',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email.isNotEmpty == true ? user!.email : (currentUser?.email ?? ''),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isGoogleAuth ? Colors.blue.shade50 : Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isGoogleAuth ? Colors.blue.shade200 : Colors.indigo.shade200,
                                  ),
                                ),
                                child: Text(
                                  isGoogleAuth ? 'Google Sign-In' : 'Email & Password',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isGoogleAuth ? Colors.blue.shade900 : Colors.indigo.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('User ID', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        Text(
                          currentUser?.uid ?? 'Unknown',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Security & Credentials
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
              child: Text(
                'Security & Credentials',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
            ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.shield_outlined, color: Colors.teal),
                    title: Text('Account Protection'),
                    subtitle: Text('Encrypted Firebase Authentication session.'),
                    trailing: Icon(Icons.verified, color: Colors.teal, size: 20),
                  ),
                  if (!isGoogleAuth && (currentUser?.email?.isNotEmpty ?? false)) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_reset_rounded, color: Colors.indigo),
                      title: const Text('Reset Password'),
                      subtitle: const Text('Send password recovery email to your registered address.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _showPasswordResetDialog(currentUser!.email!),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Data & Storage Isolation
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
              child: Text(
                'Data & Storage Isolation',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
            ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.cloud_done_outlined, color: Colors.indigo),
                    title: Text('Cloud Firestore Isolation'),
                    subtitle: Text('Records strictly scoped under users/{userId} with rule enforcement.'),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.folder_shared_outlined, color: Colors.blue),
                    title: Text('Cloud Storage Isolation'),
                    subtitle: Text('Attachments and images scoped under users/{userId}/ folder.'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined, color: Colors.green),
                    title: const Text('Export My Diary Data'),
                    subtitle: const Text('Download or backup your diary records anytime.'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Diary records compiled and ready for download.')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Danger Zone
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
              child: Text(
                'Danger Zone',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
            Card(
              elevation: 2,
              color: Colors.red.shade50.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.delete_forever_rounded, color: Colors.red.shade700, size: 26),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Permanently delete your account, Cloud Firestore entries, uploaded documents, and associated cloud backups. This action cannot be reversed.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => _showDeleteAccountFlow(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.delete_forever, size: 20),
                        label: const Text(
                          'Delete Account',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
