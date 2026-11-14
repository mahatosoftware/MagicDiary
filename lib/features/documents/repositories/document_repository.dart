import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../reminders/models/reminder.dart';
import '../../reminders/repositories/reminder_repository.dart';
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
      folder: docRecord.folder,
      expiryDate: docRecord.expiryDate,
      isIdentityDocument: docRecord.isIdentityDocument,
      extractedText: docRecord.extractedText,
      fileHash: docRecord.fileHash,
      relatedProductId: docRecord.relatedProductId,
      relatedInstallmentId: docRecord.relatedInstallmentId,
      relatedBillId: docRecord.relatedBillId,
      tags: docRecord.tags,
      notes: docRecord.notes,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(userId).collection('documents').doc(newId).set(newDoc.toMap());

    // Sync expiry reminder if document has expiryDate
    final expRemId = 'reminder_doc_${newId}_exp';
    final remRepo = ReminderRepository(firestore: _firestore);
    if (newDoc.expiryDate != null) {
      try {
        await remRepo.syncReminder(
          userId,
          Reminder(
            id: expRemId,
            userId: userId,
            title: 'Document Expiry: ${newDoc.title}',
            description: '${newDoc.category} document (${newDoc.title}) expires on ${newDoc.expiryDate!.day}/${newDoc.expiryDate!.month}/${newDoc.expiryDate!.year}. Renew or update.',
            module: 'General',
            status: 'pending',
            dueDate: newDoc.expiryDate!,
            relatedId: newId,
            actionRoute: '/documents',
            actionType: 'Renew',
            priority: 'high',
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {}
    } else {
      try {
        await remRepo.deleteReminder(userId, expRemId);
      } catch (_) {}
    }

    return newDoc;
  }

  Future<void> deleteDocument(String userId, String docId) async {
    if (userId.isEmpty || docId.isEmpty) return;
    await _firestore.collection('users').doc(userId).collection('documents').doc(docId).delete();
    try {
      final remRepo = ReminderRepository(firestore: _firestore);
      await remRepo.deleteReminder(userId, 'reminder_doc_${docId}_exp');
    } catch (_) {}
  }
}
