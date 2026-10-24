import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../models/property_models.dart';

class PropertyDashboardScreen extends ConsumerWidget {
  const PropertyDashboardScreen({super.key});

  void _showAddPropertyDialog(BuildContext context, WidgetRef ref, {Property? property}) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final isEditing = property != null;
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: property?.title ?? '');
    final addressController = TextEditingController(text: property?.address ?? '');
    final priceController = TextEditingController(
        text: property != null
            ? (property.purchasePrice % 1 == 0
                ? property.purchasePrice.toInt().toString()
                : property.purchasePrice.toString())
            : '');
    final taxController = TextEditingController(
        text: property != null
            ? (property.propertyTaxAmount % 1 == 0
                ? property.propertyTaxAmount.toInt().toString()
                : property.propertyTaxAmount.toString())
            : '');
    final rentController = TextEditingController(
        text: property?.monthlyRentIncome != null
            ? (property!.monthlyRentIncome! % 1 == 0
                ? property.monthlyRentIncome!.toInt().toString()
                : property.monthlyRentIncome!.toString())
            : '');

    String propertyType = property?.propertyType ?? 'Apartment';
    String taxFrequency = property?.propertyTaxFrequency ?? 'Annual';
    DateTime purchaseDate = property?.purchaseDate ?? DateTime.now().subtract(const Duration(days: 365));
    DateTime taxDueDate = property?.taxDueDate ?? DateTime.now().add(const Duration(days: 90));

    final propertyTypes = [
      'Apartment',
      'Villa',
      'Independent House',
      'Commercial',
      'Plot / Land',
      'Office Space',
      'Farmhouse',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.home_work, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text(isEditing ? 'Edit Property' : 'Add New Property'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Property Name / Identifier *',
                            hintText: 'e.g., Green Glen Apartment 302',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.apartment),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter property name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: propertyType,
                          decoration: const InputDecoration(
                            labelText: 'Property Type *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: propertyTypes.map((t) {
                            return DropdownMenuItem(value: t, child: Text(t));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => propertyType = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Full Address / Location *',
                            hintText: 'e.g., Tower 4, Flat 302, Bellandur, Bengaluru',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.place),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter property address'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Purchase Price *',
                                  hintText: 'e.g., 7500000',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(
                                  'Purchased:\n${DateFormat('dd MMM yyyy').format(purchaseDate)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: purchaseDate,
                                    firstDate: DateTime(1980),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) setState(() => purchaseDate = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: taxFrequency,
                          decoration: const InputDecoration(
                            labelText: 'Property Tax Frequency *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.update),
                          ),
                          items: Property.taxFrequencies.map((f) {
                            return DropdownMenuItem(value: f, child: Text(f));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => taxFrequency = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: taxController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: '$taxFrequency Tax *',
                                  hintText: 'e.g., 8500',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.receipt_long),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                icon: const Icon(Icons.event, size: 18),
                                label: Text(
                                  'Tax Due:\n${DateFormat('dd MMM yyyy').format(taxDueDate)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: taxDueDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                                  );
                                  if (picked != null) setState(() => taxDueDate = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: rentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Monthly Rental Income (Optional)',
                            hintText: 'e.g., 35000 (leave empty if self-occupied)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.savings),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final price = double.parse(priceController.text.trim());
                    final tax = double.parse(taxController.text.trim());
                    final rent = rentController.text.trim().isNotEmpty
                        ? double.tryParse(rentController.text.trim())
                        : null;

                    final savedProperty = Property(
                      id: property?.id ?? const Uuid().v4(),
                      title: titleController.text.trim(),
                      propertyType: propertyType,
                      address: addressController.text.trim(),
                      purchasePrice: price,
                      purchaseDate: purchaseDate,
                      propertyTaxAmount: tax,
                      propertyTaxFrequency: taxFrequency,
                      taxDueDate: taxDueDate,
                      monthlyRentIncome: rent,
                    );

                    final repo = ref.read(propertyRepositoryProvider);
                    await repo.addProperty(user.uid, savedProperty);
                    ref.invalidate(propertiesProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditing
                              ? 'Property "${savedProperty.title}" updated successfully!'
                              : 'Property "${savedProperty.title}" added successfully!'),
                          backgroundColor: Colors.indigo,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Update Property' : 'Save Property'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddMaintenanceDialog(
    BuildContext context,
    WidgetRef ref,
    List<Property> properties,
  ) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    if (properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add a property first before logging maintenance.'),
          action: SnackBarAction(
            label: 'Add Property',
            onPressed: () => _showAddPropertyDialog(context, ref),
          ),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final costController = TextEditingController();
    final contractorController = TextEditingController();

    String selectedPropertyId = properties.first.id;
    String category = 'Plumbing';
    DateTime maintDate = DateTime.now();

    final categories = [
      'Plumbing',
      'Painting',
      'Electrical',
      'Carpentry & Woodwork',
      'Renovation & Remodel',
      'Society Maintenance Fee',
      'Roofing & Waterproofing',
      'Pest Control',
      'HVAC / AC Service',
      'Appliance Repair',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.handyman, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Log Repair / Maintenance'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedPropertyId,
                          decoration: const InputDecoration(
                            labelText: 'Property *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home),
                          ),
                          items: properties.map((p) {
                            return DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                p.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedPropertyId = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Work Category *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: categories.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => category = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Work Description / Title *',
                            hintText: 'e.g., Master Bathroom Leak Repair',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter repair title'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: costController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Cost / Expense *',
                                  hintText: 'e.g., 2500',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(
                                  'Date:\n${DateFormat('dd MMM yyyy').format(maintDate)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: maintDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) setState(() => maintDate = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contractorController,
                          decoration: const InputDecoration(
                            labelText: 'Contractor / Technician Name & Contact',
                            hintText: 'e.g., Ramesh Plumber (9876543210)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final cost = double.parse(costController.text.trim());

                    final newMaint = PropertyMaintenance(
                      id: const Uuid().v4(),
                      propertyId: selectedPropertyId,
                      title: titleController.text.trim(),
                      category: category,
                      cost: cost,
                      date: maintDate,
                      contractorName: contractorController.text.trim().isNotEmpty
                          ? contractorController.text.trim()
                          : 'Self / Local Technician',
                    );

                    final repo = ref.read(propertyRepositoryProvider);
                    await repo.addMaintenance(user.uid, newMaint);
                    ref.invalidate(propertyMaintenancesProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Maintenance record logged successfully!'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  child: const Text('Save Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeletePropertyConfirmation(BuildContext context, WidgetRef ref, Property property) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Property?'),
        content: Text(
          'Are you sure you want to delete "${property.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(propertyRepositoryProvider);
              await repo.deleteProperty(user.uid, property.id);
              ref.invalidate(propertiesProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Property "${property.title}" deleted.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMaintenanceConfirmation(
      BuildContext context, WidgetRef ref, PropertyMaintenance maintenance) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Maintenance Record?'),
        content: Text(
          'Are you sure you want to delete "${maintenance.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(propertyRepositoryProvider);
              await repo.deleteMaintenance(user.uid, maintenance.id);
              ref.invalidate(propertyMaintenancesProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maintenance record deleted.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(propertiesProvider);
    final maintenancesAsync = ref.watch(propertyMaintenancesProvider);
    final theme = Theme.of(context);

    final properties = propertiesAsync.asData?.value ?? [];

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
        title: const Text('Home & Property Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home_work_outlined),
            tooltip: 'Add Property',
            onPressed: () => _showAddPropertyDialog(context, ref),
          ),
          if (properties.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.handyman_outlined),
              tooltip: 'Log Maintenance',
              onPressed: () => _showAddMaintenanceDialog(context, ref, properties),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (properties.isEmpty) {
            _showAddPropertyDialog(context, ref);
          } else {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Icon(Icons.add_home, color: Colors.white),
                        ),
                        title: const Text('Add New Property', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Register an apartment, villa, commercial space, or plot'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showAddPropertyDialog(context, ref);
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.build, color: Colors.white),
                        ),
                        title: const Text('Log Maintenance or Repair', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Keep track of painting, plumbing, renovation costs & contractors'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showAddMaintenanceDialog(context, ref, properties);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add to Diary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portfolio Summary Card (if properties exist)
            if (properties.isNotEmpty) ...[
              Card(
                elevation: 0,
                color: Colors.indigo.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.indigo.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.indigo.shade100,
                        child: const Icon(Icons.account_balance, color: Colors.indigo, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Real Estate Value',
                              style: TextStyle(fontSize: 13, color: Colors.indigo, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppFormatters.currency(
                                properties.fold(0.0, (sum, p) => sum + p.purchasePrice),
                              ),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${properties.length} ${properties.length == 1 ? 'Property' : 'Properties'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Section 1: My Properties
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'My Properties',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddPropertyDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Property'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            propertiesAsync.when(
              data: (props) {
                if (props.isEmpty) {
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.home_work_outlined, size: 56, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No property records yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add your apartments, independent houses, commercial plots, or villas to track purchase values, property tax due dates, and rental yields.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _showAddPropertyDialog(context, ref),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Property'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: props.map((p) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.indigo.shade50,
                                  child: const Icon(Icons.home, color: Colors.indigo),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              p.title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              p.propertyType,
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        p.address,
                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      _showAddPropertyDialog(context, ref, property: p);
                                    } else if (val == 'log_maint') {
                                      _showAddMaintenanceDialog(context, ref, props);
                                    } else if (val == 'delete') {
                                      _showDeletePropertyConfirmation(context, ref, p);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18, color: Colors.indigo),
                                          SizedBox(width: 8),
                                          Text('Edit Property'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'log_maint',
                                      child: Row(
                                        children: [
                                          Icon(Icons.handyman, size: 18, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Text('Log Maintenance'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete Property', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Purchase Value', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(
                                      AppFormatters.currency(p.purchasePrice),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Tax Due (${p.propertyTaxFrequency})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(
                                      '${AppFormatters.currency(p.propertyTaxAmount)} • ${DateFormat('dd MMM').format(p.taxDueDate)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (p.monthlyRentIncome != null && p.monthlyRentIncome! > 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.arrow_downward, size: 14, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Rental Yield: ${AppFormatters.currency(p.monthlyRentIncome!)} / month',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (err, stack) => Text('Error loading properties: $err'),
            ),

            const SizedBox(height: 28),

            // Section 2: Repairs & Maintenance History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Repairs & Renovations History',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (properties.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showAddMaintenanceDialog(context, ref, properties),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Log Work'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            maintenancesAsync.when(
              data: (maints) {
                if (maints.isEmpty) {
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.handyman_outlined, size: 48, color: Colors.orange.shade300),
                          const SizedBox(height: 10),
                          const Text(
                            'No maintenance logs yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Track renovation costs, plumber/electrician contacts, and society maintenance fees.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          if (properties.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            FilledButton.tonalIcon(
                              onPressed: () => _showAddMaintenanceDialog(context, ref, properties),
                              icon: const Icon(Icons.build),
                              label: const Text('Log Maintenance Record'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: maints.map((m) {
                    final matchedProp = properties.cast<Property?>().firstWhere(
                          (p) => p?.id == m.propertyId,
                          orElse: () => null,
                        );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.shade100,
                          child: Icon(_getMaintenanceIcon(m.category), color: Colors.brown.shade700),
                        ),
                        title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${matchedProp != null ? '${matchedProp.title} • ' : ''}${m.category} • ${DateFormat('dd MMM yyyy').format(m.date)}\nVendor: ${m.contractorName}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppFormatters.currency(m.cost),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              tooltip: 'Delete',
                              onPressed: () => _showDeleteMaintenanceConfirmation(context, ref, m),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (err, stack) => Text('Error loading maintenance: $err'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMaintenanceIcon(String category) {
    switch (category) {
      case 'Plumbing':
        return Icons.plumbing;
      case 'Painting':
        return Icons.format_paint;
      case 'Electrical':
        return Icons.electric_bolt;
      case 'Carpentry & Woodwork':
        return Icons.carpenter;
      case 'Renovation & Remodel':
        return Icons.construction;
      case 'Society Maintenance Fee':
        return Icons.receipt_long;
      case 'Roofing & Waterproofing':
        return Icons.roofing;
      case 'Pest Control':
        return Icons.bug_report;
      case 'HVAC / AC Service':
        return Icons.ac_unit;
      default:
        return Icons.handyman;
    }
  }
}
