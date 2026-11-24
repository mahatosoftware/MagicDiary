import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CircleQrScannerDialog extends StatefulWidget {
  const CircleQrScannerDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const CircleQrScannerDialog(),
    );
  }

  /// Robust code cleaner handling universal links, deep links, queries & fragments
  static String cleanScannedCode(String raw) {
    var code = raw.trim();
    if (code.contains('/join/')) {
      code = code.split('/join/').last;
    } else if (code.contains('/circle/')) {
      code = code.split('/circle/').last;
    } else if (code.contains('/circles/')) {
      code = code.split('/circles/').last;
    }

    if (code.contains('code=')) {
      final uri = Uri.tryParse(code);
      if (uri != null && uri.queryParameters.containsKey('code')) {
        code = uri.queryParameters['code']!;
      } else {
        code = code.split('code=').last.split('&').first;
      }
    }

    if (code.contains('?')) code = code.split('?').first;
    if (code.contains('#')) code = code.split('#').first;
    while (code.endsWith('/')) {
      code = code.substring(0, code.length - 1);
    }
    return code.trim().toUpperCase();
  }

  @override
  State<CircleQrScannerDialog> createState() => _CircleQrScannerDialogState();
}

class _CircleQrScannerDialogState extends State<CircleQrScannerDialog>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  StreamSubscription<BarcodeCapture>? _subscription;
  final TextEditingController _manualInputController = TextEditingController();
  late TabController _tabController;

  bool _isProcessing = false;
  bool _isTorchOn = false;
  String? _manualError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);

    _controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _subscription = _controller.barcodes.listen(_onDetect);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _subscription ??= _controller.barcodes.listen(_onDetect);
        if (!_controller.value.isRunning) {
          try {
            _controller.start();
          } catch (_) {}
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_subscription?.cancel());
        _subscription = null;
        if (_controller.value.isRunning) {
          unawaited(_controller.stop());
        }
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_controller.dispose());
    _manualInputController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || !mounted) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        final code = CircleQrScannerDialog.cleanScannedCode(raw);
        if (code.isNotEmpty) {
          _isProcessing = true;
          HapticFeedback.mediumImpact();
          Navigator.of(context).pop(code);
          break;
        }
      }
    }
  }

  void _submitManualCode() {
    final raw = _manualInputController.text.trim();
    if (raw.isEmpty) {
      setState(() => _manualError = 'Please enter an invitation code');
      return;
    }

    final code = CircleQrScannerDialog.cleanScannedCode(raw);
    if (code.isEmpty) {
      setState(() => _manualError = 'Invalid code entered');
      return;
    }

    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: Colors.deepPurple),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Join Magic Circle',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: Colors.deepPurple,
              indicatorColor: Colors.deepPurple,
              tabs: const [
                Tab(icon: Icon(Icons.camera_alt_outlined), text: 'Scan QR'),
                Tab(icon: Icon(Icons.keyboard_outlined), text: 'Enter Code'),
              ],
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Live Camera Scanner
                  Stack(
                    children: [
                      MobileScanner(
                        controller: _controller,
                        errorBuilder: (context, error) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.videocam_off_outlined, size: 48, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Camera unavailable: ${error.errorDetails?.message ?? error.errorCode.name}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () => _tabController.animateTo(1),
                                    icon: const Icon(Icons.keyboard),
                                    label: const Text('Enter Code Manually'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Viewfinder Overlay
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2.5),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                spreadRadius: 4,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Torch Toggle Button
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: Icon(
                              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              await _controller.toggleTorch();
                              setState(() => _isTorchOn = !_isTorchOn);
                            },
                          ),
                        ),
                      ),

                      // Instruction Banner
                      Positioned(
                        top: 16,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Point camera at a Circle QR Code',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Tab 2: Manual Code Entry
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Have an invite or group code?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the circle code (e.g. ABC2345) or one-time VIP code (e.g. IN-ABC123) below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _manualInputController,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 20,
                            letterSpacing: 3,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: 'CODE',
                            hintStyle: TextStyle(
                              letterSpacing: 2,
                              color: Colors.grey.shade400,
                            ),
                            errorText: _manualError,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.vpn_key_rounded),
                          ),
                          onSubmitted: (_) => _submitManualCode(),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _submitManualCode,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Join Circle', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
