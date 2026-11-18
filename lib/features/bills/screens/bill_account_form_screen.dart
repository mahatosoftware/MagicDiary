import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../models/bills_models.dart';

class BillAccountFormScreen extends ConsumerStatefulWidget {
  const BillAccountFormScreen({super.key});

  @override
  ConsumerState<BillAccountFormScreen> createState() => _BillAccountFormScreenState();
}

class _BillAccountFormScreenState extends ConsumerState<BillAccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _providerController = TextEditingController();
  final _accNoController = TextEditingController();
  final _amountController = TextEditingController();

  String _category = 'Telecom';
  int _dueDay = 10;
  bool _autoReminder = true;

  final List<String> _categories = [
    'Telecom',
    'Broadband / Internet',
    'Electricity',
    'Credit Card',
    'Water / Gas',
    'Newspaper',
    'Utility',
    'Subscription',
    'Rent',
    'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _accNoController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(billsRepositoryProvider);

    final account = BillAccount(
      id: '',
      userId: user.uid,
      name: _nameController.text.trim(),
      category: _category,
      providerName: _providerController.text.trim(),
      accountNumber: _accNoController.text.trim(),
      billingCycle: 'Monthly',
      dueDayOfMonth: _dueDay,
      defaultAmount: double.tryParse(_amountController.text.trim()) ?? 0.0,
      autoReminder: _autoReminder,
      createdAt: DateTime.now(),
    );

    await repo.addBillAccount(user.uid, account);
    ref.invalidate(billAccountsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill account added!')),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/bills');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/bills');
            }
          },
        ),
        title: const Text('Add Bill Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Name *',
                  hintText: 'e.g., Electricity Bill, Airtel Broadband',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: _categories
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      controller: _providerController,
                      decoration: const InputDecoration(
                        labelText: 'Provider *',
                        hintText: 'e.g. WBSEDCL, Airtel',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter provider' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      controller: _accNoController,
                      decoration: const InputDecoration(
                        labelText: 'Account / ID No.',
                        hintText: 'Consumer ID / No.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Avg. Amount (₹)',
                        hintText: 'e.g. 1500',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _dueDay,
                decoration: const InputDecoration(
                  labelText: 'Monthly Due Day *',
                  hintText: 'Select day of month',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                ),
                items: List.generate(31, (i) => i + 1)
                    .map((d) => DropdownMenuItem(value: d, child: Text('Day $d of every month')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _dueDay = val);
                },
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text(
                    'Auto Reminder',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Automatically generate reminders and push notifications for this bill',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _autoReminder,
                  onChanged: (val) => setState(() => _autoReminder = val),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveAccount,
                  icon: const Icon(Icons.check),
                  label: const Text('Save Bill Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
