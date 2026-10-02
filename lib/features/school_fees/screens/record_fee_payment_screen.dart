import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../models/school_fees_models.dart';

class RecordFeePaymentScreen extends ConsumerStatefulWidget {
  const RecordFeePaymentScreen({super.key});

  @override
  ConsumerState<RecordFeePaymentScreen> createState() => _RecordFeePaymentScreenState();
}

class _RecordFeePaymentScreenState extends ConsumerState<RecordFeePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '30000');
  final _refController = TextEditingController(text: 'UPI-REF-99214455');
  final _notesController = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = 'UPI';

  final List<String> _methods = ['UPI', 'Credit Card', 'Bank Transfer', 'Cash', 'Cheque'];

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(userProfileProvider);
    final isDemo = ref.read(isDemoModeProvider);
    final repo = ref.read(schoolFeesRepositoryProvider);

    final payment = FeePayment(
      id: '',
      installmentId: 'inst_3',
      amountPaid: double.parse(_amountController.text.trim()),
      paymentDate: _paymentDate,
      paymentMethod: _paymentMethod,
      transactionRef: _refController.text.trim(),
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    await repo.recordPayment(user?.uid ?? 'demo_user', payment, isDemo: isDemo);
    ref.invalidate(feeInstallmentsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee payment recorded and receipt generated!')),
      );
      context.go('/school-fees');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record School Fee Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.purple.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.school, size: 36, color: Colors.purple),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Q3 Fee (Oct - Dec)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Child: Aarav Mahato • Due: ₹30,000'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid (₹) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: _methods
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMethod = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: const Text('Payment Date'),
                      subtitle: Text(DateFormat('yyyy-MM-dd').format(_paymentDate)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _paymentDate = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _refController,
                decoration: const InputDecoration(
                  labelText: 'Transaction Reference / Cheque No. *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter reference no.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _recordPayment,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirm Payment & Issue Receipt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
