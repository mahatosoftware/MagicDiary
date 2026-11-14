import '../models/notification_enums.dart';
import '../models/notification_template.dart';
import '../models/reminder_interval.dart';

class NotificationTemplateManager {
  static final NotificationTemplateManager _instance = NotificationTemplateManager._internal();
  factory NotificationTemplateManager() => _instance;

  NotificationTemplateManager._internal() {
    _initializeDefaultTemplates();
  }

  final Map<String, NotificationTemplate> _templates = {};

  void registerTemplate(NotificationTemplate template) {
    final key = _makeKey(template.moduleId, template.eventType);
    _templates[key] = template;
  }

  NotificationTemplate getTemplate(String moduleId, String eventType) {
    final key = _makeKey(moduleId, eventType);
    if (_templates.containsKey(key)) {
      return _templates[key]!;
    }

    // Try module generic fallback
    final moduleFallback = _makeKey(moduleId, 'general');
    if (_templates.containsKey(moduleFallback)) {
      return _templates[moduleFallback]!;
    }

    // Global default fallback
    return _templates['general:general'] ?? _createGlobalDefault();
  }

  List<NotificationTemplate> getAllTemplates() => _templates.values.toList();

  List<NotificationTemplate> getTemplatesForModule(String moduleId) {
    final clean = moduleId.toLowerCase().trim();
    return _templates.values.where((t) => t.moduleId.toLowerCase() == clean).toList();
  }

  String _makeKey(String moduleId, String eventType) =>
      '${moduleId.toLowerCase().trim()}:${eventType.toLowerCase().trim()}';

  NotificationTemplate _createGlobalDefault() {
    return const NotificationTemplate(
      id: 'tpl_default',
      moduleId: 'general',
      eventType: 'general',
      titleTemplate: 'Reminder: {title}',
      bodyTemplate: '{title} is due on {date}.',
      maskedBodyTemplate: 'You have a scheduled reminder due on {date}.',
      genericBodyTemplate: 'You have a pending commitment.',
      defaultIntervals: [ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.generalReminders,
      priority: NotificationPriority.medium,
    );
  }

  void _initializeDefaultTemplates() {
    // -------------------------------------------------------------
    // A. FINANCIAL DIARY TEMPLATES
    // -------------------------------------------------------------
    // 1. Electricity bill
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_electricity',
      moduleId: 'bills',
      eventType: 'electricity_bill',
      titleTemplate: 'Electricity Bill Due',
      bodyTemplate: 'Your electricity bill payment of {amount} is due in {days} days.',
      maskedBodyTemplate: 'Your electricity bill payment is due in {days} days.',
      genericBodyTemplate: 'You have an upcoming utility bill payment due soon.',
      defaultIntervals: [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.high,
    ));

    // 2. Water bill
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_water',
      moduleId: 'bills',
      eventType: 'water_bill',
      titleTemplate: 'Water Bill Due',
      bodyTemplate: 'Your water bill payment of {amount} is due in {days} days.',
      maskedBodyTemplate: 'Your water bill payment is due in {days} days.',
      genericBodyTemplate: 'You have an upcoming utility bill payment due soon.',
      defaultIntervals: [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.high,
    ));

