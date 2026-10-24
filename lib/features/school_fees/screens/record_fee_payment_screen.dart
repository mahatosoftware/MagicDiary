import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../models/school_fees_models.dart';

class RecordFeePaymentScreen extends ConsumerStatefulWidget {
  final FeeInstallment? installment;
  const RecordFeePaymentScreen({super.key, this.installment});

  @override
  ConsumerState<RecordFeePaymentScreen> createState() => _RecordFeePaymentScreenState();
}

class _RecordFeePaymentScreenState extends ConsumerState<RecordFeePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _refController;
  late TextEditingController _notesController;
  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = 'UPI';
  String? _selectedInstallmentId;

  final List<String> _methods = ['UPI', 'Credit Card', 'Bank Transfer', 'Cash', 'Cheque'];

  @override
  void initState() {
    super.initState();
    _selectedInstallmentId = widget.installment?.id;
    final due = widget.installment != null
        ? (widget.installment!.amount - widget.installment!.paidAmount)
        : 0.0;
    _amountController = TextEditingController(
      text: due > 0
          ? (due % 1 == 0 ? due.toInt().toString() : due.toString())
          : '',
    );
    _refController = TextEditingController(text: 'UPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment(String installmentId) async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(schoolFeesRepositoryProvider);

    final payment = FeePayment(
      id: '',
      installmentId: installmentId,
      amountPaid: double.parse(_amountController.text.trim()),
      paymentDate: _paymentDate,
      paymentMethod: _paymentMethod,
      transactionRef: _refController.text.trim().isNotEmpty
          ? _refController.text.trim()
          : 'TXN-${DateTime.now().millisecondsSinceEpoch}',
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    await repo.recordPayment(user.uid, payment);
    ref.invalidate(feeInstallmentsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee payment recorded and receipt generated!')),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/school-fees');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenProvider).asData?.value ?? [];
    final installments = ref.watch(feeInstallmentsProvider).asData?.value ?? [];
    final childMap = {for (var c in children) c.id: c};

    // Determine current installment
    FeeInstallment? currentInst = widget.installment;
    if (currentInst == null && installments.isNotEmpty) {
      _selectedInstallmentId ??= installments.first.id;
      final match = installments.where((i) => i.id == _selectedInstallmentId);
      currentInst = match.isNotEmpty ? match.first : installments.first;
    }

    final child = currentInst != null ? childMap[currentInst.childId] : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/school-fees');
            }
          },
        ),
        title: const Text('Record School Fee Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.installment == null && installments.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: currentInst?.id,
                  decoration: const InputDecoration(
                    labelText: 'Select Fee Installment *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                  items: installments.map((inst) {
                    final c = childMap[inst.childId];
                    final childLabel = c != null ? ' (${c.name})' : '';
                    return DropdownMenuItem(
                      value: inst.id,
                      child: Text('${inst.title}$childLabel • ${AppFormatters.currency(inst.amount)}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedInstallmentId = val;
                        final newInst = installments.firstWhere((i) => i.id == val);
                        final due = newInst.amount - newInst.paidAmount;
                        _amountController.text = due > 0
                            ? (due % 1 == 0 ? due.toInt().toString() : due.toString())
                            : '';
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (currentInst != null)
                Card(
                  color: Colors.purple.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.school, size: 36, color: Colors.purple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentInst.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                'Child: ${child?.name ?? "Student"} • Total Due: ${AppFormatters.currency(currentInst.amount - currentInst.paidAmount)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              if (child?.schoolName != null && child!.schoolName!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'School: ${child.schoolName}${child.grade != null && child.grade!.isNotEmpty ? ' • ${child.grade}' : ''}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
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
                  hintText: 'e.g., 30000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter amount';
                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                  return null;
                },
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
                        prefixIcon: Icon(Icons.payment),
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
                      title: const Text('Payment Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(_paymentDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.calendar_today, size: 18),
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
                  labelText: 'Transaction Reference / Cheque No. (Optional)',
                  hintText: 'e.g., UPI-REF-99214455',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'e.g., Paid via father\'s HDFC account',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: currentInst != null ? () => _recordPayment(currentInst!.id) : null,
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
