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
import '../features/shared_diaries/screens/manage_diary_shares_screen.dart';
import '../features/shared_diaries/screens/record_selection_screen.dart';
import '../features/shared_diaries/screens/claim_share_invite_screen.dart';
import '../features/shared_diaries/models/shared_diary_models.dart';
import '../features/magic_circles/screens/magic_circles_screen.dart';
import '../features/magic_circles/screens/create_circle_screen.dart';
import '../features/magic_circles/screens/circle_dashboard_screen.dart';
import '../features/magic_circles/screens/claim_circle_invite_screen.dart';
import '../features/magic_circles/models/magic_circle_models.dart';
import '../features/payments/screens/payments_hub_screen.dart';
import '../features/documents/screens/document_library_screen.dart';
import '../features/reminders/screens/reminders_screen.dart';
import '../features/notifications/screens/notification_centre_screen.dart';
import '../features/notifications/screens/notification_settings_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/account_settings_screen.dart';
import '../features/profile/screens/security_settings_screen.dart';
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
import '../features/bills/models/bills_models.dart';
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
import '../features/cash_forecast/screens/outflow_forecast_screen.dart';

class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((_) {
        notifyListeners();
      });
    } catch (_) {
      // Firebase not initialized in tests or offline mode
    }
  }
}

final _authRefreshListenable = AuthRefreshListenable();

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: _authRefreshListenable,
  redirect: (context, state) {
    bool loggedIn = false;
    try {
      loggedIn = FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      loggedIn = false;
    }
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
        GoRoute(
          path: '/my-day',
          redirect: (context, state) => '/',
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
        GoRoute(
          path: '/circle/invite/:token',
          builder: (context, state) => ClaimCircleInviteScreen(
            token: state.pathParameters['token']!,
          ),
        ),
        GoRoute(
          path: '/circles/invite/:token',
          builder: (context, state) => ClaimCircleInviteScreen(
            token: state.pathParameters['token']!,
          ),
        ),
        GoRoute(
          path: '/join/:token',
          builder: (context, state) => ClaimCircleInviteScreen(
            token: state.pathParameters['token']!,
          ),
        ),
        GoRoute(
          path: '/circles/join',
          builder: (context, state) {
            final token = state.uri.queryParameters['code'] ?? '';
            return ClaimCircleInviteScreen(token: token);
          },
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
            ownerId: state.uri.queryParameters['ownerId'],
            ownerName: state.uri.queryParameters['ownerName'],
            circleId: state.uri.queryParameters['circleId'],
            shareAccess: state.extra is SharedDiaryAccess ? state.extra as SharedDiaryAccess : null,
          ),
        ),
        GoRoute(
          path: '/diary-records/:diaryId/add',
          builder: (context, state) => GenericRecordFormScreen(
            diaryId: state.pathParameters['diaryId']!,
            ownerId: state.uri.queryParameters['ownerId'],
          ),
        ),
        GoRoute(
          path: '/diary-records/:diaryId/edit',
          builder: (context, state) => GenericRecordFormScreen(
            diaryId: state.pathParameters['diaryId']!,
            initialRecord: state.extra as DiaryRecord?,
            ownerId: state.uri.queryParameters['ownerId'],
          ),
        ),
        GoRoute(
          path: '/diary-records/:diaryId/:recordId',
          builder: (context, state) => GenericRecordDetailScreen(
            diaryId: state.pathParameters['diaryId']!,
            recordId: state.pathParameters['recordId']!,
            initialRecord: state.extra as DiaryRecord?,
            ownerId: state.uri.queryParameters['ownerId'],
            ownerName: state.uri.queryParameters['ownerName'],
            circleId: state.uri.queryParameters['circleId'],
          ),
        ),
        GoRoute(
          path: '/manage-shares/:diaryId',
          builder: (context, state) => ManageDiarySharesScreen(
            diaryId: state.pathParameters['diaryId']!,
            diaryTitle: state.uri.queryParameters['title'],
          ),
        ),
        GoRoute(
          path: '/record-selection/:diaryId',
          builder: (context, state) => RecordSelectionScreen(
            diaryId: state.pathParameters['diaryId']!,
            ownerUid: state.uri.queryParameters['ownerId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '',
            diaryTitle: state.uri.queryParameters['title'] ?? 'Select Records',
            initiallySelectedRecordIds: (state.extra as Map<String, dynamic>?)?['selected'] as Set<String>? ?? {},
            recipientName: state.uri.queryParameters['recipient'],
          ),
        ),
        GoRoute(
          path: '/share/invite/:token',
          builder: (context, state) => ClaimShareInviteScreen(
            token: state.pathParameters['token']!,
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
          builder: (context, state) => RecordBillPaymentScreen(bill: state.extra as Bill?),
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
          path: '/outflow-forecast',
          builder: (context, state) => const OutflowForecastScreen(),
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
        GoRoute(
          path: '/security-privacy',
          builder: (context, state) => const SecuritySettingsScreen(),
        ),
      ],
    ),
  ],
);
