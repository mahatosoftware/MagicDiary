import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/service_record.dart';

class ProductRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  ProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Product>> getProducts(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('products')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => Product.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      // Re-query without orderBy in case index or field is missing
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('products')
            .get();
        return snapshot.docs.map((doc) => Product.fromMap(doc.data(), doc.id)).toList();
      } catch (inner) {
        return const [];
      }
    }
  }

  Future<Product?> getProductById(String userId, String productId) async {
    if (userId.isEmpty || productId.isEmpty) return null;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('products')
          .doc(productId)
          .get();
      if (doc.exists && doc.data() != null) {
        return Product.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<Product> addProduct(String userId, Product product) async {
    final String newId = product.id.isEmpty ? _uuid.v4() : product.id;
    final Product newProduct = Product(
      id: newId,
      userId: userId,
      name: product.name,
      category: product.category,
      brand: product.brand,
      model: product.model,
      serialNumber: product.serialNumber,
      purchaseDate: product.purchaseDate,
      price: product.price,
      currency: product.currency,
      sellerInfo: product.sellerInfo,
      hasWarranty: product.hasWarranty,
      warrantyStartDate: product.warrantyStartDate,
      warrantyEndDate: product.warrantyEndDate,
      warrantyDurationMonths: product.warrantyDurationMonths,
      extendedWarranty: product.extendedWarranty,
      isCustomWarranty: product.isCustomWarranty,
      warrantyType: product.warrantyType,
      invoiceDocumentId: product.invoiceDocumentId,
      warrantyCardDocumentId: product.warrantyCardDocumentId,
      imageUrls: product.imageUrls,
      notes: product.notes,
      tags: product.tags,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('products')
        .doc(newId)
        .set(newProduct.toMap());
    return newProduct;
  }

  Future<void> updateProduct(String userId, Product product) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('products')
        .doc(product.id)
        .update(product.toMap());
  }

  Future<void> deleteProduct(String userId, String productId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('products')
        .doc(productId)
        .delete();
  }

  // Service Records
  Future<List<ServiceRecord>> getServiceRecords(String userId, String productId) async {
    if (userId.isEmpty || productId.isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('products')
          .doc(productId)
          .collection('serviceRecords')
          .orderBy('serviceDate', descending: true)
          .get();
      return snapshot.docs.map((doc) => ServiceRecord.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('products')
            .doc(productId)
            .collection('serviceRecords')
            .get();
        return snapshot.docs.map((doc) => ServiceRecord.fromMap(doc.data(), doc.id)).toList();
      } catch (inner) {
        return const [];
      }
    }
  }

  Future<ServiceRecord> addServiceRecord(String userId, ServiceRecord record) async {
    final String newId = record.id.isEmpty ? _uuid.v4() : record.id;
    final ServiceRecord newRecord = ServiceRecord(
      id: newId,
      productId: record.productId,
      serviceDate: record.serviceDate,
      serviceType: record.serviceType,
      workPerformed: record.workPerformed,
      totalCost: record.totalCost,
      currency: record.currency,
      serviceCenter: record.serviceCenter,
      invoiceDocumentId: record.invoiceDocumentId,
      nextServiceDate: record.nextServiceDate,
      notes: record.notes,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('products')
        .doc(record.productId)
        .collection('serviceRecords')
        .doc(newId)
        .set(newRecord.toMap());
    return newRecord;
  }
}
