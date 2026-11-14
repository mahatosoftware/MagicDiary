import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

enum AttachmentCategory {
  receipt,
  invoice,
  policy,
  contract,
  certificate,
  identity,
  voiceNote,
  photo,
  other,
}

class AttachmentMetadata {
  final String id;
  final String userId;
  final String title;
  final String fileUrl;
  final String storagePath;
  final String mimeType;
  final int fileSizeBytes;
  final AttachmentCategory category;
  final String? relatedDiaryId;
  final String? relatedRecordId;
  final String? circleId;
  final DateTime? expiryDate;
  final String? extractedText;
  final List<String> tags;
  final DateTime createdAt;

  AttachmentMetadata({
    required this.id,
    required this.userId,
    required this.title,
    required this.fileUrl,
    required this.storagePath,
    required this.mimeType,
    required this.fileSizeBytes,
    this.category = AttachmentCategory.other,
    this.relatedDiaryId,
    this.relatedRecordId,
    this.circleId,
    this.expiryDate,
    this.extractedText,
    this.tags = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'fileUrl': fileUrl,
        'storagePath': storagePath,
        'mimeType': mimeType,
        'fileSizeBytes': fileSizeBytes,
        'category': category.name,
        'relatedDiaryId': relatedDiaryId,
        'relatedRecordId': relatedRecordId,
        'circleId': circleId,
        if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate!),
        if (extractedText != null) 'extractedText': extractedText,
        'tags': tags,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory AttachmentMetadata.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final parsed = DateTime.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return AttachmentMetadata(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      fileUrl: map['fileUrl'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      category: AttachmentCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => AttachmentCategory.other,
      ),
      relatedDiaryId: map['relatedDiaryId'] as String?,
      relatedRecordId: map['relatedRecordId'] as String?,
      circleId: map['circleId'] as String?,
      expiryDate: map['expiryDate'] != null ? parseDate(map['expiryDate']) : null,
      extractedText: map['extractedText'] as String?,
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: parseDate(map['createdAt']),
    );
  }
}

class AttachmentService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AttachmentService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _userAttachmentsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('documents');
  }

  Future<AttachmentMetadata> uploadAttachment({
    required String userId,
    required File file,
    required String title,
    required String mimeType,
    AttachmentCategory category = AttachmentCategory.other,
    String? relatedDiaryId,
    String? relatedRecordId,
    String? circleId,
    DateTime? expiryDate,
    List<String> tags = const [],
  }) async {
    final attachmentId = const Uuid().v4();
    final ext = file.path.split('.').last;
    final storagePath = 'users/$userId/attachments/$attachmentId.$ext';

    final ref = _storage.ref().child(storagePath);
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: mimeType),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();
    final fileSize = await file.length();

    final metadata = AttachmentMetadata(
      id: attachmentId,
      userId: userId,
      title: title,
      fileUrl: downloadUrl,
      storagePath: storagePath,
      mimeType: mimeType,
      fileSizeBytes: fileSize,
      category: category,
      relatedDiaryId: relatedDiaryId,
      relatedRecordId: relatedRecordId,
      circleId: circleId,
      expiryDate: expiryDate,
      tags: tags,
      createdAt: DateTime.now(),
    );

    await _userAttachmentsRef(userId).doc(attachmentId).set(metadata.toMap());
    return metadata;
  }

  Future<List<AttachmentMetadata>> getAttachmentsForRecord({
    required String userId,
    required String recordId,
  }) async {
    final snapshot = await _userAttachmentsRef(userId)
        .where('relatedRecordId', isEqualTo: recordId)
        .get();

    return snapshot.docs
        .map((d) => AttachmentMetadata.fromMap(d.data(), d.id))
        .toList();
  }

  Future<void> deleteAttachment({
    required String userId,
    required String attachmentId,
    required String storagePath,
  }) async {
    try {
      await _storage.ref().child(storagePath).delete();
    } catch (_) {}
    await _userAttachmentsRef(userId).doc(attachmentId).delete();
  }
}
