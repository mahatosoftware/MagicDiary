import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum QrScanType {
  username,
  inviteToken,
  circleInviteToken,
  email,
  raw,
}

class QrScanResult {
  final QrScanType type;
  final String value;
  final String? uid;
  final String? displayName;
  final String? email;

  const QrScanResult({
    required this.type,
    required this.value,
    this.uid,
    this.displayName,
    this.email,
  });

  static QrScanResult parse(String rawText) {
    String text = rawText.trim();
    // Strip wrapping quotes if present
    if ((text.startsWith('"') && text.endsWith('"')) || (text.startsWith("'") && text.endsWith("'"))) {
      text = text.substring(1, text.length - 1).trim();
    }

    // 1. Check for JSON payload (e.g. {"username":"...", "uid":"...", "name":"...", "email":"..."})
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final map = jsonDecode(text);
        if (map is Map) {
          final token = (map['token'] ?? map['inviteToken'])?.toString();
          if (token != null && token.isNotEmpty) {
            return QrScanResult(type: QrScanType.inviteToken, value: token);
          }
          final username = (map['username'] ?? map['user'])?.toString();
          final uid = map['uid']?.toString();
          final displayName = (map['displayName'] ?? map['name'])?.toString();
          final email = map['email']?.toString();
          if (username != null && username.isNotEmpty) {
            final clean = username.replaceAll('@', '').trim().toUpperCase();
            return QrScanResult(
              type: QrScanType.username,
              value: clean,
              uid: uid,
              displayName: displayName,
              email: email,
            );
          } else if (uid != null && uid.isNotEmpty) {
            return QrScanResult(
              type: QrScanType.username,
              value: uid,
              uid: uid,
              displayName: displayName,
              email: email,
            );
          }
        }
      } catch (_) {}
    }

    // 2. Check for one-time diary invite link (deep link or web link)
    if (text.contains('/share/invite/')) {
      final token = text.split('/share/invite/').last.split('?').first.replaceAll('/', '').trim();
      if (token.isNotEmpty) {
        return QrScanResult(type: QrScanType.inviteToken, value: token);
      }
    }

    // 2b. Check for circle invite link (deep link or web link)
    if (text.contains('/circle/invite/')) {
      final token = text.split('/circle/invite/').last.split('?').first.replaceAll('/', '').trim();
      if (token.isNotEmpty) {
        return QrScanResult(type: QrScanType.circleInviteToken, value: token);
      }
    }

    // 2c. Check for unified domain join link (e.g. https://magicdiary.mahato.in/join/CODE)
    if (text.contains('/join/')) {
      final token = text.split('/join/').last.split('?').first.replaceAll('/', '').trim();
      if (token.isNotEmpty) {
        return QrScanResult(type: QrScanType.circleInviteToken, value: token);
      }
    }

    // 3. Check for UUID invite token (e.g. 8-4-4-4-12 hex chars)
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(text)) {
      return QrScanResult(type: QrScanType.inviteToken, value: text);
    }

    // 4. Check for user profile deep link (e.g. magicdiary://user/USERNAME?uid=...&name=...&email=...)
    final uri = Uri.tryParse(text);
    if (uri != null && (text.contains('/user/') || uri.host == 'user' || uri.path.contains('/user/'))) {
      String username = '';
      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last;
        username = (last == 'user' && uri.pathSegments.length > 1) ? uri.pathSegments[1] : last;
      }
      if (username.isEmpty && uri.queryParameters.containsKey('username')) {
        username = uri.queryParameters['username']!;
      }
      username = username.replaceAll('@', '').replaceAll('/', '').trim();
      final uid = uri.queryParameters['uid'];
      final name = uri.queryParameters['name'] != null ? Uri.decodeComponent(uri.queryParameters['name']!) : null;
      final email = uri.queryParameters['email'] != null ? Uri.decodeComponent(uri.queryParameters['email']!) : null;

      if (username.isNotEmpty) {
        return QrScanResult(
          type: QrScanType.username,
          value: username.toUpperCase(),
          uid: uid,
          displayName: name,
          email: email,
        );
      }
    }

    // 5. Check for email (e.g. mailto:bob@example.com or bob@example.com)
    final cleanEmail = text.replaceAll('mailto:', '').trim();
    if (cleanEmail.contains('@') && !cleanEmail.startsWith('@') && cleanEmail.contains('.')) {
      return QrScanResult(type: QrScanType.email, value: cleanEmail.toLowerCase());
    }

    // 6. Clean username (e.g. @KYZMPTR or KYZMPTR or /KYZMPTR/)
    final cleanUsername = text.replaceAll('@', '').replaceAll('/', '').trim();
    if (cleanUsername.isNotEmpty && cleanUsername.length <= 32 && !cleanUsername.contains(' ')) {
      return QrScanResult(type: QrScanType.username, value: cleanUsername.toUpperCase());
    }

    return QrScanResult(type: QrScanType.raw, value: text);
  }
}

