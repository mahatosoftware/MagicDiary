import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CircleInviteReadyDialog extends StatelessWidget {
  final String circleId;
  final String circleName;
  final String token;
  final String? deepLinkOverride;

  const CircleInviteReadyDialog({
    super.key,
    required this.circleId,
    required this.circleName,
    required this.token,
    this.deepLinkOverride,
  });

  String get deepLink =>
      deepLinkOverride ?? 'https://magicdiary.mahato.in/join/$token';

  String get shareMessage =>
      'Join my Magic Circle "$circleName" on Magic Diary! Tap the link or scan the QR code to collaborate:\n$deepLink';

  static Future<void> show(
    BuildContext context, {
    required String circleId,
    required String circleName,
    required String token,
    String? deepLinkOverride,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CircleInviteReadyDialog(
        circleId: circleId,
        circleName: circleName,
        token: token,
        deepLinkOverride: deepLinkOverride,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = deepLink;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.deepPurple.shade50,
                child: const Icon(Icons.groups_rounded, color: Colors.deepPurple, size: 32),
              ),
              const SizedBox(height: 14),
              const Text(
                'Circle Invite Link Ready!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Share this link or QR code via WhatsApp, SMS, or any messaging app to invite members to "$circleName".',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // QR Code
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: link,
                  version: QrVersions.auto,
                  size: 160.0,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.deepPurple,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Link Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        link,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Deep Link',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Circle invite link copied to clipboard!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick Share Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.green),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareMessage));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('WhatsApp message copied! Paste it in your chat.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.sms_outlined, size: 16, color: Colors.blue),
                      label: const Text('SMS / Other', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareMessage));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invite message copied! Ready to send.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
