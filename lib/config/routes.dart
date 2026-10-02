import 'package:go_router/go_router.dart';
import '../core/widgets/app_scaffold.dart';

// Screens & 5 Main Hubs
import '../features/my_day/screens/my_day_screen.dart';
import '../features/diaries/screens/diaries_hub_screen.dart';
import '../features/payments/screens/payments_hub_screen.dart';
import '../features/documents/screens/document_library_screen.dart';
import '../features/reminders/screens/reminders_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/auth/screens/login_screen.dart';

// Diary Module Screens
import '../features/warranty/screens/product_list_screen.dart';
import '../features/warranty/screens/product_form_screen.dart';
import '../features/warranty/screens/ocr_invoice_review_screen.dart';
import '../features/school_fees/screens/school_fees_dashboard_screen.dart';
import '../features/school_fees/screens/child_form_screen.dart';
import '../features/school_fees/screens/fee_structure_form_screen.dart';
import '../features/school_fees/screens/record_fee_payment_screen.dart';
import '../features/bills/screens/bills_dashboard_screen.dart';
import '../features/bills/screens/bill_account_form_screen.dart';
import '../features/bills/screens/record_bill_payment_screen.dart';
import '../features/vehicle/screens/vehicle_dashboard_screen.dart';
import '../features/finance/screens/finance_dashboard_screen.dart';
import '../features/household/screens/household_dashboard_screen.dart';
import '../features/property/screens/property_dashboard_screen.dart';
import '../features/personal/screens/personal_dashboard_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppScaffold(child: child),
      routes: [
        // 1. My Day Hub
        GoRoute(
          path: '/',
          builder: (context, state) => const MyDayScreen(),
        ),
        // 2. My Diaries Hub
        GoRoute(
          path: '/diaries',
          builder: (context, state) => const DiariesHubScreen(),
        ),
        // 3. My Payments Hub
        GoRoute(
          path: '/payments',
          builder: (context, state) => const PaymentsHubScreen(),
        ),
        // 4. My Documents Hub
        GoRoute(
          path: '/documents',
          builder: (context, state) => const DocumentLibraryScreen(),
        ),
        // 5. My Reminders Hub
        GoRoute(
          path: '/reminders',
          builder: (context, state) => const RemindersScreen(),
        ),

        // Specialized Diary Modules
        GoRoute(
          path: '/personal',
          builder: (context, state) => const PersonalDashboardScreen(),
        ),
        GoRoute(
          path: '/warranty',
          builder: (context, state) => const ProductListScreen(),
        ),
        GoRoute(
          path: '/warranty/add',
          builder: (context, state) => const ProductFormScreen(),
        ),
        GoRoute(
          path: '/warranty/ocr',
          builder: (context, state) => const OcrInvoiceReviewScreen(),
        ),
        GoRoute(
          path: '/school-fees',
          builder: (context, state) => const SchoolFeesDashboardScreen(),
        ),
        GoRoute(
          path: '/school-fees/add-child',
          builder: (context, state) => const ChildFormScreen(),
        ),
        GoRoute(
          path: '/school-fees/add-structure',
          builder: (context, state) => const FeeStructureFormScreen(),
        ),
        GoRoute(
          path: '/school-fees/record-payment',
          builder: (context, state) => const RecordFeePaymentScreen(),
        ),
        GoRoute(
          path: '/bills',
          builder: (context, state) => const BillsDashboardScreen(),
        ),
        GoRoute(
          path: '/bills/add-account',
          builder: (context, state) => const BillAccountFormScreen(),
        ),
        GoRoute(
          path: '/bills/record-payment',
          builder: (context, state) => const RecordBillPaymentScreen(),
        ),
        GoRoute(
          path: '/vehicle',
          builder: (context, state) => const VehicleDashboardScreen(),
        ),
        GoRoute(
          path: '/finance',
          builder: (context, state) => const FinanceDashboardScreen(),
        ),
        GoRoute(
          path: '/household',
          builder: (context, state) => const HouseholdDashboardScreen(),
        ),
        GoRoute(
          path: '/property',
          builder: (context, state) => const PropertyDashboardScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
