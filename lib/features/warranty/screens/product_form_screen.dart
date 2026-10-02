import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../models/product.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Map<String, String>? initialValues;

  const ProductFormScreen({super.key, this.initialValues});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _priceController;
  late TextEditingController _sellerController;
  late TextEditingController _notesController;

  String _category = 'Electronics';
  DateTime _purchaseDate = DateTime.now();
  bool _hasWarranty = true;
  int _warrantyMonths = 12;
  bool _extendedWarranty = false;

  final List<String> _categories = [
    'Electronics',
    'Appliances',
    'Gadgets',
    'Furniture',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialValues ?? {};
    _nameController = TextEditingController(text: init['name'] ?? '');
    _brandController = TextEditingController(text: init['brand'] ?? '');
    _modelController = TextEditingController(text: init['model'] ?? '');
    _priceController = TextEditingController(text: init['price'] ?? '');
    _sellerController = TextEditingController(text: init['seller'] ?? '');
    _notesController = TextEditingController(text: init['notes'] ?? '');

    if (init['category'] != null && _categories.contains(init['category'])) {
      _category = init['category']!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _priceController.dispose();
    _sellerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(userProfileProvider);
    final isDemo = ref.read(isDemoModeProvider);
    final repo = ref.read(productRepositoryProvider);

    final DateTime? warrantyEnd = _hasWarranty
        ? DateTime(_purchaseDate.year, _purchaseDate.month + _warrantyMonths, _purchaseDate.day)
        : null;

    final newProduct = Product(
      id: '',
      userId: user?.uid ?? 'demo_user',
      name: _nameController.text.trim(),
      category: _category,
      brand: _brandController.text.trim(),
      model: _modelController.text.trim().isNotEmpty ? _modelController.text.trim() : null,
      purchaseDate: _purchaseDate,
      price: double.tryParse(_priceController.text.trim()) ?? 0.0,
      sellerInfo: _sellerController.text.trim(),
      hasWarranty: _hasWarranty,
      warrantyStartDate: _hasWarranty ? _purchaseDate : null,
      warrantyEndDate: warrantyEnd,
      warrantyDurationMonths: _warrantyMonths,
      extendedWarranty: _extendedWarranty,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repo.addProduct(user?.uid ?? 'demo_user', newProduct, isDemo: isDemo);
    ref.invalidate(productsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully!')),
      );
      context.go('/warranty');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Purchased Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  hintText: 'e.g., Sony Bravia 55" 4K TV',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter product name' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand / Manufacturer *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter brand' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model Number (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (₹) *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'Enter price' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sellerController,
                decoration: const InputDecoration(
                  labelText: 'Seller / Retailer Info *',
                  hintText: 'e.g., Croma, Amazon, Reliance Digital',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter seller info' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                title: const Text('Purchase Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_purchaseDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _purchaseDate = picked);
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Has Manufacturer Warranty?'),
                value: _hasWarranty,
                onChanged: (val) => setState(() => _hasWarranty = val),
              ),
              if (_hasWarranty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _warrantyMonths,
                        decoration: const InputDecoration(
                          labelText: 'Warranty Duration',
                          border: OutlineInputBorder(),
                        ),
                        items: [6, 12, 18, 24, 36, 60]
                            .map((m) => DropdownMenuItem(value: m, child: Text('$m Months (${m ~/ 12} yrs)')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _warrantyMonths = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Extended Warranty'),
                        value: _extendedWarranty,
                        onChanged: (val) => setState(() => _extendedWarranty = val ?? false),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes / Serial Details',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveProduct,
                  icon: const Icon(Icons.check),
                  label: const Text('Save Product Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
