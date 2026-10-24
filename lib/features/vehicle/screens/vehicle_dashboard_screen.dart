import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../models/vehicle_models.dart';
import '../../../core/ads/admob_config.dart';
import '../../../core/ads/widgets/native_ad_card_widget.dart';

class VehicleDashboardScreen extends ConsumerWidget {
  const VehicleDashboardScreen({super.key});

  void _showAddServiceDialog(
    BuildContext context,
    WidgetRef ref,
    List<Vehicle> vehicles, {
    String? defaultVehicleId,
    ServiceRecord? existingRecord,
  }) {
    _showServiceRecordDialog(
      context,
      ref,
      vehicles,
      defaultVehicleId: defaultVehicleId,
      existingRecord: existingRecord,
    );
  }

  void _showServiceRecordDialog(
    BuildContext context,
    WidgetRef ref,
    List<Vehicle> vehicles, {
    String? defaultVehicleId,
    ServiceRecord? existingRecord,
  }) {
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add a vehicle to your garage first!'),
          action: SnackBarAction(
            label: 'Add Vehicle',
            onPressed: () => context.push('/vehicle/add'),
          ),
        ),
      );
      return;
    }

    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final isEditing = existingRecord != null;
    String selectedVehicleId = existingRecord?.vehicleId ?? defaultVehicleId ?? vehicles.first.id;
    if (!vehicles.any((v) => v.id == selectedVehicleId) && vehicles.isNotEmpty) {
      selectedVehicleId = vehicles.first.id;
    }

    final odoController = TextEditingController(
      text: existingRecord != null ? existingRecord.odometerReading.toString() : '',
    );
    final typeController = TextEditingController(
      text: existingRecord?.serviceType ?? 'Periodic Service',
    );
    final workController = TextEditingController(
      text: existingRecord?.workPerformed ?? '',
    );
    final costController = TextEditingController(
      text: existingRecord != null
          ? (existingRecord.totalCost % 1 == 0
              ? existingRecord.totalCost.toInt().toString()
              : existingRecord.totalCost.toString())
          : '',
    );
    final centerController = TextEditingController(
      text: existingRecord?.serviceCenter ?? '',
    );
    DateTime serviceDate = existingRecord?.serviceDate ?? DateTime.now();

    final serviceTypes = [
      'Periodic Service',
      'Oil Change',
      'Tyre Replacement',
      'Wheel Alignment',
      'Brake Service',
      'Battery Replacement',
      'Air Conditioner Filter',
      'Washing & Detailing',
      'Accident Repair',
      'Challan Payment',
      'Other',
    ];
    if (existingRecord != null && !serviceTypes.contains(existingRecord.serviceType)) {
      serviceTypes.add(existingRecord.serviceType);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note : Icons.build_circle_outlined,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  Text(isEditing ? 'Edit Service Record' : 'Log Service & Maintenance'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedVehicleId,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle *',
                          border: OutlineInputBorder(),
                        ),
                        items: vehicles.map((v) {
                          return DropdownMenuItem(
                            value: v.id,
                            child: Text('${v.name} (${v.registrationNumber})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedVehicleId = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: typeController.text,
                        decoration: const InputDecoration(
                          labelText: 'Service Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: serviceTypes.map((t) {
                          return DropdownMenuItem(value: t, child: Text(t));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => typeController.text = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        title: const Text('Service Date'),
                        subtitle: Text(DateFormat('dd MMM yyyy').format(serviceDate)),
                        trailing: const Icon(Icons.calendar_today, size: 18),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: serviceDate,
                            firstDate: DateTime(2010),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => serviceDate = picked);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: odoController,
                        decoration: const InputDecoration(
                          labelText: 'Odometer Reading (km) *',
                          hintText: 'e.g. 15000',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: workController,
                        decoration: const InputDecoration(
                          labelText: 'Work Performed / Notes',
                          hintText: 'e.g. Engine oil change, air filter replacement',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: costController,
                              decoration: const InputDecoration(
                                labelText: 'Total Cost (₹) *',
                                hintText: 'e.g. 4500',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: centerController,
                              decoration: const InputDecoration(
                                labelText: 'Service Center / Shop',
                                hintText: 'e.g. Authorized Center',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                  onPressed: () async {
                    final odo = int.tryParse(odoController.text.trim()) ?? 0;
                    final cost = double.tryParse(costController.text.trim()) ?? 0.0;
                    final recordId = isEditing ? existingRecord.id : const Uuid().v4();

                    final recordToSave = ServiceRecord(
                      id: recordId,
                      vehicleId: selectedVehicleId,
                      serviceDate: serviceDate,
                      odometerReading: odo,
                      serviceType: typeController.text.trim(),
                      workPerformed: workController.text.trim().isNotEmpty
                          ? workController.text.trim()
                          : 'Routine maintenance',
                      totalCost: cost,
                      serviceCenter: centerController.text.trim().isNotEmpty
                          ? centerController.text.trim()
                          : 'Workshop',
                    );

                    final repo = ref.read(vehicleRepositoryProvider);
                    if (isEditing) {
                      await repo.updateServiceRecord(user.uid, recordToSave);
                    } else {
                      await repo.addServiceRecord(user.uid, recordToSave);
                    }
                    ref.invalidate(vehicleServicesProvider);
                    ref.invalidate(financialTransactionsProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditing
                              ? 'Service record updated successfully!'
                              : 'Service record logged successfully!'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Update Record' : 'Save Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRenewInsuranceDialog(BuildContext context, WidgetRef ref, Vehicle vehicle) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final now = DateTime.now();
    // Default new expiry to 1 year after current expiry, or 1 year from now if already expired
    DateTime newExpiry = vehicle.insuranceExpiry.isAfter(now)
        ? vehicle.insuranceExpiry.add(const Duration(days: 365))
        : now.add(const Duration(days: 365));

    final premiumController = TextEditingController();
    final insurerController = TextEditingController();
    final policyNoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dateFormat = DateFormat('dd MMM yyyy');
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Renew Insurance: ${vehicle.name}',
                      style: const TextStyle(fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Current Expiry: ${dateFormat.format(vehicle.insuranceExpiry)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // New Expiry Date Picker
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: const Icon(Icons.calendar_month, color: Colors.blue),
                        title: const Text('New Policy Expiry Date *', style: TextStyle(fontSize: 13)),
                        subtitle: Text(
                          dateFormat.format(newExpiry),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        trailing: const Icon(Icons.edit_calendar, size: 20),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: newExpiry,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (picked != null) {
                            setState(() => newExpiry = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Quick Expiry Extension Chips
                      Row(
                        children: [
                          ActionChip(
                            label: const Text('+1 Year'),
                            onPressed: () {
                              setState(() {
                                final base = vehicle.insuranceExpiry.isAfter(DateTime.now())
                                    ? vehicle.insuranceExpiry
                                    : DateTime.now();
                                newExpiry = base.add(const Duration(days: 365));
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('+2 Years'),
                            onPressed: () {
                              setState(() {
                                final base = vehicle.insuranceExpiry.isAfter(DateTime.now())
                                    ? vehicle.insuranceExpiry
                                    : DateTime.now();
                                newExpiry = base.add(const Duration(days: 730));
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Premium Paid (Optional)
                      TextField(
                        controller: premiumController,
                        decoration: const InputDecoration(
                          labelText: 'Premium Paid (₹)',
                          hintText: 'e.g. 14200 (logs as vehicle expense)',
                          prefixIcon: Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      // Insurer & Policy No
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: insurerController,
                              decoration: const InputDecoration(
                                labelText: 'Insurance Provider',
                                hintText: 'e.g. HDFC ERGO, Acko',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: policyNoController,
                              decoration: const InputDecoration(
                                labelText: 'Policy Number',
                                hintText: 'e.g. POL-123456',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Renewal'),
                  onPressed: () async {
                    final premium = double.tryParse(premiumController.text.trim());
                    final repo = ref.read(vehicleRepositoryProvider);

                    await repo.renewInsurance(
                      user.uid,
                      vehicle,
                      newExpiryDate: newExpiry,
                      premiumAmount: premium,
                      insurer: insurerController.text.trim(),
                      policyNumber: policyNoController.text.trim(),
                    );

                    ref.invalidate(vehiclesProvider);
                    ref.invalidate(remindersProvider);
                    ref.invalidate(financialTransactionsProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${vehicle.name} insurance renewed until ${dateFormat.format(newExpiry)}! Reminder updated.',
                          ),
                          backgroundColor: Colors.blue.shade700,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUpdatePuccDialog(BuildContext context, WidgetRef ref, Vehicle vehicle) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final now = DateTime.now();
    // Default PUCC is typically 6 months or 1 year in India
    DateTime newExpiry = vehicle.pucExpiry.isAfter(now)
        ? vehicle.pucExpiry.add(const Duration(days: 180))
        : now.add(const Duration(days: 180));

    final feeController = TextEditingController();
    final centerController = TextEditingController();
    final certNoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dateFormat = DateFormat('dd MMM yyyy');
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.eco_outlined, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Update PUCC: ${vehicle.name}',
                      style: const TextStyle(fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Current Expiry: ${dateFormat.format(vehicle.pucExpiry)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // New Expiry Date Picker
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: const Icon(Icons.calendar_month, color: Colors.green),
                        title: const Text('New PUC Expiry Date *', style: TextStyle(fontSize: 13)),
                        subtitle: Text(
                          dateFormat.format(newExpiry),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        trailing: const Icon(Icons.edit_calendar, size: 20),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: newExpiry,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                          );
                          if (picked != null) {
                            setState(() => newExpiry = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Quick Expiry Extension Chips
                      Row(
                        children: [
                          ActionChip(
                            label: const Text('+6 Months'),
                            onPressed: () {
                              setState(() {
                                final base = vehicle.pucExpiry.isAfter(DateTime.now())
                                    ? vehicle.pucExpiry
                                    : DateTime.now();
                                newExpiry = base.add(const Duration(days: 180));
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('+1 Year (BS-VI)'),
                            onPressed: () {
                              setState(() {
                                final base = vehicle.pucExpiry.isAfter(DateTime.now())
                                    ? vehicle.pucExpiry
                                    : DateTime.now();
                                newExpiry = base.add(const Duration(days: 365));
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Testing Fee (Optional)
                      TextField(
                        controller: feeController,
                        decoration: const InputDecoration(
                          labelText: 'Test Fee (₹)',
                          hintText: 'e.g. 100 or 150',
                          prefixIcon: Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      // Center & Cert No
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: centerController,
                              decoration: const InputDecoration(
                                labelText: 'Testing Center',
                                hintText: 'e.g. IndianOil Pump RTO',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: certNoController,
                              decoration: const InputDecoration(
                                labelText: 'Certificate No.',
                                hintText: 'e.g. PUC-882190',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Certificate'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: () async {
                    final fee = double.tryParse(feeController.text.trim());
                    final repo = ref.read(vehicleRepositoryProvider);

                    await repo.renewPucc(
                      user.uid,
                      vehicle,
                      newExpiryDate: newExpiry,
                      testFee: fee,
                      testCenter: centerController.text.trim(),
                      certificateNumber: certNoController.text.trim(),
                    );

                    ref.invalidate(vehiclesProvider);
                    ref.invalidate(remindersProvider);
                    ref.invalidate(financialTransactionsProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${vehicle.name} PUC certificate updated until ${dateFormat.format(newExpiry)}! Reminder updated.',
                          ),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSellVehicleDialog(BuildContext context, WidgetRef ref, Vehicle vehicle) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final salePriceController = TextEditingController();
    final buyerController = TextEditingController();
    final notesController = TextEditingController();
    DateTime saleDate = DateTime.now();
    bool deleteServiceRecords = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dateFormat = DateFormat('dd MMM yyyy');
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.sell_outlined, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sell Vehicle: ${vehicle.name}',
                      style: const TextStyle(fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_car, color: Colors.teal, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${vehicle.brand} ${vehicle.model} (${vehicle.registrationNumber})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Current Odometer: ${vehicle.currentOdometer} km',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sale Price
                      TextField(
                        controller: salePriceController,
                        decoration: const InputDecoration(
                          labelText: 'Sale Price / Proceeds (₹) *',
                          hintText: 'e.g. 650000',
                          prefixIcon: Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(),
                          helperText: 'Records as Income in Financial Reports',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      // Sale Date
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: const Icon(Icons.calendar_today, color: Colors.teal, size: 20),
                        title: const Text('Sale Date', style: TextStyle(fontSize: 13)),
                        subtitle: Text(
                          dateFormat.format(saleDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        trailing: const Icon(Icons.edit_calendar, size: 20),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: saleDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => saleDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Buyer Name
                      TextField(
                        controller: buyerController,
                        decoration: const InputDecoration(
                          labelText: 'Buyer / Dealership Name (Optional)',
                          hintText: 'e.g. Spinny, Cars24, or Buyer Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Notes
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Sale Notes / Transfer Details (Optional)',
                          hintText: 'e.g. Sold with NOC, ownership transfer in progress',
                          prefixIcon: Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),

                      // Checkbox for deleting associated records
                      CheckboxListTile(
                        value: deleteServiceRecords,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.teal,
                        title: const Text(
                          'Remove all associated maintenance records',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Permanently delete all service and repair logs for this vehicle',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        onChanged: (val) {
                          if (val != null) setState(() => deleteServiceRecords = val);
                        },
                      ),

                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This vehicle will be removed from your garage, and all its active Insurance and PUC reminders will be cancelled.',
                                style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Confirm Sale & Remove'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                  onPressed: () async {
                    final price = double.tryParse(salePriceController.text.trim()) ?? 0.0;
                    final repo = ref.read(vehicleRepositoryProvider);

                    await repo.sellVehicle(
                      user.uid,
                      vehicle,
                      salePrice: price,
                      saleDate: saleDate,
                      buyerName: buyerController.text.trim(),
                      notes: notesController.text.trim(),
                      deleteServiceRecords: deleteServiceRecords,
                    );

                    ref.invalidate(vehiclesProvider);
                    ref.invalidate(vehicleServicesProvider);
                    ref.invalidate(remindersProvider);
                    ref.invalidate(financialTransactionsProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            price > 0
                                ? '${vehicle.name} marked as sold for ${AppFormatters.currency(price)}! Vehicle & associated records removed.'
                                : '${vehicle.name} marked as sold and removed from your garage.',
                          ),
                          backgroundColor: Colors.teal.shade800,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteVehicleDialog(BuildContext context, WidgetRef ref, Vehicle vehicle) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    bool deleteServiceRecords = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Remove ${vehicle.name}?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to remove ${vehicle.name} (${vehicle.registrationNumber}) from your garage? This will cancel all its scheduled insurance, PUC, and service reminders.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: deleteServiceRecords,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.red.shade700,
                    title: const Text(
                      'Delete associated service & maintenance records',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Check this if you sold or scrapped the vehicle and no longer need its repair history.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    onChanged: (val) {
                      if (val != null) setState(() => deleteServiceRecords = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                  onPressed: () async {
                    final repo = ref.read(vehicleRepositoryProvider);
                    await repo.deleteVehicle(
                      user.uid,
                      vehicle.id,
                      deleteServiceRecords: deleteServiceRecords,
                      deleteReminders: true,
                    );
                    ref.invalidate(vehiclesProvider);
                    ref.invalidate(vehicleServicesProvider);
                    ref.invalidate(remindersProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            deleteServiceRecords
                                ? '${vehicle.name} and all its service records were removed from your garage.'
                                : '${vehicle.name} was removed from your garage.',
                          ),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  },
                  child: const Text('Delete Vehicle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteServiceRecordDialog(BuildContext context, WidgetRef ref, ServiceRecord record) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Service Record?'),
          content: Text(
            'Are you sure you want to delete this "${record.serviceType}" record (${AppFormatters.currency(record.totalCost)})? This will also remove the corresponding expense from your financial reports.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                final repo = ref.read(vehicleRepositoryProvider);
                await repo.deleteServiceRecord(user.uid, record.id);
                ref.invalidate(vehicleServicesProvider);
                ref.invalidate(financialTransactionsProvider);

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service record deleted.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlertBanner(BuildContext context, WidgetRef ref, List<Vehicle> vehicles) {
    final now = DateTime.now();
    final urgentVehicles = <Map<String, dynamic>>[];

    for (final v in vehicles) {
      final daysIns = v.insuranceExpiry.difference(now).inDays;
      if (daysIns < 0) {
        urgentVehicles.add({
          'vehicle': v,
          'type': 'Insurance',
          'msg': '${v.name}: Insurance expired ${daysIns.abs()} days ago!',
          'isExpired': true,
          'action': () => _showRenewInsuranceDialog(context, ref, v),
        });
      } else if (daysIns <= 30) {
        urgentVehicles.add({
          'vehicle': v,
          'type': 'Insurance',
          'msg': '${v.name}: Insurance expires in $daysIns days',
          'isExpired': false,
          'action': () => _showRenewInsuranceDialog(context, ref, v),
        });
      }

      final daysPuc = v.pucExpiry.difference(now).inDays;
      if (daysPuc < 0) {
        urgentVehicles.add({
          'vehicle': v,
          'type': 'PUCC',
          'msg': '${v.name}: PUC certificate expired ${daysPuc.abs()} days ago!',
          'isExpired': true,
          'action': () => _showUpdatePuccDialog(context, ref, v),
        });
      } else if (daysPuc <= 15) {
        urgentVehicles.add({
          'vehicle': v,
          'type': 'PUCC',
          'msg': '${v.name}: PUC certificate expires in $daysPuc days',
          'isExpired': false,
          'action': () => _showUpdatePuccDialog(context, ref, v),
        });
      }
    }

    if (urgentVehicles.isEmpty) return const SizedBox.shrink();

    final hasExpired = urgentVehicles.any((item) => item['isExpired'] == true);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasExpired ? Colors.red.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasExpired ? Colors.red.shade300 : Colors.amber.shade300,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasExpired ? Icons.error_outline : Icons.warning_amber_rounded,
                color: hasExpired ? Colors.red.shade800 : Colors.amber.shade900,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasExpired
                      ? 'Action Required: Vehicle Documents Expired!'
                      : 'Upcoming Vehicle Renewals',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: hasExpired ? Colors.red.shade900 : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...urgentVehicles.map((item) {
            final isExpired = item['isExpired'] as bool;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: isExpired ? Colors.red : Colors.amber.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item['msg'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isExpired ? FontWeight.bold : FontWeight.w500,
                        color: isExpired ? Colors.red.shade900 : Colors.brown.shade800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: item['action'] as VoidCallback,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      item['type'] == 'Insurance' ? 'Renew' : 'Update',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isExpired ? Colors.red.shade900 : Colors.indigo.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusChip(int daysRemaining, String label) {
    if (daysRemaining < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.shade400, width: 0.8),
        ),
        child: Text(
          'Expired ${daysRemaining.abs()}d ago',
          style: TextStyle(color: Colors.red.shade900, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    } else if (daysRemaining <= 30) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.amber.shade500, width: 0.8),
        ),
        child: Text(
          'Expiring in ${daysRemaining}d',
          style: TextStyle(color: Colors.brown.shade900, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Valid (${daysRemaining}d)',
        style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final servicesAsync = ref.watch(vehicleServicesProvider);
    final theme = Theme.of(context);

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
        title: const Text('Vehicle & Maintenance Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Vehicle',
            onPressed: () => context.push('/vehicle/add'),
          ),
          vehiclesAsync.maybeWhen(
            data: (vehicles) => vehicles.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.build_circle_outlined),
                    tooltip: 'Log Service',
                    onPressed: () => _showAddServiceDialog(context, ref, vehicles),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vehicle/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert banner if any vehicle has expiring or expired insurance / PUCC
            vehiclesAsync.maybeWhen(
              data: (vehicles) => _buildAlertBanner(context, ref, vehicles),
              orElse: () => const SizedBox.shrink(),
            ),

            // Garage Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'My Garage',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/vehicle/add'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Vehicle'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            vehiclesAsync.when(
              data: (vehicles) {
                if (vehicles.isEmpty) {
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 20.0),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.directions_car_filled_outlined,
                                size: 48,
                                color: theme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Your Garage is Empty',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add your car, bike, scooter, or EV to track insurance, PUC renewals, servicing & FASTag in one place.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/vehicle/add'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Vehicle to Garage'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: vehicles.map((v) {
                    final now = DateTime.now();
                    final daysIns = v.insuranceExpiry.difference(now).inDays;
                    final daysPuc = v.pucExpiry.difference(now).inDays;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: (daysIns < 0 || daysPuc < 0)
                              ? Colors.red.shade200
                              : (daysIns <= 30 || daysPuc <= 15)
                                  ? Colors.amber.shade200
                                  : Colors.grey.shade200,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Header: Icon, Nickname, Registration, Odo, and Context Menu
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(
                                    v.type == 'Car' || v.type == 'EV'
                                        ? Icons.directions_car
                                        : Icons.two_wheeler,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${v.brand} ${v.model} • ${v.registrationNumber}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    '${v.currentOdometer} km',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  tooltip: 'Vehicle Options',
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      context.push('/vehicle/edit', extra: v);
                                    } else if (val == 'sell') {
                                      _showSellVehicleDialog(context, ref, v);
                                    } else if (val == 'renew_insurance') {
                                      _showRenewInsuranceDialog(context, ref, v);
                                    } else if (val == 'renew_pucc') {
                                      _showUpdatePuccDialog(context, ref, v);
                                    } else if (val == 'log_service') {
                                      _showAddServiceDialog(context, ref, vehicles, defaultVehicleId: v.id);
                                    } else if (val == 'delete') {
                                      _showDeleteVehicleDialog(context, ref, v);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit_outlined, size: 20),
                                        title: Text('Edit Vehicle Details'),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'sell',
                                      child: ListTile(
                                        leading: Icon(Icons.sell_outlined, size: 20, color: Colors.teal),
                                        title: Text('Sell Vehicle (Record Sale)'),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'renew_insurance',
                                      child: ListTile(
                                        leading: Icon(Icons.shield_outlined, size: 20, color: Colors.blue),
                                        title: Text('Renew Insurance'),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'renew_pucc',
                                      child: ListTile(
                                        leading: Icon(Icons.eco_outlined, size: 20, color: Colors.green),
                                        title: Text('Update PUCC'),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'log_service',
                                      child: ListTile(
                                        leading: Icon(Icons.build_circle_outlined, size: 20, color: Colors.teal),
                                        title: Text('Log Service'),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        title: Text('Delete Vehicle', style: TextStyle(color: Colors.red)),
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const Divider(height: 20),

                            // Insurance and PUCC Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Insurance Expiry
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _showRenewInsuranceDialog(context, ref, v),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.shield_outlined, size: 14, color: Colors.blue),
                                              SizedBox(width: 4),
                                              Text('Insurance Expiry', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            AppFormatters.date(v.insuranceExpiry),
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          _buildStatusChip(daysIns, 'Insurance'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // PUC Expiry
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _showUpdatePuccDialog(context, ref, v),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.eco_outlined, size: 14, color: Colors.green),
                                              SizedBox(width: 4),
                                              Text('PUC Certificate', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            AppFormatters.date(v.pucExpiry),
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          _buildStatusChip(daysPuc, 'PUCC'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Loan EMI (if configured)
                                if (v.loanEmiAmount != null) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Loan EMI', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          const SizedBox(height: 2),
                                          Text(
                                            AppFormatters.currency(v.loanEmiAmount!),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.purple,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // Optional FASTag and Next Service Row
                            if (v.fastagId != null || v.nextServiceDate != null) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  if (v.fastagId != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.toll_outlined, size: 13, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          'FASTag: ${v.fastagId}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  if (v.nextServiceDate != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.build_circle_outlined, size: 13, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Service Due: ${AppFormatters.date(v.nextServiceDate!)}',
                                          style: const TextStyle(fontSize: 11, color: Colors.orange),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Quick Action Buttons Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showRenewInsuranceDialog(context, ref, v),
                                  icon: const Icon(Icons.shield_outlined, size: 13, color: Colors.blue),
                                  label: const Text('Renew Insurance', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _showUpdatePuccDialog(context, ref, v),
                                  icon: const Icon(Icons.eco_outlined, size: 13, color: Colors.green),
                                  label: const Text('Update PUCC', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _showAddServiceDialog(
                                    context,
                                    ref,
                                    vehicles,
                                    defaultVehicleId: v.id,
                                  ),
                                  icon: const Icon(Icons.build, size: 13, color: Colors.teal),
                                  label: const Text('Log Service', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading vehicles: $err'),
            ),

            const SizedBox(height: 16),
            const NativeAdCardWidget(
              placement: AdMobConfig.placementVehicleInline,
            ),
            const SizedBox(height: 16),

            // Service History Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Service & Maintenance History',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                vehiclesAsync.maybeWhen(
                  data: (vehicles) => vehicles.isNotEmpty
                      ? TextButton.icon(
                          onPressed: () => _showAddServiceDialog(context, ref, vehicles),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Log Service'),
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            servicesAsync.when(
              data: (services) {
                if (services.isEmpty) {
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.handyman_outlined, color: Colors.grey, size: 36),
                            const SizedBox(height: 8),
                            const Text(
                              'No service records logged yet.',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Keep track of oil changes, tyre replacements, and maintenance bills.',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            vehiclesAsync.maybeWhen(
                              data: (vehicles) => vehicles.isNotEmpty
                                  ? OutlinedButton.icon(
                                      onPressed: () => _showAddServiceDialog(context, ref, vehicles),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Log First Service'),
                                    )
                                  : const SizedBox.shrink(),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: services.map((s) {
                    final matchingVehicle = vehiclesAsync.value?.where((v) => v.id == s.vehicleId).firstOrNull;
                    final vehiclePrefix = matchingVehicle != null ? '${matchingVehicle.name} • ' : '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showServiceRecordDialog(
                          context,
                          ref,
                          vehiclesAsync.value ?? [],
                          existingRecord: s,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.teal.shade50,
                                radius: 20,
                                child: Icon(Icons.build_circle_outlined, color: Colors.teal.shade800),
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
                                            s.serviceType,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          AppFormatters.currency(s.totalCost),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.teal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      s.workPerformed,
                                      style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$vehiclePrefix${AppFormatters.date(s.serviceDate)} • ${s.odometerReading} km • ${s.serviceCenter}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                    tooltip: 'Edit Service Record',
                                    onPressed: () => _showServiceRecordDialog(
                                      context,
                                      ref,
                                      vehiclesAsync.value ?? [],
                                      existingRecord: s,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    tooltip: 'Delete Service Record',
                                    onPressed: () => _showDeleteServiceRecordDialog(context, ref, s),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading service records: $err'),
            ),

            const SizedBox(height: 80), // Padding for FAB
          ],
        ),
      ),
    );
  }
}