    // 3. Internet bill
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_internet',
      moduleId: 'bills',
      eventType: 'internet_bill',
      titleTemplate: 'Broadband/Internet Bill Due',
      bodyTemplate: 'Your internet bill payment of {amount} is due in {days} days.',
      maskedBodyTemplate: 'Your internet bill payment is due in {days} days.',
      genericBodyTemplate: 'You have an upcoming internet bill due soon.',
      defaultIntervals: [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.medium,
    ));

    // 4. Mobile bill
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_mobile',
      moduleId: 'bills',
      eventType: 'mobile_bill',
      titleTemplate: 'Mobile Bill / Recharge Due',
      bodyTemplate: 'Your mobile bill payment of {amount} is due in {days} days.',
      maskedBodyTemplate: 'Your mobile bill payment is due in {days} days.',
      genericBodyTemplate: 'You have an upcoming mobile phone bill due soon.',
      defaultIntervals: [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.medium,
    ));

    // 5. Gas bill
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_gas',
      moduleId: 'bills',
      eventType: 'gas_bill',
      titleTemplate: 'Piped Gas / LPG Bill Due',
      bodyTemplate: 'Your gas bill payment of {amount} is due in {days} days.',
      maskedBodyTemplate: 'Your gas bill payment is due in {days} days.',
      genericBodyTemplate: 'You have a gas utility bill due soon.',
      defaultIntervals: [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.high,
    ));

    // 6. Credit card payment (5 days, 3 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_credit_card',
      moduleId: 'finance',
      eventType: 'credit_card',
      titleTemplate: '{bankName} Credit Card Due',
      bodyTemplate: 'Your {bankName} credit card payment of {amount} is due in {days} days.',
      maskedBodyTemplate: 'Your {bankName} credit card payment is due in {days} days.',
      genericBodyTemplate: 'You have an upcoming credit card payment due.',
      defaultIntervals: [
        ReminderInterval.fiveDaysBefore,
        ReminderInterval.threeDaysBefore,
        ReminderInterval.oneDayBefore,
      ],
      channelType: NotificationChannelType.financialUrgent,
      priority: NotificationPriority.urgent,
    ));

    // 7. Loan EMI (3 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_loan_emi',
      moduleId: 'finance',
      eventType: 'loan_emi',
      titleTemplate: '{bankName} Loan EMI Due',
      bodyTemplate: 'Your {bankName} EMI of {amount} is due on {date}. Ensure sufficient account balance.',
      maskedBodyTemplate: 'Your {bankName} EMI is due on {date}. Maintain adequate balance.',
      genericBodyTemplate: 'You have an upcoming loan EMI installment.',
      defaultIntervals: [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialUrgent,
      priority: NotificationPriority.urgent,
    ));

    // 8. Insurance premium (15 days, 7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_insurance_premium',
      moduleId: 'finance',
      eventType: 'insurance_premium',
      titleTemplate: '{policyName} Insurance Premium Due',
      bodyTemplate: 'Your {policyName} insurance premium of {amount} is due in {days} days.',
      maskedBodyTemplate: 'Your {policyName} insurance premium is due in {days} days.',
      genericBodyTemplate: 'An insurance policy premium renewal is due soon.',
      defaultIntervals: [
        ReminderInterval.fifteenDaysBefore,
        ReminderInterval.sevenDaysBefore,
        ReminderInterval.oneDayBefore,
      ],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.high,
    ));

    // 9. Rent (3 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_rent',
      moduleId: 'household',
      eventType: 'rent',
      titleTemplate: 'Monthly Rent Payment Due',
      bodyTemplate: 'Your monthly rent of {amount} for {propertyTitle} is due in {days} days.',
      maskedBodyTemplate: 'Monthly rent for {propertyTitle} is due in {days} days.',
      genericBodyTemplate: 'Your monthly rent payment is due soon.',
      defaultIntervals: [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.high,
    ));

    // 10. Property tax (15 days, 7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_prop_tax',
      moduleId: 'property',
      eventType: 'property_tax',
      titleTemplate: 'Property Tax Due: {propertyName}',
      bodyTemplate: 'Property tax payment of {amount} for {propertyName} is due in {days} days.',
      maskedBodyTemplate: 'Property tax for {propertyName} is due in {days} days.',
      genericBodyTemplate: 'A municipal property tax payment is due soon.',
      defaultIntervals: [
        ReminderInterval.fifteenDaysBefore,
        ReminderInterval.sevenDaysBefore,
        ReminderInterval.oneDayBefore,
      ],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.high,
    ));

    // 11. School fees (7 days, 3 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_school_fees',
      moduleId: 'school_fees',
      eventType: 'school_fees',
      titleTemplate: 'School Fee Due: {childName}',
      bodyTemplate: 'School fee payment of {amount} for {childName} is due in {days} days.',
      maskedBodyTemplate: 'School fee payment for {childName} is due in {days} days.',
      genericBodyTemplate: 'An education fee installment is due soon.',
      defaultIntervals: [
        ReminderInterval.sevenDaysBefore,
        ReminderInterval.threeDaysBefore,
        ReminderInterval.oneDayBefore,
      ],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.high,
    ));

    // 12. Subscription (3 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_subscription',
      moduleId: 'bills',
      eventType: 'subscription',
      titleTemplate: '{serviceName} Subscription Renewal',
      bodyTemplate: 'Your {serviceName} subscription of {amount} renews in {days} days.',
      maskedBodyTemplate: '{serviceName} subscription renewal is due in {days} days.',
      genericBodyTemplate: 'A digital service subscription renews soon.',
      defaultIntervals: [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.medium,
    ));

    // 13. Household recurring payment (1 day before)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_house_recurring',
      moduleId: 'household',
      eventType: 'household_recurring',
      titleTemplate: 'Household Expense Due: {expenseName}',
      bodyTemplate: 'Your household payment for {expenseName} of {amount} is due tomorrow.',
      maskedBodyTemplate: 'Household payment for {expenseName} is due tomorrow.',
      genericBodyTemplate: 'A recurring household payment is due tomorrow.',
      defaultIntervals: [ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.medium,
    ));

    // 14. Salary/income expected (On expected date)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_salary_income',
      moduleId: 'finance',
      eventType: 'salary_income',
      titleTemplate: 'Expected Income: {sourceName}',
      bodyTemplate: 'Expected income of {amount} from {sourceName} is scheduled for today.',
      maskedBodyTemplate: 'Expected income from {sourceName} is scheduled for today.',
      genericBodyTemplate: 'An income credit is expected today.',
      defaultIntervals: [ReminderInterval.onDueDate],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.low,
    ));

    // 15. Investment maturity (30 days, 7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_investment_maturity',
      moduleId: 'finance',
      eventType: 'investment_maturity',
      titleTemplate: 'Investment Maturing: {investmentName}',
      bodyTemplate: 'Your investment in {investmentName} of {amount} matures in {days} days.',
      maskedBodyTemplate: 'Your investment in {investmentName} matures in {days} days.',
      genericBodyTemplate: 'A fixed financial investment matures soon.',
      defaultIntervals: [
        ReminderInterval.thirtyDaysBefore,
        ReminderInterval.sevenDaysBefore,
        ReminderInterval.oneDayBefore,
      ],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.medium,
    ));

    // 16. Tax payment (15 days, 7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_fin_tax_payment',
      moduleId: 'finance',
      eventType: 'tax_payment',
      titleTemplate: 'Tax Payment Due: {taxType}',
      bodyTemplate: 'Advance/statutory tax payment of {amount} is due in {days} days.',
      maskedBodyTemplate: 'Advance tax installment is due in {days} days.',
      genericBodyTemplate: 'A statutory tax payment deadline is approaching.',
      defaultIntervals: [
        ReminderInterval.fifteenDaysBefore,
        ReminderInterval.sevenDaysBefore,
        ReminderInterval.oneDayBefore,
      ],
      channelType: NotificationChannelType.financialUrgent,
      priority: NotificationPriority.urgent,
    ));

    // -------------------------------------------------------------
    // B. VEHICLE DIARY TEMPLATES
    // -------------------------------------------------------------
    // 1. Vehicle servicing (7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_veh_servicing',
      moduleId: 'vehicle',
      eventType: 'vehicle_servicing',
      titleTemplate: 'Service Due: {vehicleName}',
      bodyTemplate: 'Periodic maintenance for {vehicleName} is due on {date}.',
      maskedBodyTemplate: 'Periodic servicing for your vehicle is due on {date}.',
      genericBodyTemplate: 'A scheduled vehicle maintenance is approaching.',
      defaultIntervals: [ReminderInterval.sevenDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.maintenanceService,
      priority: NotificationPriority.medium,
    ));

    // 2. Insurance expiry (30 days, 7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_veh_insurance',
      moduleId: 'vehicle',
      eventType: 'vehicle_insurance',
      titleTemplate: 'Vehicle Insurance Expiring: {vehicleName}',
      bodyTemplate: 'Insurance policy for {vehicleName} ({regNo}) expires in {days} days. Renew promptly to avoid penalty.',
      maskedBodyTemplate: 'Insurance policy for {vehicleName} expires in {days} days.',
      genericBodyTemplate: 'Your vehicle insurance is expiring soon.',
      defaultIntervals: [
        ReminderInterval.thirtyDaysBefore,
        ReminderInterval.sevenDaysBefore,
        ReminderInterval.oneDayBefore,
      ],
      channelType: NotificationChannelType.financialUrgent,
      priority: NotificationPriority.high,
    ));

    // 3. PUC expiry (15 days, 7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_veh_puc',
      moduleId: 'vehicle',
      eventType: 'vehicle_puc',
      titleTemplate: 'PUC Certificate Expiring: {vehicleName}',
      bodyTemplate: 'PUC emission certificate for {vehicleName} expires in {days} days on {date}.',
      maskedBodyTemplate: 'PUC emission certificate for {vehicleName} expires in {days} days.',
      genericBodyTemplate: 'Vehicle pollution certificate renewal is due.',
      defaultIntervals: [
        ReminderInterval.fifteenDaysBefore,
        ReminderInterval.sevenDaysBefore,
        ReminderInterval.oneDayBefore,
      ],
      channelType: NotificationChannelType.maintenanceService,
      priority: NotificationPriority.medium,
    ));

    // 4. Vehicle tax (15 days, 3 days)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_veh_tax',
      moduleId: 'vehicle',
      eventType: 'vehicle_tax',
      titleTemplate: 'Road Tax Due: {vehicleName}',
      bodyTemplate: 'Vehicle road tax of {amount} for {vehicleName} is due in {days} days.',
      maskedBodyTemplate: 'Road tax for {vehicleName} is due in {days} days.',
      genericBodyTemplate: 'A vehicle road tax payment is due soon.',
      defaultIntervals: [
        ReminderInterval.fifteenDaysBefore,
        ReminderInterval.threeDaysBefore,
      ],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.high,
    ));

    // 5. Driving licence expiry (30 days, 7 days)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_veh_driving_licence',
      moduleId: 'vehicle',
      eventType: 'driving_licence',
      titleTemplate: 'Driving Licence Expiring',
      bodyTemplate: 'Your driving licence expires in {days} days on {date}. Plan your renewal.',
      maskedBodyTemplate: 'Your driving licence expires in {days} days.',
      genericBodyTemplate: 'A driving licence renewal is approaching.',
      defaultIntervals: [ReminderInterval.thirtyDaysBefore, ReminderInterval.sevenDaysBefore],
      channelType: NotificationChannelType.generalReminders,
      priority: NotificationPriority.medium,
    ));

    // 6. Registration expiry (30 days, 7 days)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_veh_registration',
      moduleId: 'vehicle',
      eventType: 'registration_expiry',
      titleTemplate: 'Registration Expiring: {vehicleName}',
      bodyTemplate: 'Vehicle registration (RC) for {vehicleName} expires in {days} days on {date}.',
      maskedBodyTemplate: 'Vehicle registration (RC) for {vehicleName} expires in {days} days.',
      genericBodyTemplate: 'Vehicle registration renewal is due.',
      defaultIntervals: [ReminderInterval.thirtyDaysBefore, ReminderInterval.sevenDaysBefore],
      channelType: NotificationChannelType.maintenanceService,
      priority: NotificationPriority.high,
    ));

    // -------------------------------------------------------------
    // C. WARRANTY DIARY TEMPLATES
    // -------------------------------------------------------------
    // 1. Product warranty expiry (30 days, 7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_war_warranty_expiry',
      moduleId: 'warranty',
      eventType: 'product_warranty',
      titleTemplate: 'Warranty Expiring: {productName}',
      bodyTemplate: 'The standard warranty for {productName} expires in {days} days on {date}.',
      maskedBodyTemplate: 'Warranty for {productName} expires in {days} days.',
      genericBodyTemplate: 'A product warranty is expiring soon.',
      defaultIntervals: [
        ReminderInterval.thirtyDaysBefore,
        ReminderInterval.sevenDaysBefore,
        ReminderInterval.oneDayBefore,
      ],
      channelType: NotificationChannelType.maintenanceService,
      priority: NotificationPriority.medium,
    ));

    // 2. Extended warranty expiry (30 days, 7 days)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_war_extended_warranty',
      moduleId: 'warranty',
      eventType: 'extended_warranty',
      titleTemplate: 'Extended Warranty Expiring: {productName}',
      bodyTemplate: 'Extended warranty for {productName} expires in {days} days on {date}.',
      maskedBodyTemplate: 'Extended warranty for {productName} expires in {days} days.',
      genericBodyTemplate: 'An extended product warranty is expiring soon.',
      defaultIntervals: [ReminderInterval.thirtyDaysBefore, ReminderInterval.sevenDaysBefore],
      channelType: NotificationChannelType.maintenanceService,
      priority: NotificationPriority.medium,
    ));

    // 3. Return window closure (3 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_war_return_window',
      moduleId: 'warranty',
      eventType: 'return_window',
      titleTemplate: 'Return Window Closing: {productName}',
      bodyTemplate: 'Return/replacement window for {productName} closes in {days} days.',
      maskedBodyTemplate: 'Return window for {productName} closes in {days} days.',
      genericBodyTemplate: 'A product return period is closing soon.',
      defaultIntervals: [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialUrgent,
      priority: NotificationPriority.high,
    ));

    // 4. Free service expiry (7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_war_free_service',
      moduleId: 'warranty',
      eventType: 'free_service',
      titleTemplate: 'Complimentary Service Expiring: {productName}',
      bodyTemplate: 'Claim your complimentary service for {productName} before {date}.',
      maskedBodyTemplate: 'Complimentary service for {productName} expires soon.',
      genericBodyTemplate: 'A complimentary service voucher is expiring.',
      defaultIntervals: [ReminderInterval.sevenDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.maintenanceService,
      priority: NotificationPriority.medium,
    ));

    // -------------------------------------------------------------
    // D. DOMESTIC HELP DIARY TEMPLATES
    // -------------------------------------------------------------
    // 1. Monthly salary (On due date)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_dom_salary',
      moduleId: 'domestic_help',
      eventType: 'monthly_salary',
      titleTemplate: 'Staff Salary Due: {workerName}',
      bodyTemplate: 'Monthly salary of {amount} for {workerName} is due today.',
      maskedBodyTemplate: 'Monthly salary for {workerName} is due today.',
      genericBodyTemplate: 'A domestic staff salary payment is due today.',
      defaultIntervals: [ReminderInterval.onDueDate],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.high,
    ));

    // 2. Advance settlement (On due date)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_dom_advance',
      moduleId: 'domestic_help',
      eventType: 'advance_settlement',
      titleTemplate: 'Advance Settlement: {workerName}',
      bodyTemplate: 'Scheduled salary advance deduction of {amount} for {workerName} is due today.',
      maskedBodyTemplate: 'Salary advance deduction for {workerName} is due today.',
      genericBodyTemplate: 'A staff advance adjustment is due today.',
      defaultIntervals: [ReminderInterval.onDueDate],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.medium,
    ));

    // 3. Monthly attendance closure (Last day of month)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_dom_attendance',
      moduleId: 'domestic_help',
      eventType: 'monthly_attendance',
      titleTemplate: 'Review Domestic Staff Attendance',
      bodyTemplate: 'Monthly attendance closure for {monthName}. Verify leaves and overtime.',
      maskedBodyTemplate: 'Review monthly attendance and calculate salary statements.',
      genericBodyTemplate: 'Review staff attendance records for the month.',
      defaultIntervals: [ReminderInterval.onDueDate],
      channelType: NotificationChannelType.generalReminders,
      priority: NotificationPriority.low,
    ));

    // 4. Salary revision (On effective date)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_dom_salary_revision',
      moduleId: 'domestic_help',
      eventType: 'salary_revision',
      titleTemplate: 'Salary Revision Effective: {workerName}',
      bodyTemplate: 'Salary revision for {workerName} is effective today.',
      maskedBodyTemplate: 'Staff salary adjustment is effective today.',
      genericBodyTemplate: 'A staff salary revision is effective today.',
      defaultIntervals: [ReminderInterval.onDueDate],
      channelType: NotificationChannelType.generalReminders,
      priority: NotificationPriority.medium,
    ));

    // -------------------------------------------------------------
    // E. PROPERTY AND HOUSEHOLD DIARY TEMPLATES
    // -------------------------------------------------------------
    // 1. Maintenance charges (3 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_prop_maintenance',
      moduleId: 'property',
      eventType: 'maintenance_charges',
      titleTemplate: 'Society Maintenance Due: {propertyName}',
      bodyTemplate: 'Society maintenance charges of {amount} for {propertyName} are due in {days} days.',
      maskedBodyTemplate: 'Society maintenance charges for {propertyName} are due in {days} days.',
      genericBodyTemplate: 'A property maintenance fee is due soon.',
      defaultIntervals: [ReminderInterval.threeDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.financialReminders,
      priority: NotificationPriority.high,
    ));

    // 2. Rental agreement expiry (30 days, 7 days)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_prop_rental_agreement',
      moduleId: 'property',
      eventType: 'rental_agreement',
      titleTemplate: 'Rental Agreement Expiring: {propertyName}',
      bodyTemplate: 'Rental agreement for {propertyName} expires in {days} days on {date}. Plan renewal or move-out.',
      maskedBodyTemplate: 'Rental agreement for {propertyName} expires in {days} days.',
      genericBodyTemplate: 'A property lease agreement is expiring soon.',
      defaultIntervals: [ReminderInterval.thirtyDaysBefore, ReminderInterval.sevenDaysBefore],
      channelType: NotificationChannelType.generalReminders,
      priority: NotificationPriority.high,
    ));

    // 3. Appliance servicing (7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_house_appliance_servicing',
      moduleId: 'household',
      eventType: 'appliance_servicing',
      titleTemplate: 'Appliance Service Due: {applianceName}',
      bodyTemplate: 'Scheduled maintenance for {applianceName} is due in {days} days on {date}.',
      maskedBodyTemplate: 'Maintenance for {applianceName} is due in {days} days.',
      genericBodyTemplate: 'A home appliance service is due soon.',
      defaultIntervals: [ReminderInterval.sevenDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.maintenanceService,
      priority: NotificationPriority.medium,
    ));

    // 4. Annual maintenance (AMC) (7 days, 1 day)
    registerTemplate(const NotificationTemplate(
      id: 'tpl_prop_annual_maintenance',
      moduleId: 'property',
      eventType: 'annual_maintenance',
      titleTemplate: 'AMC Renewal Due: {serviceName}',
      bodyTemplate: 'Annual maintenance contract (AMC) for {serviceName} is due for renewal on {date}.',
      maskedBodyTemplate: 'AMC for {serviceName} is due for renewal on {date}.',
      genericBodyTemplate: 'An annual maintenance contract is due for renewal.',
      defaultIntervals: [ReminderInterval.sevenDaysBefore, ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.maintenanceService,
      priority: NotificationPriority.medium,
    ));

    // -------------------------------------------------------------
    // F. SPECIAL LIFECYCLE TEMPLATES (OVERDUE, SNOOZE, DEFER)
    // -------------------------------------------------------------
    // Overdue Alert
    registerTemplate(const NotificationTemplate(
      id: 'tpl_lifecycle_overdue',
      moduleId: 'general',
      eventType: 'overdue',
      titleTemplate: 'Overdue: {title}',
      bodyTemplate: 'Your {title} was due on {date} and is now overdue by {days} days.',
      maskedBodyTemplate: 'Your {title} is overdue by {days} days. Please take action.',
      genericBodyTemplate: 'You have an overdue commitment requiring your attention.',
      defaultIntervals: [ReminderInterval.onDueDate],
      channelType: NotificationChannelType.overdueAlerts,
      priority: NotificationPriority.urgent,
    ));

    // Snoozed Reminder
    registerTemplate(const NotificationTemplate(
      id: 'tpl_lifecycle_snooze',
      moduleId: 'general',
      eventType: 'snooze',
      titleTemplate: 'Snoozed Reminder: {title}',
      bodyTemplate: 'Reminder postponed until {newTime}. Commitment is due on {dueDate}.',
      maskedBodyTemplate: 'Reminder for {title} postponed until {newTime}.',
      genericBodyTemplate: 'Postponed reminder is now active.',
      defaultIntervals: [],
      channelType: NotificationChannelType.snoozeDefer,
      priority: NotificationPriority.high,
    ));

    // Deferred Reminder
    registerTemplate(const NotificationTemplate(
      id: 'tpl_lifecycle_defer',
      moduleId: 'general',
      eventType: 'defer',
      titleTemplate: 'Rescheduled: {title}',
      bodyTemplate: 'Your reminder has been rescheduled to {newDate}.',
      maskedBodyTemplate: 'Reminder for {title} has been rescheduled to {newDate}.',
      genericBodyTemplate: 'A reminder has been rescheduled.',
      defaultIntervals: [],
      channelType: NotificationChannelType.snoozeDefer,
      priority: NotificationPriority.medium,
    ));

    // General Diary default
    registerTemplate(const NotificationTemplate(
      id: 'tpl_personal_general',
      moduleId: 'personal',
      eventType: 'general',
      titleTemplate: 'Personal Reminder: {title}',
      bodyTemplate: '{title} is scheduled for {date}.',
      maskedBodyTemplate: 'Personal diary reminder for {date}.',
      genericBodyTemplate: 'You have a scheduled personal reminder.',
      defaultIntervals: [ReminderInterval.oneDayBefore],
      channelType: NotificationChannelType.generalReminders,
      priority: NotificationPriority.medium,
    ));
  }
}
