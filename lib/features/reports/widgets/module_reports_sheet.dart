import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/formatters.dart';
import '../../household/models/household_models.dart';
import '../../school_fees/models/school_fees_models.dart';
import '../../vehicle/models/vehicle_models.dart';
import '../../property/models/property_models.dart';
import '../models/report_models.dart';

class ModuleReportsSheet {
  static void showHouseholdReport(BuildContext context, {
    required List<HouseholdExpense> expenses,
    required ReportDateRange dateRange,
  }) {
    final periodExpenses = expenses.where((e) => dateRange.contains(e.dueDate)).toList();
    final totalSpent = periodExpenses.where((e) => e.status == 'paid').fold<double>(0, (s, e) => s + e.amount);
    final totalPending = periodExpenses.where((e) => e.status != 'paid').fold<double>(0, (s, e) => s + e.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.home_work_rounded, color: Colors.green, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Household Running Costs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Period: ${dateRange.label}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Summary Row
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Text('Paid Utilities', style: TextStyle(fontSize: 11, color: Colors.green)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppFormatters.currency(totalSpent),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      color: Colors.amber.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Text('Pending Due', style: TextStyle(fontSize: 11, color: Colors.amber)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppFormatters.currency(totalPending),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Itemized Household Bills (${periodExpenses.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              if (periodExpenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('No household expenses recorded in this period.', style: TextStyle(color: Colors.grey))),
                )
              else
                ...periodExpenses.map((h) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: h.status == 'paid' ? Colors.green.shade100 : Colors.amber.shade100,
                          child: Icon(
                            h.status == 'paid' ? Icons.check : Icons.hourglass_top,
                            color: h.status == 'paid' ? Colors.green.shade800 : Colors.amber.shade800,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          '${h.category} - ${h.providerName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Due: ${DateFormat('dd MMM yyyy').format(h.dueDate)} • ${h.frequency} • ${h.period}',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppFormatters.currency(h.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  static void showEducationReport(BuildContext context, {
    required List<Child> children,
    required List<FeeInstallment> installments,
    required ReportDateRange dateRange,
  }) {
    final childMap = {for (var c in children) c.id: c};
    final periodInstallments = installments.where((i) {
      final pDate = i.paidDate ?? i.dueDate;
      return dateRange.contains(pDate);
    }).toList();

    final totalPaid = periodInstallments.fold<double>(0, (s, i) => s + (i.paidAmount > 0 ? i.paidAmount : (i.status == 'paid' ? i.amount : 0)));
    final totalDue = periodInstallments.fold<double>(0, (s, i) => s + (i.amount - i.paidAmount));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.school_rounded, color: Colors.purple, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Education & School Fees Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Period: ${dateRange.label}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.purple.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Text('Fees Paid', style: TextStyle(fontSize: 11, color: Colors.purple)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppFormatters.currency(totalPaid),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Text('Pending Fees', style: TextStyle(fontSize: 11, color: Colors.orange)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppFormatters.currency(totalDue),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Child-wise Installments (${periodInstallments.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              if (periodInstallments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('No school fee installments in this period.', style: TextStyle(color: Colors.grey))),
                )
              else
                ...periodInstallments.map((inst) {
                  final child = childMap[inst.childId];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.shade100,
                        child: Text(child != null && child.name.isNotEmpty ? child.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        '${inst.title} • ${child?.name ?? "Child"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'School: ${child?.schoolName ?? "N/A"} • Due: ${DateFormat('dd MMM yyyy').format(inst.dueDate)}',
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(AppFormatters.currency(inst.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Text(inst.status.toUpperCase(), style: TextStyle(fontSize: 10, color: inst.status == 'paid' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  static void showVehicleReport(BuildContext context, {
    required List<Vehicle> vehicles,
    required List<ServiceRecord> services,
    required ReportDateRange dateRange,
  }) {
    final periodServices = services.where((s) => dateRange.contains(s.serviceDate)).toList();
    final totalServiceCost = periodServices.fold<double>(0, (sum, s) => sum + s.totalCost);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.directions_car_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vehicle Maintenance Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Period: ${dateRange.label}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Total Service & Repairs', style: TextStyle(fontSize: 11, color: Colors.red)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppFormatters.currency(totalServiceCost),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Vehicles Tracked', style: TextStyle(fontSize: 11, color: Colors.red)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                vehicles.length.toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Maintenance History in Period (${periodServices.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              if (periodServices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('No vehicle service records in this period.', style: TextStyle(color: Colors.grey))),
                )
              else
                ...periodServices.map((s) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.build, color: Colors.white, size: 16)),
                        title: Text(
                          s.serviceType,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${s.serviceCenter} • ${DateFormat('dd MMM yyyy').format(s.serviceDate)}',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppFormatters.currency(s.totalCost),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  static void showPropertyReport(BuildContext context, {
    required List<Property> properties,
    required List<PropertyMaintenance> maintenances,
    required ReportDateRange dateRange,
  }) {
    final periodMaintenances = maintenances.where((m) => dateRange.contains(m.date)).toList();
    final totalMaintCost = periodMaintenances.fold<double>(0, (sum, m) => sum + m.cost);
    final totalTaxLiability = properties.fold<double>(0, (sum, p) => sum + p.propertyTaxAmount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.apartment_rounded, color: Colors.deepOrange, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Property & Tax Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Period: ${dateRange.label}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.deepOrange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Text('Repairs & Upgrades', style: TextStyle(fontSize: 11, color: Colors.deepOrange)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppFormatters.currency(totalMaintCost),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Text('Total Tax Obligations', style: TextStyle(fontSize: 11, color: Colors.blue)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppFormatters.currency(totalTaxLiability),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Properties & Tax Frequencies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ...properties.map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.deepOrange, child: Icon(Icons.home, color: Colors.white, size: 16)),
                      title: Text(
                        p.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Tax: ${AppFormatters.currency(p.propertyTaxAmount)} (${p.propertyTaxFrequency}) • Due: ${DateFormat('dd MMM').format(p.taxDueDate)}',
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          p.propertyType,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 12),
              Text('Maintenance Logs in Period (${periodMaintenances.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              if (periodMaintenances.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('No maintenance logged in this period.', style: TextStyle(color: Colors.grey))),
                )
              else
                ...periodMaintenances.map((m) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.handyman, color: Colors.white, size: 16)),
                        title: Text(
                          m.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${m.contractorName} • ${DateFormat('dd MMM yyyy').format(m.date)}',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppFormatters.currency(m.cost),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
