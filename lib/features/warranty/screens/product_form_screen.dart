import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../models/product.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Map<String, String>? initialValues;
  final Product? product;

  const ProductFormScreen({
    super.key,
    this.initialValues,
    this.product,
  });

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
  late TextEditingController _customDurationController;

  String _category = 'Electronics';
  DateTime _purchaseDate = DateTime.now();
  bool _hasWarranty = true;
  bool _isCustomWarranty = false;
  int _warrantyMonths = 12;
  String _customUnit = 'Months'; // 'Months', 'Years', 'Days'
  String _warrantyType = 'Manufacturer';
  late DateTime _warrantyEndDate;
  bool _extendedWarranty = false;

  final List<String> _categories = [
    'Electronics',
    'Appliances',
    'Gadgets',
    'Furniture',
    'Other'
  ];

  final List<int> _standardMonths = [1, 3, 6, 12, 18, 24, 36, 60];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final init = widget.initialValues ?? {};

    _nameController = TextEditingController(text: p?.name ?? init['name'] ?? '');
    _brandController = TextEditingController(text: p?.brand ?? init['brand'] ?? '');
    _modelController = TextEditingController(text: p?.model ?? init['model'] ?? '');
    _priceController = TextEditingController(text: p != null ? p.price.toString() : init['price'] ?? '');
    _sellerController = TextEditingController(text: p?.sellerInfo ?? init['seller'] ?? '');
    _notesController = TextEditingController(text: p?.notes ?? init['notes'] ?? '');

    if (p != null) {
      if (_categories.contains(p.category)) {
        _category = p.category;
      }
      _purchaseDate = p.purchaseDate;
      _hasWarranty = p.hasWarranty;
      _warrantyMonths = p.warrantyDurationMonths;
      _isCustomWarranty = p.isCustomWarranty || !_standardMonths.contains(p.warrantyDurationMonths);
      _warrantyType = p.warrantyType ?? 'Manufacturer';
      _extendedWarranty = p.extendedWarranty;
      _warrantyEndDate = p.warrantyEndDate ?? _calculateDefaultEndDate(_purchaseDate, _warrantyMonths);
      _customDurationController = TextEditingController(text: _warrantyMonths.toString());
    } else {
      if (init['category'] != null && _categories.contains(init['category'])) {
        _category = init['category']!;
      }
      if (init['purchaseDate'] != null) {
        final parsed = DateTime.tryParse(init['purchaseDate']!);
        if (parsed != null) _purchaseDate = parsed;
      }
      if (init['hasWarranty'] != null) {
        _hasWarranty = init['hasWarranty'] == 'true';
      }
      if (init['warrantyType'] != null) {
        _warrantyType = init['warrantyType']!;
      }
      if (init['warrantyMonths'] != null) {
        final months = int.tryParse(init['warrantyMonths']!);
        if (months != null && months > 0) {
          _warrantyMonths = months;
          if (!_standardMonths.contains(months)) {
            _isCustomWarranty = true;
          }
        }
      }
      if (init['isCustomWarranty'] != null) {
        _isCustomWarranty = init['isCustomWarranty'] == 'true';
      }
      if (init['warrantyEndDate'] != null) {
        final endParsed = DateTime.tryParse(init['warrantyEndDate']!);
        if (endParsed != null) {
          _warrantyEndDate = endParsed;
          _isCustomWarranty = true;
        } else {
          _warrantyEndDate = _calculateDefaultEndDate(_purchaseDate, _warrantyMonths);
        }
      } else {
        _warrantyEndDate = _calculateDefaultEndDate(_purchaseDate, _warrantyMonths);
      }
      _customDurationController = TextEditingController(text: _warrantyMonths.toString());
    }
  }

  DateTime _calculateDefaultEndDate(DateTime purchase, int months) {
    return DateTime(purchase.year, purchase.month + months, purchase.day);
  }

  void _updateCustomEndDate() {
    final val = int.tryParse(_customDurationController.text.trim());
    if (val == null || val <= 0) return;

    setState(() {
      if (_customUnit == 'Months') {
        _warrantyMonths = val;
        _warrantyEndDate = DateTime(_purchaseDate.year, _purchaseDate.month + val, _purchaseDate.day);
      } else if (_customUnit == 'Years') {
        _warrantyMonths = val * 12;
        _warrantyEndDate = DateTime(_purchaseDate.year + val, _purchaseDate.month, _purchaseDate.day);
      } else if (_customUnit == 'Days') {
        _warrantyMonths = (val / 30.44).round().clamp(1, 1200);
        _warrantyEndDate = _purchaseDate.add(Duration(days: val));
      }
    });
  }

  void _onPurchaseDateChanged(DateTime newDate) {
    setState(() {
      _purchaseDate = newDate;
      if (_isCustomWarranty) {
        _updateCustomEndDate();
      } else {
        _warrantyEndDate = _calculateDefaultEndDate(_purchaseDate, _warrantyMonths);
      }
    });
  }

  Future<void> _pickCustomWarrantyEndDate() async {
    final initialDate = _warrantyEndDate.isAfter(_purchaseDate)
        ? _warrantyEndDate
        : _purchaseDate.add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _purchaseDate,
      lastDate: DateTime(_purchaseDate.year + 30),
      helpText: 'Select Warranty Expiration Date',
    );

    if (picked != null) {
      setState(() {
        _warrantyEndDate = picked;
        final diffDays = picked.difference(_purchaseDate).inDays;
        if (_customUnit == 'Days') {
          _customDurationController.text = diffDays.toString();
          _warrantyMonths = (diffDays / 30.44).round().clamp(1, 1200);
        } else if (_customUnit == 'Years') {
          final yrs = (diffDays / 365.25).round().clamp(1, 30);
          _customDurationController.text = yrs.toString();
          _warrantyMonths = yrs * 12;
        } else {
          final months = ((picked.year - _purchaseDate.year) * 12 + (picked.month - _purchaseDate.month)).clamp(1, 1200);
          _customDurationController.text = months.toString();
          _warrantyMonths = months;
        }
      });
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
    _customDurationController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(productRepositoryProvider);

    final DateTime? warrantyEnd = _hasWarranty ? _warrantyEndDate : null;
    final int finalMonths = _hasWarranty
        ? (_isCustomWarranty
            ? (int.tryParse(_customDurationController.text.trim()) != null
                ? _warrantyMonths
                : 1)
            : _warrantyMonths)
        : 0;

    final productToSave = Product(
      id: widget.product?.id ?? '',
      userId: user.uid,
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
      warrantyDurationMonths: finalMonths,
      extendedWarranty: _extendedWarranty,
      isCustomWarranty: _hasWarranty && _isCustomWarranty,
      warrantyType: _hasWarranty ? _warrantyType : null,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.product != null) {
      await repo.updateProduct(user.uid, productToSave);
    } else {
      await repo.addProduct(user.uid, productToSave);
    }

    ref.invalidate(productsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.product != null ? 'Product updated successfully!' : 'Product added successfully!'),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/warranty');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

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
        title: Text(isEditing ? 'Edit Purchased Product' : 'Add Purchased Product'),
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
                      isExpanded: true,
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
                  if (picked != null) {
                    _onPurchaseDateChanged(picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Has Manufacturer / Custom Warranty?'),
                subtitle: Text(_hasWarranty ? 'Warranty tracking is active' : 'No warranty coverage'),
                value: _hasWarranty,
                onChanged: (val) {
                  setState(() {
                    _hasWarranty = val;
                    if (val && _warrantyEndDate.isBefore(_purchaseDate)) {
                      _warrantyEndDate = _calculateDefaultEndDate(_purchaseDate, _warrantyMonths);
                    }
                  });
                },
              ),
              if (_hasWarranty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _isCustomWarranty ? -1 : _warrantyMonths,
                  decoration: const InputDecoration(
                    labelText: 'Warranty Duration',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 Month')),
                    DropdownMenuItem(value: 3, child: Text('3 Months')),
                    DropdownMenuItem(value: 6, child: Text('6 Months')),
                    DropdownMenuItem(value: 12, child: Text('12 Months (1 yr)')),
                    DropdownMenuItem(value: 18, child: Text('18 Months (1.5 yrs)')),
                    DropdownMenuItem(value: 24, child: Text('24 Months (2 yrs)')),
                    DropdownMenuItem(value: 36, child: Text('36 Months (3 yrs)')),
                    DropdownMenuItem(value: 60, child: Text('60 Months (5 yrs)')),
                    DropdownMenuItem(value: -1, child: Text('Custom Warranty...')),
                  ],
                  onChanged: (val) {
                    if (val == -1) {
                      setState(() {
                        _isCustomWarranty = true;
                        _customUnit = 'Months';
                        _customDurationController.text = _warrantyMonths.toString();
                        _updateCustomEndDate();
                      });
                    } else if (val != null) {
                      setState(() {
                        _isCustomWarranty = false;
                        _warrantyMonths = val;
                        _warrantyEndDate = _calculateDefaultEndDate(_purchaseDate, val);
                      });
                    }
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Extended Warranty', style: TextStyle(fontSize: 14)),
                  value: _extendedWarranty,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) => setState(() => _extendedWarranty = val ?? false),
                ),
                const SizedBox(height: 12),
                if (_isCustomWarranty) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune, color: Theme.of(context).primaryColor, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Custom Warranty Options',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isCustomWarranty = false;
                                    _warrantyMonths = 12;
                                    _warrantyEndDate = _calculateDefaultEndDate(_purchaseDate, 12);
                                  });
                                },
                                child: const Text('Use Preset', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _customDurationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Custom Duration *',
                                    hintText: 'e.g., 9',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.timer_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _updateCustomEndDate(),
                                  validator: (v) {
                                    if (!_hasWarranty || !_isCustomWarranty) return null;
                                    if (v == null || v.trim().isEmpty) return 'Enter duration';
                                    final n = int.tryParse(v.trim());
                                    if (n == null || n <= 0) return 'Invalid duration';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _customUnit,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: ['Months', 'Years', 'Days']
                                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _customUnit = val);
                                      _updateCustomEndDate();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            tileColor: Colors.white,
                            leading: const Icon(Icons.event_available, color: Colors.green),
                            title: const Text('Warranty Expiration Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              '${DateFormat('yyyy-MM-dd').format(_warrantyEndDate)} (${_warrantyEndDate.difference(DateTime.now()).inDays >= 0 ? '${_warrantyEndDate.difference(DateTime.now()).inDays} days left' : 'Expired'})',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.calendar_month, color: Colors.indigo),
                            onTap: _pickCustomWarrantyEndDate,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _warrantyType,
                            decoration: const InputDecoration(
                              labelText: 'Warranty Coverage / Provider',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.shield_outlined),
                            ),
                            items: [
                              'Manufacturer',
                              'Seller / Retailer',
                              'Extended / Third-Party',
                              'Accidental Damage Protection',
                              'Custom',
                            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _warrantyType = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Warranty valid until: ${DateFormat('yyyy-MM-dd').format(_warrantyEndDate)} ($_warrantyMonths months)',
                            style: TextStyle(color: Colors.blue.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                          onPressed: () {
                            setState(() {
                              _isCustomWarranty = true;
                              _customDurationController.text = _warrantyMonths.toString();
                              _customUnit = 'Months';
                            });
                          },
                          child: const Text('Customize', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  label: Text(isEditing ? 'Update Product Record' : 'Save Product Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
