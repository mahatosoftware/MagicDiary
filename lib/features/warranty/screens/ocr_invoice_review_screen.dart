import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'product_form_screen.dart';

class OcrInvoiceReviewScreen extends StatefulWidget {
  const OcrInvoiceReviewScreen({super.key});

  @override
  State<OcrInvoiceReviewScreen> createState() => _OcrInvoiceReviewScreenState();
}

class _OcrInvoiceReviewScreenState extends State<OcrInvoiceReviewScreen> {
  bool _isScanning = false;
  bool _hasScanned = false;

  final TextEditingController _merchantController = TextEditingController(text: 'Croma Electronics');
  final TextEditingController _productNameController = TextEditingController(text: 'Sony Soundbar System 300W');
  final TextEditingController _brandController = TextEditingController(text: 'Sony');
  final TextEditingController _amountController = TextEditingController(text: '24990.00');
  final TextEditingController _dateController = TextEditingController(text: '2026-09-15');
  final TextEditingController _invoiceNoController = TextEditingController(text: 'INV-2026-9921');

  @override
  void dispose() {
    _merchantController.dispose();
    _productNameController.dispose();
    _brandController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _invoiceNoController.dispose();
    super.dispose();
  }

  void _simulateScan() {
    setState(() {
      _isScanning = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _hasScanned = true;
        });
      }
    });
  }

  void _proceedToForm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(
          initialValues: {
            'name': _productNameController.text,
            'brand': _brandController.text,
            'price': _amountController.text,
            'seller': _merchantController.text,
            'purchaseDate': _dateController.text,
            'notes': 'Scanned Invoice #${_invoiceNoController.text}',
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/warranty');
            }
          },
        ),
        title: const Text('OCR Invoice Scanner'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.document_scanner, size: 40, color: Colors.blueAccent),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Invoice Extraction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Upload a purchase receipt or invoice to automatically extract product details, purchase date, & price.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (!_hasScanned) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade100,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Tap below to select sample receipt invoice image'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : _simulateScan,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt),
                        label: Text(_isScanning ? 'Scanning Receipt...' : 'Select & Scan Invoice'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Invoice extracted with 98% accuracy! Review details below.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _productNameController,
                decoration: const InputDecoration(labelText: 'Extracted Product Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brandController,
                      decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _merchantController,
                      decoration: const InputDecoration(labelText: 'Merchant / Seller', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _dateController,
                      decoration: const InputDecoration(labelText: 'Purchase Date', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _hasScanned = false),
                      child: const Text('Rescan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _proceedToForm,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Create Product Record'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
