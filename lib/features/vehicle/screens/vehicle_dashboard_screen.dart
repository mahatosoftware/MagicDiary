import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';

class VehicleDashboardScreen extends ConsumerWidget {
  const VehicleDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final servicesAsync = ref.watch(vehicleServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle & Maintenance Diary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Garage',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            vehiclesAsync.when(
              data: (vehicles) {
                if (vehicles.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No vehicles added to garage yet.'),
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
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: Icon(
                                        v.type == 'Car' ? Icons.directions_car : Icons.two_wheeler,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          v.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          'Reg: ${v.registrationNumber}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Insurance Expiry', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(
                                      AppFormatters.date(v.insuranceExpiry),
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PUC Certificate', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Row(
                                      children: [
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
                                            padding: EdgeInsets.only(left: 4),
                                            child: StatusBadge(status: 'expiring_soon'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (v.loanEmiAmount != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Loan EMI', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(
                                        AppFormatters.currency(v.loanEmiAmount!),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple),
                                      ),
                                    ],
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

            const SizedBox(height: 24),

            Text(
              'Service & Maintenance History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            servicesAsync.when(
              data: (services) {
                if (services.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No service records logged.'),
                    ),
                  );
                }
                return Column(
                  children: services.map((s) {
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.tealAccent,
                          child: Icon(Icons.build, color: Colors.teal),
                        ),
                        title: Text(s.serviceType, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${s.workPerformed}\nService Date: ${AppFormatters.date(s.serviceDate)} • Odo: ${s.odometerReading} km'),
                        trailing: Text(
                          AppFormatters.currency(s.totalCost),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading service records: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
