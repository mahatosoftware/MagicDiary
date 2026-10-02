import '../../features/warranty/models/product.dart';
import '../../features/warranty/models/service_record.dart';
import '../../features/school_fees/models/school_fees_models.dart';
import '../../features/bills/models/bills_models.dart';
import '../../features/documents/models/document_record.dart';
import '../../features/reminders/models/reminder.dart';

class MockData {
  static final DateTime now = DateTime.now();

  static final List<Product> initialProducts = [
    Product(
      id: 'prod_1',
      userId: 'demo_user',
      name: 'Samsung 55" OLED 4K Smart TV',
      category: 'Electronics',
      brand: 'Samsung',
      model: 'QA55S90C',
      serialNumber: 'SN-SAM-998822',
      purchaseDate: now.subtract(const Duration(days: 200)),
      price: 119999.0,
      sellerInfo: 'Croma Electronics, MG Road',
      hasWarranty: true,
      warrantyStartDate: now.subtract(const Duration(days: 200)),
      warrantyEndDate: now.add(const Duration(days: 165)),
      warrantyDurationMonths: 12,
      extendedWarranty: true,
      notes: 'Includes 1 year extended panel replacement policy.',
      tags: ['Television', 'Living Room'],
      createdAt: now.subtract(const Duration(days: 200)),
      updatedAt: now.subtract(const Duration(days: 200)),
    ),
    Product(
      id: 'prod_2',
      userId: 'demo_user',
      name: 'LG Inverter Refrigerator 450L',
      category: 'Appliances',
      brand: 'LG',
      model: 'GL-T432APZY',
      serialNumber: 'SN-LG-554411',
      purchaseDate: now.subtract(const Duration(days: 350)),
      price: 54990.0,
      sellerInfo: 'Reliance Digital',
      hasWarranty: true,
      warrantyStartDate: now.subtract(const Duration(days: 350)),
      warrantyEndDate: now.add(const Duration(days: 15)),
      warrantyDurationMonths: 12,
      notes: 'Compressor has 10 year warranty.',
      tags: ['Kitchen', 'Refrigeration'],
      createdAt: now.subtract(const Duration(days: 350)),
      updatedAt: now.subtract(const Duration(days: 350)),
    ),
    Product(
      id: 'prod_3',
      userId: 'demo_user',
      name: 'Apple MacBook Pro 16" M3 Max',
      category: 'Gadgets',
      brand: 'Apple',
      model: 'A2992',
      serialNumber: 'C02GX999MD6M',
      purchaseDate: now.subtract(const Duration(days: 400)),
      price: 349900.0,
      sellerInfo: 'Imagine Apple Store',
      hasWarranty: true,
      warrantyStartDate: now.subtract(const Duration(days: 400)),
      warrantyEndDate: now.subtract(const Duration(days: 35)),
      warrantyDurationMonths: 12,
      notes: 'Purchased AppleCare+ (expired).',
      tags: ['Work', 'Laptop'],
      createdAt: now.subtract(const Duration(days: 400)),
      updatedAt: now.subtract(const Duration(days: 400)),
    ),
  ];

  static final List<ServiceRecord> initialServiceRecords = [
    ServiceRecord(
      id: 'srv_1',
      productId: 'prod_2',
      serviceDate: now.subtract(const Duration(days: 180)),
      serviceType: 'Routine Maintenance',
      workPerformed: 'Filter cleaning & gas pressure check.',
      totalCost: 1200.0,
      serviceCenter: 'LG Authorized Service Center',
      createdAt: now.subtract(const Duration(days: 180)),
    ),
  ];

  static final List<Child> initialChildren = [
    Child(
      id: 'child_1',
      userId: 'demo_user',
      name: 'Aarav Mahato',
      dateOfBirth: DateTime(2015, 6, 15),
      gender: 'Male',
      notes: 'Enrolled in STEM extra-curricular activities.',
      createdAt: now.subtract(const Duration(days: 500)),
    ),
  ];

  static final List<School> initialSchools = [
    School(
      id: 'school_1',
      userId: 'demo_user',
      name: 'Delhi Public School (DPS), North',
      address: '124 Education Boulevard, City Center',
      contactPhone: '+91 98765 43210',
      contactEmail: 'admin@dpsnorth.edu.in',
      website: 'https://dpsnorth.edu.in',
      createdAt: now.subtract(const Duration(days: 500)),
    ),
  ];

