import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentRecord {
  final String id;
  final String userId;
  final String title;
  final String category; // 'Invoices', 'Receipts', 'Warranties', 'School Receipts', 'Identity', 'Other'
  final String fileUrl;
  final String? storagePath;
  final String mimeType;
  final int fileSizeBytes;
  final String? folder;
  final DateTime? expiryDate;
  final bool isIdentityDocument;
  final String? extractedText;
  final String? fileHash;
  final String? relatedProductId;
  final String? relatedInstallmentId;
  final String? relatedBillId;
  final List<String> tags;
  final String? notes;
  final DateTime createdAt;

  DocumentRecord({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.fileUrl,
    this.storagePath,
    required this.mimeType,
    required this.fileSizeBytes,
    this.folder,
    this.expiryDate,
    this.isIdentityDocument = false,
    this.extractedText,
    this.fileHash,
    this.relatedProductId,
    this.relatedInstallmentId,
    this.relatedBillId,
    this.tags = const [],
    this.notes,
    required this.createdAt,
  });

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  factory DocumentRecord.fromMap(Map<String, dynamic> map, String id) {
    return DocumentRecord(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'Other',
      fileUrl: map['fileUrl'] ?? '',
      storagePath: map['storagePath'],
      mimeType: map['mimeType'] ?? 'application/pdf',
      fileSizeBytes: map['fileSizeBytes'] ?? 0,
      folder: map['folder'] as String?,
      expiryDate: map['expiryDate'] is Timestamp
          ? (map['expiryDate'] as Timestamp).toDate()
          : (map['expiryDate'] != null ? DateTime.tryParse(map['expiryDate'].toString()) : null),
      isIdentityDocument: map['isIdentityDocument'] as bool? ?? false,
      extractedText: map['extractedText'] as String?,
      fileHash: map['fileHash'] as String?,
      relatedProductId: map['relatedProductId'],
      relatedInstallmentId: map['relatedInstallmentId'],
      relatedBillId: map['relatedBillId'],
      tags: List<String>.from(map['tags'] ?? []),
      notes: map['notes'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'category': category,
      'fileUrl': fileUrl,
      'storagePath': storagePath,
      'mimeType': mimeType,
      'fileSizeBytes': fileSizeBytes,
      if (folder != null) 'folder': folder,
      if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate!),
      'isIdentityDocument': isIdentityDocument,
      if (extractedText != null) 'extractedText': extractedText,
      if (fileHash != null) 'fileHash': fileHash,
      'relatedProductId': relatedProductId,
      'relatedInstallmentId': relatedInstallmentId,
      'relatedBillId': relatedBillId,
      'tags': tags,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
