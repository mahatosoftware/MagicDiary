import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../models/vehicle_models.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  final Vehicle? vehicle;
  const VehicleFormScreen({super.key, this.vehicle});

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
  int _insuranceTenureMonths = 12;
  int _pucTenureMonths = 12;
  DateTime _insuranceStartDate = DateTime.now();
  DateTime _insuranceExpiry = Vehicle.calculateExpiryDate(DateTime.now(), 12);
  DateTime _pucStartDate = DateTime.now();
  DateTime _pucExpiry = Vehicle.calculateExpiryDate(DateTime.now(), 12);
  int _serviceIntervalMonths = 6;
  int _serviceIntervalKm = 10000;
  DateTime? _nextServiceDate = DateTime.now().add(const Duration(days: 120));

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      final v = widget.vehicle!;
      _nameController.text = v.name;
      _brandController.text = v.brand;
      _modelController.text = v.model;
      _regNoController.text = v.registrationNumber;
      _odometerController.text = v.currentOdometer.toString();
      if (v.loanEmiAmount != null) {
        _loanEmiController.text = v.loanEmiAmount!.toStringAsFixed(0);
      }
      if (v.fastagId != null) {
        _fastagController.text = v.fastagId!;
      }
      if (_vehicleTypes.contains(v.type)) {
        _type = v.type;
      } else {
        _vehicleTypes.add(v.type);
        _type = v.type;
      }
      _purchaseDate = v.purchaseDate;
      _insuranceTenureMonths = v.insuranceTenureMonths;
      _pucTenureMonths = v.pucTenureMonths;
      _insuranceStartDate = v.insuranceStartDate ?? (v.insuranceExpiry.isAfter(DateTime.now())
          ? v.insuranceExpiry.subtract(Duration(days: 30 * v.insuranceTenureMonths))
          : DateTime.now());
      _insuranceExpiry = v.insuranceExpiry;
      _pucStartDate = v.pucStartDate ?? (v.pucExpiry.isAfter(DateTime.now())
          ? v.pucExpiry.subtract(Duration(days: 30 * v.pucTenureMonths))
          : DateTime.now());
      _pucExpiry = v.pucExpiry;
      _serviceIntervalMonths = v.serviceIntervalMonths;
      _serviceIntervalKm = v.serviceIntervalKm;
      _nextServiceDate = v.nextServiceDate;
    }
  }

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
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? DateTime(2200),
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
        const SnackBar(content: Text('Please log in to manage your vehicles.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(vehicleRepositoryProvider);
      final isEditing = widget.vehicle != null;
      final vehicleId = isEditing ? widget.vehicle!.id : const Uuid().v4();

      final vehicleToSave = Vehicle(
        id: vehicleId,
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
        serviceIntervalMonths: _serviceIntervalMonths,
        serviceIntervalKm: _serviceIntervalKm,
        insuranceTenureMonths: _insuranceTenureMonths,
        pucTenureMonths: _pucTenureMonths,
        insuranceStartDate: _insuranceStartDate,
        pucStartDate: _pucStartDate,
      );

      if (isEditing) {
        await repo.updateVehicle(user.uid, vehicleToSave);
      } else {
        await repo.addVehicle(user.uid, vehicleToSave);
      }

      ref.invalidate(vehiclesProvider);
      ref.invalidate(remindersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? '${vehicleToSave.name} updated successfully!'
                : '${vehicleToSave.name} added to your garage!'),
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
            content: Text('Failed to save vehicle: $e'),
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
        title: Text(widget.vehicle != null
            ? 'Edit ${widget.vehicle!.name}'
            : 'Add Vehicle to Garage'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 88.0),
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

                  // Insurance Configuration Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.blue.shade50.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined, color: Colors.blue, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Insurance Policy & Tenure',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _insuranceTenureMonths == 6
                                      ? '6 Months'
                                      : (_insuranceTenureMonths == 36
                                          ? '3 Years'
                                          : (_insuranceTenureMonths == 60 ? '5 Years' : '1 Year')),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Policy Tenure:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ChoiceChip(
                                label: const Text('6 Months'),
                                selected: _insuranceTenureMonths == 6,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _insuranceTenureMonths = 6;
                                      _insuranceExpiry = Vehicle.calculateExpiryDate(_insuranceStartDate, 6);
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: const Text('1 Year (Standard)'),
                                selected: _insuranceTenureMonths == 12,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _insuranceTenureMonths = 12;
                                      _insuranceExpiry = Vehicle.calculateExpiryDate(_insuranceStartDate, 12);
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: const Text('3 Years (4W New)'),
                                selected: _insuranceTenureMonths == 36,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _insuranceTenureMonths = 36;
                                      _insuranceExpiry = Vehicle.calculateExpiryDate(_insuranceStartDate, 36);
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: const Text('5 Years (2W New)'),
                                selected: _insuranceTenureMonths == 60,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _insuranceTenureMonths = 60;
                                      _insuranceExpiry = Vehicle.calculateExpiryDate(_insuranceStartDate, 60);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _pickDate(
                                    context: context,
                                    initialDate: _insuranceStartDate,
                                    onPicked: (d) {
                                      _insuranceStartDate = d;
                                      _insuranceExpiry = Vehicle.calculateExpiryDate(d, _insuranceTenureMonths);
                                    },
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Start / Issue Date',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.event, size: 14, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                dateFormat.format(_insuranceStartDate),
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _pickDate(
                                    context: context,
                                    initialDate: _insuranceExpiry,
                                    onPicked: (d) => _insuranceExpiry = d,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.blue.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Expiry Date *',
                                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.event_available, size: 14, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                dateFormat.format(_insuranceExpiry),
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reminder will recur automatically every ${_insuranceTenureMonths == 6 ? "6 months" : (_insuranceTenureMonths == 36 ? "3 years" : (_insuranceTenureMonths == 60 ? "5 years" : "year"))}.',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // PUC Configuration Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.green.shade50.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.eco_outlined, color: Colors.green, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'PUC Certificate & Validity',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _pucTenureMonths == 6 ? '6 Months' : '1 Year',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Certificate Validity:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ChoiceChip(
                                label: const Text('6 Months (BS-III & older)'),
                                selected: _pucTenureMonths == 6,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _pucTenureMonths = 6;
                                      _pucExpiry = Vehicle.calculateExpiryDate(_pucStartDate, 6);
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: const Text('1 Year (BS-IV / BS-VI)'),
                                selected: _pucTenureMonths == 12,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _pucTenureMonths = 12;
                                      _pucExpiry = Vehicle.calculateExpiryDate(_pucStartDate, 12);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _pickDate(
                                    context: context,
                                    initialDate: _pucStartDate,
                                    onPicked: (d) {
                                      _pucStartDate = d;
                                      _pucExpiry = Vehicle.calculateExpiryDate(d, _pucTenureMonths);
                                    },
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Issue Date',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.event, size: 14, color: Colors.green),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                dateFormat.format(_pucStartDate),
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _pickDate(
                                    context: context,
                                    initialDate: _pucExpiry,
                                    onPicked: (d) => _pucExpiry = d,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.green.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Expiry Date *',
                                            style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.event_available, size: 14, color: Colors.green),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                dateFormat.format(_pucExpiry),
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reminder will recur automatically every ${_pucTenureMonths == 6 ? "6 months" : "year"}.',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Routine Servicing Configuration Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.orange.shade50.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.build_circle_outlined, color: Colors.orange, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Routine Servicing Schedule',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _serviceIntervalMonths == 12
                                      ? '1 Year'
                                      : '$_serviceIntervalMonths Months',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Service Interval (Months):',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ChoiceChip(
                                label: const Text('6 Months'),
                                selected: _serviceIntervalMonths == 6,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _serviceIntervalMonths = 6;
                                      if (_nextServiceDate != null) {
                                        _nextServiceDate = Vehicle.calculateExpiryDate(DateTime.now(), 6);
                                      }
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: const Text('10 Months'),
                                selected: _serviceIntervalMonths == 10,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _serviceIntervalMonths = 10;
                                      if (_nextServiceDate != null) {
                                        _nextServiceDate = Vehicle.calculateExpiryDate(DateTime.now(), 10);
                                      }
                                    });
                                  }
                                },
                              ),
                              ChoiceChip(
                                label: const Text('1 Year (12 Mo)'),
                                selected: _serviceIntervalMonths == 12,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _serviceIntervalMonths = 12;
                                      if (_nextServiceDate != null) {
                                        _nextServiceDate = Vehicle.calculateExpiryDate(DateTime.now(), 12);
                                      }
                                    });
                                  }
                                },
                              ),
                              ActionChip(
                                label: Text(![6, 10, 12].contains(_serviceIntervalMonths)
                                    ? 'Custom: $_serviceIntervalMonths Mo'
                                    : 'Custom...'),
                                avatar: ![6, 10, 12].contains(_serviceIntervalMonths)
                                    ? const Icon(Icons.check, size: 16)
                                    : const Icon(Icons.edit, size: 16),
                                onPressed: () async {
                                  final controller = TextEditingController(text: _serviceIntervalMonths.toString());
                                  final customVal = await showDialog<int>(
                                    context: context,
                                    builder: (dlgCtx) => AlertDialog(
                                      title: const Text('Custom Service Interval'),
                                      content: TextField(
                                        controller: controller,
                                        autofocus: true,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Interval in Months',
                                          hintText: 'e.g. 4, 8, 10, 18',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dlgCtx),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final parsed = int.tryParse(controller.text.trim());
                                            if (parsed != null && parsed > 0 && parsed <= 60) {
                                              Navigator.pop(dlgCtx, parsed);
                                            }
                                          },
                                          child: const Text('Apply'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (customVal != null) {
                                    setState(() {
                                      _serviceIntervalMonths = customVal;
                                      if (_nextServiceDate != null) {
                                        _nextServiceDate = Vehicle.calculateExpiryDate(DateTime.now(), customVal);
                                      }
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _pickDate(
                                    context: context,
                                    initialDate: _nextServiceDate ?? DateTime.now().add(Duration(days: 30 * _serviceIntervalMonths)),
                                    onPicked: (d) => _nextServiceDate = d,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.orange.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Next Service Date',
                                            style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 14, color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _nextServiceDate != null
                                                    ? dateFormat.format(_nextServiceDate!)
                                                    : 'Not scheduled',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.autorenew, size: 16),
                                label: Text(
                                  '+${_serviceIntervalMonths == 12 ? "1 Yr" : "$_serviceIntervalMonths Mo"}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _nextServiceDate = Vehicle.calculateExpiryDate(DateTime.now(), _serviceIntervalMonths);
                                  });
                                },
                              ),
                              if (_nextServiceDate != null) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: 'Clear Scheduled Service',
                                  onPressed: () => setState(() => _nextServiceDate = null),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Routine service reminder will repeat every ${_serviceIntervalMonths == 12 ? "1 year" : "$_serviceIntervalMonths months"} (and milestone every $_serviceIntervalKm km).',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                          ),
                        ],
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
                        _isSaving
                            ? (widget.vehicle != null ? 'Updating Vehicle...' : 'Adding Vehicle...')
                            : (widget.vehicle != null ? 'Update Vehicle' : 'Save Vehicle to Garage'),
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
