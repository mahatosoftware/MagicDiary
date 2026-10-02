import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/mock_data.dart';
import '../models/document_record.dart';

class DocumentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final List<DocumentRecord> _mockDocs = List.from(MockData.initialDocuments);

  Future<List<DocumentRecord>> getDocuments(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.unmodifiable(_mockDocs);
    try {
      final snapshot = await _firestore.collection('users').doc(userId).collection('documents').get();
      return snapshot.docs.map((d) => DocumentRecord.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return List.unmodifiable(_mockDocs);
    }
  }

  Future<DocumentRecord> addDocument(String userId, DocumentRecord docRecord, {bool isDemo = true}) async {
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

    if (isDemo) {
      _mockDocs.add(newDoc);
      return newDoc;
    }

    await _firestore.collection('users').doc(userId).collection('documents').doc(newId).set(newDoc.toMap());
    return newDoc;
  }
}
