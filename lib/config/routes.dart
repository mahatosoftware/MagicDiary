import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/widgets/app_scaffold.dart';

// Screens & Core Hubs
import '../features/my_day/screens/my_day_screen.dart';
import '../features/diaries/screens/diaries_hub_screen.dart';
import '../features/my_diaries/screens/my_diaries_screen.dart';
import '../features/my_diaries/screens/diary_category_detail_screen.dart';
import '../features/shared_diaries/screens/shared_diaries_screen.dart';
import '../features/magic_circles/screens/magic_circles_screen.dart';
import '../features/magic_circles/screens/create_circle_screen.dart';
import '../features/magic_circles/screens/circle_dashboard_screen.dart';
import '../features/magic_circles/models/magic_circle_models.dart';
import '../features/payments/screens/payments_hub_screen.dart';
import '../features/documents/screens/document_library_screen.dart';
import '../features/reminders/screens/reminders_screen.dart';
import '../features/notifications/screens/notification_centre_screen.dart';
import '../features/notifications/screens/notification_settings_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/account_settings_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/reports/screens/financial_reports_screen.dart';

// Calendar & Diary Engine
import '../core/calendar/screens/universal_calendar_screen.dart';
import '../core/diary_engine/screens/generic_diary_list_screen.dart';
import '../core/diary_engine/screens/generic_record_form_screen.dart';
import '../core/diary_engine/screens/generic_record_detail_screen.dart';
import '../core/diary_engine/models/diary_record.dart';

// Diary Module Screens
import '../features/warranty/screens/product_list_screen.dart';
import '../features/warranty/screens/product_form_screen.dart';
import '../features/warranty/screens/ocr_invoice_review_screen.dart';
import '../features/school_fees/screens/school_fees_dashboard_screen.dart';
import '../features/school_fees/screens/child_form_screen.dart';
import '../features/school_fees/models/school_fees_models.dart';
import '../features/school_fees/screens/fee_structure_form_screen.dart';
import '../features/school_fees/screens/record_fee_payment_screen.dart';
import '../features/bills/screens/bills_dashboard_screen.dart';
import '../features/bills/screens/bill_account_form_screen.dart';
import '../features/bills/screens/record_bill_payment_screen.dart';
import '../features/vehicle/screens/vehicle_dashboard_screen.dart';
import '../features/vehicle/screens/vehicle_form_screen.dart';
import '../features/vehicle/models/vehicle_models.dart';
import '../features/finance/screens/finance_dashboard_screen.dart';
import '../features/household/screens/household_dashboard_screen.dart';
import '../features/household/screens/family_workspace_screen.dart';
import '../features/property/screens/property_dashboard_screen.dart';
import '../features/personal/screens/personal_dashboard_screen.dart';
import '../features/domestic_help/screens/domestic_help_dashboard_screen.dart';
import '../features/cash_forecast/screens/cash_forecast_screen.dart';

class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }
}

final _authRefreshListenable = AuthRefreshListenable();

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: _authRefreshListenable,
  redirect: (context, state) {
    final bool loggedIn = FirebaseAuth.instance.currentUser != null;
    final bool isLoggingIn = state.matchedLocation == '/auth/login';

    if (!loggedIn && !isLoggingIn) {
      return '/auth/login';
    }
    if (loggedIn && isLoggingIn) {
      return '/';
    }
    return null;
  },
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
        // 2. Primary Destination A: My Diaries (Life OS 45 Subdiaries)
        GoRoute(
          path: '/diaries',
          builder: (context, state) => const MyDiariesScreen(),
        ),
        GoRoute(
          path: '/diaries/category/:categoryId',
          builder: (context, state) => DiaryCategoryDetailScreen(
            categoryId: state.pathParameters['categoryId']!,
          ),
        ),
        GoRoute(
          path: '/diaries-hub',
          builder: (context, state) => const DiariesHubScreen(),
        ),
        // 3. Primary Destination B: Shared Diaries
        GoRoute(
          path: '/shared-diaries',
          builder: (context, state) => const SharedDiariesScreen(),
        ),
        // 4. Primary Destination C: Magic Circles
        GoRoute(
          path: '/circles',
          builder: (context, state) => const MagicCirclesScreen(),
        ),
        GoRoute(
          path: '/circles/create',
          builder: (context, state) => const CreateCircleScreen(),
        ),
        GoRoute(
          path: '/circles/:id',
          builder: (context, state) => CircleDashboardScreen(
            circleId: state.pathParameters['id']!,
            initialCircle: state.extra as MagicCircle?,
          ),
        ),
        // Universal Calendar
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const UniversalCalendarScreen(),
        ),
        // Universal Diary Engine
        GoRoute(
          path: '/diary-records/:diaryId',
          builder: (context, state) => GenericDiaryListScreen(
            diaryId: state.pathParameters['diaryId']!,
          ),
        ),
        GoRoute(
          path: '/diary-records/:diaryId/add',
          builder: (context, state) => GenericRecordFormScreen(
            diaryId: state.pathParameters['diaryId']!,
          ),
        ),
        GoRoute(
          path: '/diary-records/:diaryId/edit',
          builder: (context, state) => GenericRecordFormScreen(
            diaryId: state.pathParameters['diaryId']!,
            initialRecord: state.extra as DiaryRecord?,
          ),
        ),
        GoRoute(
          path: '/diary-records/:diaryId/:recordId',
          builder: (context, state) => GenericRecordDetailScreen(
            diaryId: state.pathParameters['diaryId']!,
            recordId: state.pathParameters['recordId']!,
            initialRecord: state.extra as DiaryRecord?,
          ),
        ),

        // Core Hubs
        GoRoute(
          path: '/payments',
          builder: (context, state) => const PaymentsHubScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const FinancialReportsScreen(),
        ),
        GoRoute(
          path: '/documents',
          builder: (context, state) => const DocumentLibraryScreen(),
        ),
        GoRoute(
          path: '/reminders',
          builder: (context, state) => const RemindersScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationCentreScreen(),
        ),
        GoRoute(
          path: '/notification-settings',
          builder: (context, state) => const NotificationSettingsScreen(),
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
          builder: (context, state) => ChildFormScreen(
            child: state.extra as Child?,
          ),
        ),
        GoRoute(
          path: '/school-fees/add-structure',
          builder: (context, state) => const FeeStructureFormScreen(),
        ),
        GoRoute(
          path: '/school-fees/record-payment',
          builder: (context, state) => RecordFeePaymentScreen(
            installment: state.extra as FeeInstallment?,
          ),
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
          path: '/vehicle/add',
          builder: (context, state) => VehicleFormScreen(
            vehicle: state.extra as Vehicle?,
          ),
        ),
        GoRoute(
          path: '/vehicle/edit',
          builder: (context, state) => VehicleFormScreen(
            vehicle: state.extra as Vehicle?,
          ),
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
          path: '/domestic-help',
          builder: (context, state) => const DomesticHelpDashboardScreen(),
        ),
        GoRoute(
          path: '/cash-forecast',
          builder: (context, state) => const CashForecastScreen(),
        ),
        GoRoute(
          path: '/family-workspace',
          builder: (context, state) => const FamilyWorkspaceScreen(),
        ),
        GoRoute(
          path: '/property',
          builder: (context, state) => const PropertyDashboardScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/profile/account-settings',
          builder: (context, state) => const AccountSettingsScreen(),
        ),
      ],
    ),
  ],
);
