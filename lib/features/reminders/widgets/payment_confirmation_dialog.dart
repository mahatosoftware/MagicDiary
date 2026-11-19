import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';

/// Modal dialog for confirming and recording payment details for financial reminders.
class PaymentConfirmationDialog extends StatefulWidget {
  final Reminder reminder;
  final Future<void> Function(ReminderPaymentDetails details) onConfirm;

  const PaymentConfirmationDialog({
    super.key,
    required this.reminder,
    required this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Reminder reminder,
    required Future<void> Function(ReminderPaymentDetails details) onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentConfirmationDialog(
        reminder: reminder,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<PaymentConfirmationDialog> createState() => _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<PaymentConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;
  late final TextEditingController _receiptController;

  late DateTime _selectedPaymentDate;
  String _selectedPaymentMethod = 'UPI';
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _paymentMethods = [
    'UPI',
    'Bank Transfer',
    'Card',
    'Cash',
    'Cheque',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final initialAmount = widget.reminder.amount;
    _amountController = TextEditingController(
      text: initialAmount != null && initialAmount > 0
          ? (initialAmount == initialAmount.roundToDouble()
              ? initialAmount.toStringAsFixed(0)
              : initialAmount.toStringAsFixed(2))
          : '',
    );
    _referenceController = TextEditingController();
    _notesController = TextEditingController();
    _receiptController = TextEditingController();
    _selectedPaymentDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_isSubmitting) return; // Prevent duplicate submissions

    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (parsedAmount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid payment amount');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final details = ReminderPaymentDetails(
        amount: parsedAmount,
        currency: widget.reminder.currencyCode ?? 'INR',
        paidAt: _selectedPaymentDate,
        paymentMethod: _selectedPaymentMethod,
        transactionReference: _referenceController.text.trim().isNotEmpty
            ? _referenceController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        receiptUrl: _receiptController.text.trim().isNotEmpty
            ? _receiptController.text.trim()
            : null,
      );

      await widget.onConfirm(details);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedPaymentDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) {
      setState(() => _selectedPaymentDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.reminder.currencyCode ?? '₹';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payments_outlined, color: Colors.green.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record Payment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.reminder.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                ),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount Paid *',
                  prefixText: '$currency ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  helperText: widget.reminder.amount != null
                      ? 'Pre-populated from reminder record'
                      : 'Enter settled amount',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter amount';
                  final val = double.tryParse(v.trim());
                  if (val == null || val <= 0) return 'Enter a positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Payment Date Selector
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Date',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            DateFormat('EEE, dd MMM yyyy').format(_selectedPaymentDate),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Payment Method Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedPaymentMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _paymentMethods.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPaymentMethod = val);
                },
              ),
              const SizedBox(height: 14),

              // Transaction Reference (Optional)
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: 'Transaction Reference / UTR (Optional)',
                  hintText: 'e.g. UPI Ref / Cheque No.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Notes (Optional)
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Additional details or memo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSubmitting ? null : _handleConfirm,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(_isSubmitting ? 'Recording...' : 'Mark as Paid'),
        ),
      ],
    );
  }
}
