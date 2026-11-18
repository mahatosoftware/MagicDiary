import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../models/bills_models.dart';

class RecordBillPaymentScreen extends ConsumerStatefulWidget {
  final Bill? bill;
  const RecordBillPaymentScreen({super.key, this.bill});

  @override
  ConsumerState<RecordBillPaymentScreen> createState() => _RecordBillPaymentScreenState();
}

class _RecordBillPaymentScreenState extends ConsumerState<RecordBillPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _refController = TextEditingController(text: 'UPI-PAY-441199');
  final _notesController = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  String _paymentMethod = 'UPI';
  bool _autoRollover = true;

  final List<String> _methods = ['UPI', 'Credit Card', 'Net Banking', 'Auto-Debit', 'Cash'];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.bill != null
          ? widget.bill!.amount.toStringAsFixed(widget.bill!.amount.truncateToDouble() == widget.bill!.amount ? 0 : 2)
          : '1499',
    );
  }

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
    if (user == null) return;
    final repo = ref.read(billsRepositoryProvider);

    final payment = BillPayment(
      id: '',
      billId: widget.bill?.id ?? 'bill_1',
      billAccountId: widget.bill?.billAccountId ?? 'acc_1',
      amountPaid: double.parse(_amountController.text.trim()),
      paymentDate: _paymentDate,
      paymentMethod: _paymentMethod,
      transactionRef: _refController.text.trim(),
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    await repo.recordBillPayment(user.uid, payment, autoRollover: _autoRollover);
    ref.invalidate(billsProvider);
    ref.invalidate(remindersProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_autoRollover
              ? 'Payment recorded! Next billing cycle auto-generated with reminder.'
              : 'Bill payment recorded!'),
        ),
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
        title: const Text('Record Bill Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, size: 36, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.bill != null
                                  ? 'Bill (${widget.bill!.billPeriod})'
                                  : 'Airtel Fiber Broadband',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.bill != null
                                  ? 'Due: ${DateFormat('dd MMM yyyy').format(widget.bill!.dueDate)} • Amount: ${AppFormatters.currency(widget.bill!.amount)}'
                                  : 'Bill Period: October 2026 • Amount: ₹1,499',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: _methods
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMethod = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2200),
                        );
                        if (picked != null) setState(() => _paymentDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(
                          DateFormat('yyyy-MM-dd').format(_paymentDate),
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _refController,
                decoration: const InputDecoration(
                  labelText: 'Transaction Reference No. *',
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
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text(
                    'Auto-Rollover Next Bill',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Automatically generate next cycle\'s bill and reminder schedule',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _autoRollover,
                  onChanged: (val) => setState(() => _autoRollover = val),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _recordPayment,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirm Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
