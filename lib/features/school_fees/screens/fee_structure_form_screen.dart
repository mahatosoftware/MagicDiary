import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../models/school_fees_models.dart';

class FeeStructureFormScreen extends ConsumerStatefulWidget {
  const FeeStructureFormScreen({super.key});

  @override
  ConsumerState<FeeStructureFormScreen> createState() => _FeeStructureFormScreenState();
}

class _FeeStructureFormScreenState extends ConsumerState<FeeStructureFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Grade 5 Annual Fee');
  final _amountController = TextEditingController(text: '120000');
  String _frequency = 'Quarterly';
  int _numberOfInstallments = 4;
  DateTime _firstDueDate = DateTime(2026, 4, 10);

  final List<String> _frequencies = ['Monthly', 'Quarterly', 'Semi-Annually', 'Annually'];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onFrequencyChanged(String? val) {
    if (val == null) return;
    setState(() {
      _frequency = val;
      if (val == 'Monthly') {
        _numberOfInstallments = 12;
      } else if (val == 'Quarterly') {
        _numberOfInstallments = 4;
      } else if (val == 'Semi-Annually') {
        _numberOfInstallments = 2;
      } else {
        _numberOfInstallments = 1;
      }
    });
  }

  Future<void> _saveFeeStructure() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(userProfileProvider);
    final isDemo = ref.read(isDemoModeProvider);
    final repo = ref.read(schoolFeesRepositoryProvider);

    final fs = FeeStructure(
      id: '',
      academicYearId: 'ay_1',
      name: _nameController.text.trim(),
      totalAmount: double.parse(_amountController.text.trim()),
      frequency: _frequency,
      numberOfInstallments: _numberOfInstallments,
      firstDueDate: _firstDueDate,
      createdAt: DateTime.now(),
    );

    await repo.createFeeStructureWithInstallments(
      user?.uid ?? 'demo_user',
      fs,
      'child_1',
      isDemo: isDemo,
    );

    ref.invalidate(feeInstallmentsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee structure and schedule generated!')),
      );
      context.go('/school-fees');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Fee Structure'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Fee Name / Description *',
                  hintText: 'e.g. Grade 5 Tuition & Transport Fee',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter fee structure name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Total Annual Fee (₹) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter total amount' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(
                        labelText: 'Payment Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: _frequencies
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: _onFrequencyChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_numberOfInstallments',
                      key: ValueKey(_numberOfInstallments),
                      decoration: const InputDecoration(
                        labelText: 'No. of Installments',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                title: const Text('First Installment Due Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_firstDueDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _firstDueDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _firstDueDate = picked);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveFeeStructure,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Installment Schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
