import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../models/vehicle_models.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _regNoController = TextEditingController();
  final _odometerController = TextEditingController(text: '0');
  final _loanEmiController = TextEditingController();
  final _fastagController = TextEditingController();

  String _type = 'Car';
  final List<String> _vehicleTypes = ['Car', 'Bike', 'Scooter', 'EV', 'Truck', 'Other'];

  DateTime _purchaseDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _insuranceExpiry = DateTime.now().add(const Duration(days: 180));
  DateTime _pucExpiry = DateTime.now().add(const Duration(days: 90));
  DateTime? _nextServiceDate = DateTime.now().add(const Duration(days: 120));

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _regNoController.dispose();
    _odometerController.dispose();
    _loanEmiController.dispose();
    _fastagController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2040),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(userProfileProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add a vehicle.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(vehicleRepositoryProvider);
      const uuid = Uuid();
      final newVehicle = Vehicle(
        id: uuid.v4(),
        name: _nameController.text.trim(),
        type: _type,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        registrationNumber: _regNoController.text.trim().toUpperCase(),
        purchaseDate: _purchaseDate,
        currentOdometer: int.tryParse(_odometerController.text.trim()) ?? 0,
        insuranceExpiry: _insuranceExpiry,
        pucExpiry: _pucExpiry,
        loanEmiAmount: _loanEmiController.text.trim().isNotEmpty
            ? double.tryParse(_loanEmiController.text.trim())
            : null,
        nextServiceDate: _nextServiceDate,
        fastagId: _fastagController.text.trim().isNotEmpty
            ? _fastagController.text.trim()
            : null,
      );

      await repo.addVehicle(user.uid, newVehicle);
      ref.invalidate(vehiclesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newVehicle.name} added to your garage!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/vehicle');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add vehicle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/vehicle');
            }
          },
        ),
        title: const Text('Add Vehicle to Garage'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nickname
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Nickname *',
                      hintText: 'e.g. Family Creta, Daily Commute Hunter',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name for your vehicle' : null,
                  ),
                  const SizedBox(height: 16),

                  // Type and Brand Row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: const InputDecoration(
                            labelText: 'Type *',
                            border: OutlineInputBorder(),
                          ),
                          items: _vehicleTypes.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  Icon(
                                    t == 'Car' || t == 'EV'
                                        ? Icons.directions_car
                                        : Icons.two_wheeler,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(t),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _type = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _brandController,
                          decoration: const InputDecoration(
                            labelText: 'Brand / Make *',
                            hintText: 'e.g. Hyundai, Honda',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter brand' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Model and Registration
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _modelController,
                          decoration: const InputDecoration(
                            labelText: 'Model *',
                            hintText: 'e.g. Creta SX, Activa 6G',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter model' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _regNoController,
                          decoration: const InputDecoration(
                            labelText: 'Number Plate *',
                            hintText: 'e.g. KA-01-MJ-8821',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter registration number' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Odometer
                  TextFormField(
                    controller: _odometerController,
                    decoration: const InputDecoration(
                      labelText: 'Current Odometer (km) *',
                      prefixIcon: Icon(Icons.speed_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter current km';
                      if (int.tryParse(v.trim()) == null) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Certificates & Expiry Dates',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Purchase Date Picker Tile
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.shopping_bag_outlined, color: Colors.indigo),
                      title: const Text('Purchase Date'),
                      subtitle: Text(dateFormat.format(_purchaseDate)),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () => _pickDate(
                        context: context,
                        initialDate: _purchaseDate,
                        onPicked: (d) => _purchaseDate = d,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Insurance Expiry Date Picker Tile
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.shield_outlined, color: Colors.blue),
                      title: const Text('Insurance Policy Expiry *'),
                      subtitle: Text(dateFormat.format(_insuranceExpiry)),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () => _pickDate(
                        context: context,
                        initialDate: _insuranceExpiry,
                        onPicked: (d) => _insuranceExpiry = d,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // PUC Expiry Date Picker Tile
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.eco_outlined, color: Colors.green),
                      title: const Text('PUC Certificate Expiry *'),
                      subtitle: Text(dateFormat.format(_pucExpiry)),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () => _pickDate(
                        context: context,
                        initialDate: _pucExpiry,
                        onPicked: (d) => _pucExpiry = d,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Next Service Date
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.build_circle_outlined, color: Colors.orange),
                      title: const Text('Next Routine Service Due (Optional)'),
                      subtitle: Text(
                        _nextServiceDate != null
                            ? dateFormat.format(_nextServiceDate!)
                            : 'Not scheduled',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_nextServiceDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _nextServiceDate = null),
                            ),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                      onTap: () => _pickDate(
                        context: context,
                        initialDate: _nextServiceDate ?? DateTime.now().add(const Duration(days: 90)),
                        onPicked: (d) => _nextServiceDate = d,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Finance & Tags (Optional)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _loanEmiController,
                          decoration: const InputDecoration(
                            labelText: 'Monthly Loan EMI (₹)',
                            hintText: 'e.g. 18500',
                            prefixIcon: Icon(Icons.account_balance_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _fastagController,
                          decoration: const InputDecoration(
                            labelText: 'FASTag Wallet / Barcode ID',
                            hintText: 'e.g. FTG-8821901',
                            prefixIcon: Icon(Icons.toll_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveVehicle,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isSaving ? 'Adding Vehicle...' : 'Save Vehicle to Garage',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
