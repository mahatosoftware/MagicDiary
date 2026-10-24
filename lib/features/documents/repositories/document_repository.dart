import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/document_record.dart';

class DocumentRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  DocumentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<DocumentRecord>> getDocuments(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('documents')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((d) => DocumentRecord.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      try {
        final snapshot = await _firestore.collection('users').doc(userId).collection('documents').get();
        return snapshot.docs.map((d) => DocumentRecord.fromMap(d.data(), d.id)).toList();
      } catch (inner) {
        return const [];
      }
    }
  }

  Future<DocumentRecord> addDocument(String userId, DocumentRecord docRecord) async {
    final newId = docRecord.id.isEmpty ? _uuid.v4() : docRecord.id;
    final newDoc = DocumentRecord(
      id: newId,
      userId: userId,
      title: docRecord.title,
      category: docRecord.category,
      fileUrl: docRecord.fileUrl,
      storagePath: docRecord.storagePath,
      mimeType: docRecord.mimeType,
      fileSizeBytes: docRecord.fileSizeBytes,
      relatedProductId: docRecord.relatedProductId,
      relatedInstallmentId: docRecord.relatedInstallmentId,
      relatedBillId: docRecord.relatedBillId,
      tags: docRecord.tags,
      notes: docRecord.notes,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(userId).collection('documents').doc(newId).set(newDoc.toMap());
    return newDoc;
  }
}
