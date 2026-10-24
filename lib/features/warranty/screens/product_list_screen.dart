import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/date_calculators.dart';
import '../../../core/utils/pdf_exporter.dart';
import '../../../core/widgets/status_badge.dart';
import 'product_form_screen.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Electronics',
    'Appliances',
    'Gadgets',
    'Furniture',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/diaries');
            }
          },
        ),
        title: const Text('Warranty & Purchase Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF Report',
            onPressed: () {
              final products = productsAsync.value ?? [];
              PdfExporter.generateWarrantyReport(products);
            },
          ),
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan Receipt with OCR',
            onPressed: () => context.push('/warranty/ocr'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/warranty/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search product name, brand, or tag...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: productsAsync.when(
                data: (products) {
                  var filtered = products;
                  if (_selectedCategory != 'All') {
                    filtered = filtered.where((p) => p.category == _selectedCategory).toList();
                  }
                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered
                        .where((p) =>
                            p.name.toLowerCase().contains(_searchQuery) ||
                            p.brand.toLowerCase().contains(_searchQuery) ||
                            p.tags.any((t) => t.toLowerCase().contains(_searchQuery)))
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No products found matching filters.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      final warrantyStatus = p.hasWarranty && p.warrantyEndDate != null
                          ? DateCalculators.getWarrantyStatus(p.warrantyEndDate!)
                          : 'no_warranty';
                      final daysRemaining = p.warrantyEndDate != null
                          ? p.warrantyEndDate!.difference(DateTime.now()).inDays
                          : 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(
                              p.category == 'Electronics'
                                  ? Icons.tv
                                  : p.category == 'Appliances'
                                      ? Icons.kitchen
                                      : p.category == 'Gadgets'
                                          ? Icons.laptop
                                          : Icons.shopping_bag,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('${p.brand} ${p.model ?? ''} • Purchased: ${AppFormatters.date(p.purchaseDate)}'),
                              Text('Seller: ${p.sellerInfo} • Price: ${AppFormatters.currency(p.price)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                              if (p.hasWarranty && p.warrantyEndDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        AppFormatters.daysRemaining(daysRemaining),
                                        style: TextStyle(
                                          color: daysRemaining > 30 ? Colors.green : (daysRemaining > 0 ? Colors.orange : Colors.red),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (p.isCustomWarranty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.purple.shade200),
                                          ),
                                          child: Text(
                                            'Custom (${p.warrantyDurationMonths}m)',
                                            style: TextStyle(
                                              color: Colors.purple.shade800,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StatusBadge(status: warrantyStatus),
                            ],
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: Text(p.name),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Brand: ${p.brand}'),
                                      Text('Category: ${p.category}'),
                                      if (p.model != null) Text('Model: ${p.model}'),
                                      if (p.serialNumber != null) Text('Serial No: ${p.serialNumber}'),
                                      Text('Price: ${AppFormatters.currency(p.price)}'),
                                      Text('Purchase Date: ${AppFormatters.date(p.purchaseDate)}'),
                                      const Divider(height: 16),
                                      if (p.hasWarranty) ...[
                                        Text('Warranty Duration: ${p.warrantyDurationMonths} Months${p.isCustomWarranty ? " (Custom)" : ""}'),
                                        if (p.warrantyType != null) Text('Warranty Type: ${p.warrantyType}'),
                                        if (p.warrantyEndDate != null)
                                          Text('Warranty Expiry: ${AppFormatters.date(p.warrantyEndDate!)}'),
                                        if (p.extendedWarranty) const Text('Extended Warranty: Yes'),
                                      ] else ...[
                                        const Text('Warranty: None'),
                                      ],
                                      if (p.notes != null) Text('\nNotes: ${p.notes}'),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text('Close'),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Edit'),
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => ProductFormScreen(product: p),
                                        ),
                                      );
                                    },
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    onPressed: () async {
                                      final user = ref.read(userProfileProvider);
                                      if (user != null) {
                                        Navigator.pop(dialogContext);
                                        await ref.read(productRepositoryProvider).deleteProduct(user.uid, p.id);
                                        ref.invalidate(productsProvider);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Product deleted successfully')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
