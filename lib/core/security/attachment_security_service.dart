import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

enum FileValidationResult {
  valid,
  tooLarge,
  unsupportedType,
  dangerousExtension,
}

/// Centralized Attachment and File Security Service.
/// Restricts file sizes, blocks malicious MIME types and executable extensions.
class AttachmentSecurityService {
  final FirebaseStorage _storage;
  final Uuid _uuid = const Uuid();

  static const int maxFileSizeBytes = 15 * 1024 * 1024; // 15 MB

  static const Set<String> allowedMimeTypes = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/heic',
    'application/pdf',
    'audio/mpeg',
    'audio/mp4',
    'audio/x-m4a',
    'audio/aac',
    'audio/wav',
  };

  static const Set<String> dangerousExtensions = {
    'exe', 'bat', 'cmd', 'sh', 'php', 'js', 'apk', 'ipa', 'py', 'bin',
    'msi', 'html', 'htm', 'svg', 'vbs', 'ps1', 'jar', 'app', 'dmg'
  };

  AttachmentSecurityService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Validates file size, MIME type, and extension before upload.
  static FileValidationResult validateFile({
    required int sizeBytes,
    required String mimeType,
    required String fileName,
  }) {
    if (sizeBytes > maxFileSizeBytes) {
      return FileValidationResult.tooLarge;
    }

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase().trim() : '';
    if (dangerousExtensions.contains(ext)) {
      return FileValidationResult.dangerousExtension;
    }

    final cleanMime = mimeType.toLowerCase().trim();
    final isAllowed = allowedMimeTypes.contains(cleanMime) ||
        cleanMime.startsWith('image/') ||
        cleanMime.startsWith('audio/') ||
        cleanMime == 'application/pdf';

    if (!isAllowed) {
      return FileValidationResult.unsupportedType;
    }

    return FileValidationResult.valid;
  }

  /// Generates a tamper-proof, non-guessable storage path for a user document.
  String generateUserStoragePath({
    required String userId,
    required String category,
    required String originalFileName,
  }) {
    final ext = originalFileName.contains('.')
        ? originalFileName.split('.').last.toLowerCase().trim()
        : 'dat';
    final safeId = _uuid.v4();
    final cleanCategory = category.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();
    return 'users/$userId/$cleanCategory/$safeId.$ext';
  }

  /// Generates a tamper-proof storage path for a shared circle attachment.
  String generateCircleStoragePath({
    required String circleId,
    required String originalFileName,
  }) {
    final ext = originalFileName.contains('.')
        ? originalFileName.split('.').last.toLowerCase().trim()
        : 'dat';
    final safeId = _uuid.v4();
    return 'circles/$circleId/attachments/$safeId.$ext';
  }

  /// Deletes a file from Cloud Storage safely.
  Future<void> deleteStorageFile(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      final ref = _storage.ref(storagePath);
      await ref.delete();
    } catch (_) {}
  }
}
