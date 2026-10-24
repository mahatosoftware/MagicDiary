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
    'Credit Card',
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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Name *',
                  hintText: 'e.g., Airtel Postpaid, HDFC Credit Card',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _providerController,
                      decoration: const InputDecoration(
                        labelText: 'Provider Name *',
                        hintText: 'e.g. Airtel',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter provider' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _accNoController,
                      decoration: const InputDecoration(
                        labelText: 'Account / Card Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Average Monthly Amount (₹)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _dueDay,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Due Day',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(31, (i) => i + 1)
                          .map((d) => DropdownMenuItem(value: d, child: Text('Day $d of month')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _dueDay = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('Auto Reminder'),
                      value: _autoReminder,
                      onChanged: (val) => setState(() => _autoReminder = val),
                    ),
                  ),
                ],
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