class QrCodeScanDialog extends StatefulWidget {
  const QrCodeScanDialog({super.key});

  static Future<QrScanResult?> show(BuildContext context) {
    return showDialog<QrScanResult>(
      context: context,
      builder: (ctx) => const QrCodeScanDialog(),
    );
  }

  @override
  State<QrCodeScanDialog> createState() => _QrCodeScanDialogState();
}

class _QrCodeScanDialogState extends State<QrCodeScanDialog>
    with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  late final MobileScannerController _scannerController;
  late AnimationController _animController;
  String? _errorMessage;
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _inputController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _isProcessing = true;
        HapticFeedback.mediumImpact();
        _processInput(raw);
        break;
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final capture = await _scannerController.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null && raw.trim().isNotEmpty) {
            _processInput(raw);
            return;
          }
        }
      } else {
        setState(() {
          _errorMessage = 'No valid QR code found in selected image.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to analyze gallery image: $e';
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _inputController.text = text;
      _processInput(text);
    } else {
      setState(() {
        _errorMessage = 'Clipboard is empty. Copy a QR code payload or username first.';
      });
    }
  }

  void _processInput(String raw) {
    if (raw.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter or scan a valid QR code');
      return;
    }

    final result = QrScanResult.parse(raw);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.primaryColor.withValues(alpha: 0.12),
                      child: Icon(Icons.qr_code_scanner_rounded, color: theme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan QR Code',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Point camera at recipient profile QR code',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Live Camera Viewfinder with Overlay
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    color: Colors.black,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Live MobileScanner Camera
                        MobileScanner(
                          controller: _scannerController,
                          fit: BoxFit.cover,
                          onDetect: _onDetect,
                          errorBuilder: (context, error) {
                            return Container(
                              color: Colors.black87,
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 36),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Camera unavailable (${error.errorCode.name})',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Please pick from gallery or paste from clipboard below.',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Corner bounding box target
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),

                        // Animated scanning laser line
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return Positioned(
                              top: 45 + (_animController.value * 130),
                              child: Container(
                                width: 145,
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.tealAccent.withValues(alpha: 0.8),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Camera controls overlay (Torch + Switch Camera)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filledTonal(
                                icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, size: 18),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: _isTorchOn ? Colors.amberAccent : Colors.white,
                                ),
                                tooltip: 'Toggle Flashlight',
                                onPressed: () async {
                                  await _scannerController.toggleTorch();
                                  setState(() => _isTorchOn = !_isTorchOn);
                                },
                              ),
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.cameraswitch_rounded, size: 18),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                ),
                                tooltip: 'Switch Camera',
                                onPressed: () => _scannerController.switchCamera(),
                              ),
                            ],
                          ),
                        ),

                        const Positioned(
                          bottom: 8,
                          child: Text(
                            'Align QR code within frame',
                            style: TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Gallery Image & Clipboard Quick Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_rounded, size: 17),
                        label: const Text('Pick Image', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _pickImageFromGallery,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.content_paste_rounded, size: 17),
                        label: const Text('Paste Text', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _pasteFromClipboard,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Manual Text Input & Resolve
                TextField(
                  controller: _inputController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Or enter username / deep link',
                    hintText: 'e.g. @KYZMPTR or magicdiary://...',
                    prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.teal),
                      tooltip: 'Resolve',
                      onPressed: () => _processInput(_inputController.text),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: _processInput,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
