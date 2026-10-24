import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/vehicle_models.dart';

class VehicleDashboardScreen extends ConsumerWidget {
  const VehicleDashboardScreen({super.key});

  void _showAddServiceDialog(
    BuildContext context,
    WidgetRef ref,
    List<Vehicle> vehicles, {
    String? defaultVehicleId,
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

    String selectedVehicleId = defaultVehicleId ?? vehicles.first.id;
    final odoController = TextEditingController();
    final typeController = TextEditingController(text: 'Periodic Service');
    final workController = TextEditingController();
    final costController = TextEditingController();
    final centerController = TextEditingController();
    DateTime serviceDate = DateTime.now();

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

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Log Service & Maintenance'),
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
                  onPressed: () async {
                    final odo = int.tryParse(odoController.text.trim()) ?? 0;
                    final cost = double.tryParse(costController.text.trim()) ?? 0.0;
                    const uuid = Uuid();

                    final newRecord = ServiceRecord(
                      id: uuid.v4(),
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
                    await repo.addServiceRecord(user.uid, newRecord);
                    ref.invalidate(vehicleServicesProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Service record logged successfully!'),
                          backgroundColor: Colors.teal,
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
                    final isPucExpiringSoon = v.pucExpiry.difference(DateTime.now()).inDays <= 15;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
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
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${v.currentOdometer} km',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Insurance Expiry', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(
                                        AppFormatters.date(v.insuranceExpiry),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('PUC Certificate', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(
                                        AppFormatters.date(v.pucExpiry),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isPucExpiringSoon ? Colors.red : Colors.black,
                                        ),
                                      ),
                                      if (isPucExpiringSoon)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: StatusBadge(status: 'expiring_soon'),
                                        ),
                                    ],
                                  ),
                                ),
                                if (v.loanEmiAmount != null) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Loan EMI', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        Text(
                                          AppFormatters.currency(v.loanEmiAmount!),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () => _showAddServiceDialog(
                                  context,
                                  ref,
                                  vehicles,
                                  defaultVehicleId: v.id,
                                ),
                                icon: const Icon(Icons.build, size: 14),
                                label: const Text('Log Service', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
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

            const SizedBox(height: 28),

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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.tealAccent,
                          child: Icon(Icons.build, color: Colors.teal),
                        ),
                        title: Text(s.serviceType, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${s.workPerformed}\nDate: ${AppFormatters.date(s.serviceDate)} • Odo: ${s.odometerReading} km • Center: ${s.serviceCenter}',
                        ),
                        trailing: Text(
                          AppFormatters.currency(s.totalCost),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal),
                        ),
                        isThreeLine: true,
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
