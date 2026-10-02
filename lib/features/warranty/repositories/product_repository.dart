import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/mock_data.dart';
import '../models/product.dart';
import '../models/service_record.dart';

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final List<Product> _mockProducts = List.from(MockData.initialProducts);
  final List<ServiceRecord> _mockServices = List.from(MockData.initialServiceRecords);

  Future<List<Product>> getProducts(String userId, {bool isDemo = true}) async {
    if (isDemo) {
      return List.unmodifiable(_mockProducts);
    }
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('products')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => Product.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      return List.unmodifiable(_mockProducts);
    }
  }

  Future<Product?> getProductById(String userId, String productId, {bool isDemo = true}) async {
    if (isDemo) {
      return _mockProducts.firstWhere((p) => p.id == productId, orElse: () => _mockProducts.first);
    }
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
      // Fallback
    }
    return null;
  }

  Future<Product> addProduct(String userId, Product product, {bool isDemo = true}) async {
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
      invoiceDocumentId: product.invoiceDocumentId,
      warrantyCardDocumentId: product.warrantyCardDocumentId,
      imageUrls: product.imageUrls,
      notes: product.notes,
      tags: product.tags,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (isDemo) {
      _mockProducts.insert(0, newProduct);
      return newProduct;
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('products')
        .doc(newId)
        .set(newProduct.toMap());
    return newProduct;
  }

  Future<void> updateProduct(String userId, Product product, {bool isDemo = true}) async {
    if (isDemo) {
      final index = _mockProducts.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _mockProducts[index] = product;
      }
      return;
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('products')
        .doc(product.id)
        .update(product.toMap());
  }

  Future<void> deleteProduct(String userId, String productId, {bool isDemo = true}) async {
    if (isDemo) {
      _mockProducts.removeWhere((p) => p.id == productId);
      return;
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('products')
        .doc(productId)
        .delete();
  }

  // Service Records
  Future<List<ServiceRecord>> getServiceRecords(String userId, String productId, {bool isDemo = true}) async {
    if (isDemo) {
      return _mockServices.where((s) => s.productId == productId).toList();
    }
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
      return _mockServices.where((s) => s.productId == productId).toList();
    }
  }

  Future<ServiceRecord> addServiceRecord(String userId, ServiceRecord record, {bool isDemo = true}) async {
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

    if (isDemo) {
      _mockServices.insert(0, newRecord);
      return newRecord;
    }

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
