import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
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
  final _planTierController = TextEditingController();
  final _cancelUrlController = TextEditingController();

  String _category = 'Telecom';
  int _dueDay = 10;
  bool _autoReminder = true;
  String _billingCycle = 'Monthly';

  // Subscription Tracker states
  bool _isSubscription = false;
  String _subscriptionType = 'paid'; // 'paid', 'free_trial'
  DateTime? _trialEndsAt;
  DateTime? _renewalDate;
  final int _reminderDaysBefore = 3;

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
    _planTierController.dispose();
    _cancelUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isTrial) async {
    final now = DateTime.now();
    final initialDate = isTrial
        ? (_trialEndsAt ?? now.add(const Duration(days: 14)))
        : (_renewalDate ?? now.add(const Duration(days: 30)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? initialDate : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() {
        if (isTrial) {
          _trialEndsAt = picked;
        } else {
          _renewalDate = picked;
        }
      });
    }
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
      billingCycle: _billingCycle,
      dueDayOfMonth: _dueDay,
      defaultAmount: double.tryParse(_amountController.text.trim()) ?? 0.0,
      autoReminder: _autoReminder,
      isSubscription: _isSubscription || _category == 'Subscription',
      subscriptionType: _subscriptionType,
      trialEndsAt: _trialEndsAt,
      renewalDate: _renewalDate,
      reminderDaysBefore: _reminderDaysBefore,
      cancelUrl: _cancelUrlController.text.trim().isNotEmpty ? _cancelUrlController.text.trim() : null,
      planTier: _planTierController.text.trim().isNotEmpty ? _planTierController.text.trim() : null,
      createdAt: DateTime.now(),
    );

    await repo.addBillAccount(user.uid, account);
    ref.invalidate(billAccountsProvider);
    ref.invalidate(billsProvider);
    ref.invalidate(remindersProvider);

    if (mounted) {
      final message = account.isSubscription
          ? (account.subscriptionType == 'free_trial'
              ? 'Free trial tracked! You will be alerted 3 days before expiry.'
              : 'Subscription added! Renewal reminders scheduled.')
          : 'Bill account added!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
    final isSubMode = _isSubscription || _category == 'Subscription';

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
        title: Text(isSubMode ? 'Add Subscription / Free Trial' : 'Add Bill Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented selector between Bill vs Subscription
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Utility & Bill')),
                        selected: !isSubMode,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _isSubscription = false;
                              if (_category == 'Subscription') _category = 'Telecom';
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Subscription & Trial')),
                        selected: isSubMode,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _isSubscription = true;
                              _category = 'Subscription';
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: isSubMode ? 'Subscription Name *' : 'Account Name *',
                  hintText: isSubMode ? 'e.g. Netflix, Spotify, ChatGPT Plus, Cult.fit' : 'e.g. Electricity Bill, Airtel Broadband',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(isSubMode ? Icons.subscriptions_rounded : Icons.receipt_long_rounded),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),

              if (isSubMode) ...[
                // Subscription Type: Paid vs Free Trial
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _subscriptionType == 'free_trial' ? Colors.amber.shade50 : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _subscriptionType == 'free_trial' ? Colors.amber.shade300 : Colors.indigo.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subscription Type',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'paid',
                              label: Text('Paid Plan'),
                              icon: Icon(Icons.credit_card, size: 16),
                            ),
                            ButtonSegment(
                              value: 'free_trial',
                              label: Text('Free Trial'),
                              icon: Icon(Icons.timer_outlined, size: 16),
                            ),
                          ],
                          selected: {_subscriptionType},
                          onSelectionChanged: (newSelection) {
                            setState(() => _subscriptionType = newSelection.first);
                          },
                        ),
                      ),
                      if (_subscriptionType == 'free_trial') ...[
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.alarm, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _trialEndsAt == null
                                    ? 'Select Free Trial Expiry Date'
                                    : 'Trial Ends: ${AppFormatters.date(_trialEndsAt!)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _pickDate(true),
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: Text(_trialEndsAt == null ? 'Set Date' : 'Change'),
                            ),
                          ],
                        ),
                        Text(
                          'You will receive an alert $_reminderDaysBefore days before expiry so you can cancel in time and avoid charges.',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ] else ...[
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.event_repeat_rounded, color: Colors.indigo, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _renewalDate == null
                                    ? 'Next Renewal Date (Optional)'
                                    : 'Renews: ${AppFormatters.date(_renewalDate!)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _pickDate(false),
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: Text(_renewalDate == null ? 'Set Date' : 'Change'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
                        if (val != null) {
                          setState(() {
                            _category = val;
                            if (val == 'Subscription') _isSubscription = true;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      controller: _providerController,
                      decoration: InputDecoration(
                        labelText: isSubMode ? 'Platform / Provider *' : 'Provider *',
                        hintText: isSubMode ? 'e.g. Netflix, Google, Apple' : 'e.g. WBSEDCL, Airtel',
                        border: const OutlineInputBorder(),
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
                      decoration: InputDecoration(
                        labelText: isSubMode ? 'Account / User Email' : 'Account / ID No.',
                        hintText: isSubMode ? 'Login email or user ID' : 'Consumer ID / No.',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: _subscriptionType == 'free_trial' ? 'Post-Trial Fee (₹)' : 'Amount (₹)',
                        hintText: 'e.g. 649',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (isSubMode) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: DropdownButtonFormField<String>(
                        initialValue: _billingCycle,
                        decoration: const InputDecoration(
                          labelText: 'Billing Cycle',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'Quarterly', child: Text('Quarterly')),
                          DropdownMenuItem(value: 'Yearly', child: Text('Yearly / Annual')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _billingCycle = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _planTierController,
                        decoration: const InputDecoration(
                          labelText: 'Plan Tier',
                          hintText: 'e.g. Premium 4K, Family',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cancelUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Manage / Cancel Web URL (Optional)',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
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
              ],

              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text(
                    'Auto Reminder & Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isSubMode
                        ? 'Alert me $_reminderDaysBefore days in advance before free trial expires or subscription renews'
                        : 'Automatically generate reminders and push notifications for this bill',
                    style: const TextStyle(fontSize: 12),
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
                  label: Text(isSubMode ? 'Save Subscription' : 'Save Bill Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