  static final List<AcademicYear> initialAcademicYears = [
    AcademicYear(
      id: 'ay_1',
      childId: 'child_1',
      schoolId: 'school_1',
      yearLabel: '2026-2027',
      grade: 'Grade 5',
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2027, 3, 31),
      createdAt: now.subtract(const Duration(days: 100)),
    ),
  ];

  static final List<FeeStructure> initialFeeStructures = [
    FeeStructure(
      id: 'fs_1',
      academicYearId: 'ay_1',
      name: 'Grade 5 Tuition & Bus Fee',
      totalAmount: 120000.0,
      frequency: 'Quarterly',
      numberOfInstallments: 4,
      firstDueDate: DateTime(2026, 4, 10),
      createdAt: now.subtract(const Duration(days: 90)),
    ),
  ];

  static final List<FeeInstallment> initialInstallments = [
    FeeInstallment(
      id: 'inst_1',
      feeStructureId: 'fs_1',
      childId: 'child_1',
      installmentNumber: 1,
      title: 'Q1 Fee (Apr - Jun)',
      amount: 30000.0,
      dueDate: DateTime(2026, 4, 10),
      status: 'paid',
      paidAmount: 30000.0,
      paidDate: DateTime(2026, 4, 8),
    ),
    FeeInstallment(
      id: 'inst_2',
      feeStructureId: 'fs_1',
      childId: 'child_1',
      installmentNumber: 2,
      title: 'Q2 Fee (Jul - Sep)',
      amount: 30000.0,
      dueDate: DateTime(2026, 7, 10),
      status: 'paid',
      paidAmount: 30000.0,
      paidDate: DateTime(2026, 7, 5),
    ),
    FeeInstallment(
      id: 'inst_3',
      feeStructureId: 'fs_1',
      childId: 'child_1',
      installmentNumber: 3,
      title: 'Q3 Fee (Oct - Dec)',
      amount: 30000.0,
      dueDate: now.add(const Duration(days: 12)),
      status: 'pending',
      paidAmount: 0.0,
    ),
    FeeInstallment(
      id: 'inst_4',
      feeStructureId: 'fs_1',
      childId: 'child_1',
      installmentNumber: 4,
      title: 'Q4 Fee (Jan - Mar)',
      amount: 30000.0,
      dueDate: DateTime(2027, 1, 10),
      status: 'pending',
      paidAmount: 0.0,
    ),
  ];

  static final List<BillAccount> initialBillAccounts = [
    BillAccount(
      id: 'acc_1',
      userId: 'demo_user',
      name: 'Airtel Fiber Broadband & DTH',
      category: 'Telecom',
      providerName: 'Airtel Digital',
      accountNumber: 'TEL-9988-112',
      billingCycle: 'Monthly',
      dueDayOfMonth: 15,
      defaultAmount: 1499.0,
      autoReminder: true,
      createdAt: now.subtract(const Duration(days: 200)),
    ),
    BillAccount(
      id: 'acc_2',
      userId: 'demo_user',
      name: 'HDFC Regalia Credit Card',
      category: 'Credit Card',
      providerName: 'HDFC Bank',
      accountNumber: '**** **** **** 4812',
      billingCycle: 'Monthly',
      dueDayOfMonth: 22,
      defaultAmount: 24500.0,
      autoReminder: true,
      createdAt: now.subtract(const Duration(days: 300)),
    ),
    BillAccount(
      id: 'acc_3',
      userId: 'demo_user',
      name: 'Times of India Newspaper',
      category: 'Newspaper',
      providerName: 'Local Vendor Solutions',
      accountNumber: 'NEW-442',
      billingCycle: 'Monthly',
      dueDayOfMonth: 5,
      defaultAmount: 380.0,
      autoReminder: true,
      createdAt: now.subtract(const Duration(days: 400)),
    ),
  ];

  static final List<Bill> initialBills = [
    Bill(
      id: 'bill_1',
      billAccountId: 'acc_1',
      userId: 'demo_user',
      billPeriod: 'October 2026',
      billDate: now.subtract(const Duration(days: 5)),
      dueDate: now.add(const Duration(days: 5)),
      amount: 1499.0,
      minimumDue: 1499.0,
      status: 'unpaid',
      notes: 'Gigabit fiber optic plan.',
    ),
    Bill(
      id: 'bill_2',
      billAccountId: 'acc_2',
      userId: 'demo_user',
      billPeriod: 'October 2026',
      billDate: now.subtract(const Duration(days: 10)),
      dueDate: now.add(const Duration(days: 12)),
      amount: 32450.0,
      minimumDue: 1600.0,
      status: 'unpaid',
      notes: 'Statement includes Diwali shopping & travel expenses.',
    ),
  ];

  static final List<DocumentRecord> initialDocuments = [
    DocumentRecord(
      id: 'doc_1',
      userId: 'demo_user',
      title: 'Samsung OLED TV Purchase Invoice.pdf',
      category: 'Invoices',
      fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      mimeType: 'application/pdf',
      fileSizeBytes: 245000,
      relatedProductId: 'prod_1',
      tags: ['Invoice', 'Samsung', 'TV'],
      createdAt: now.subtract(const Duration(days: 200)),
    ),
    DocumentRecord(
      id: 'doc_2',
      userId: 'demo_user',
      title: 'DPS Grade 5 Q2 Fee Receipt.pdf',
      category: 'School Receipts',
      fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      mimeType: 'application/pdf',
      fileSizeBytes: 180000,
      relatedInstallmentId: 'inst_2',
      tags: ['Receipt', 'School', 'DPS'],
      createdAt: now.subtract(const Duration(days: 80)),
    ),
  ];

  static final List<Reminder> initialReminders = [
    Reminder(
      id: 'rem_1',
      userId: 'demo_user',
      title: 'LG Refrigerator Warranty Expiry',
      description: 'Warranty expires in 15 days. Inspect cooling and compressor performance.',
      module: 'Warranty',
      dueDate: now.add(const Duration(days: 15)),
      relatedId: 'prod_2',
      createdAt: now,
    ),
    Reminder(
      id: 'rem_2',
      userId: 'demo_user',
      title: 'DPS School Fee Q3 Installment Due',
      description: 'Pay ₹30,000 for Aarav\'s Grade 5 Q3 fee before penalty date.',
      module: 'SchoolFees',
      dueDate: now.add(const Duration(days: 12)),
      relatedId: 'inst_3',
      createdAt: now,
    ),
    Reminder(
      id: 'rem_3',
      userId: 'demo_user',
      title: 'Airtel Broadband Bill Due',
      description: 'Monthly bill payment of ₹1,499 due on Airtel fiber.',
      module: 'Bills',
      dueDate: now.add(const Duration(days: 5)),
      relatedId: 'bill_1',
      createdAt: now,
    ),
  ];
}
