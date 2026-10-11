import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_routes.dart';
import 'core/constants/app_strings.dart';
import 'core/services/notification_service.dart';
import 'core/services/offline_storage.dart';
import 'core/services/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/models/user_model.dart';
import 'features/auth/screens/otp_screen.dart';
import 'features/auth/screens/phone_login_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/bills/screens/bill_detail_screen.dart';
import 'features/bills/screens/bill_list_screen.dart';
import 'features/bills/screens/defaulters_screen.dart';
import 'features/complaints/screens/complaints_screen.dart';
import 'features/customers/screens/add_customer_screen.dart';
import 'features/customers/screens/customer_detail_screen.dart';
import 'features/customers/screens/customer_list_screen.dart';
import 'features/customer_app/screens/customer_bills_screen.dart';
import 'features/customer_app/screens/customer_profile_screen.dart';
import 'features/customer_app/screens/delivery_status_screen.dart';
import 'features/customer_app/screens/my_newspapers_screen.dart';
import 'features/customer_app/screens/raise_complaint_screen.dart';
import 'features/dashboard/admin_dashboard_screen.dart';
import 'features/dashboard/customer_home_screen.dart';
import 'features/delivery/models/delivery_model.dart';
import 'features/delivery/screens/delivery_screen.dart';
import 'features/delivery_boys/add_delivery_boy_screen.dart';
import 'features/delivery_boys/delivery_boys_screen.dart';
import 'features/newspapers/add_newspaper_screen.dart';
import 'features/newspapers/newspaper_list_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/payments/screens/admin_payments_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/subscriptions/add_subscription_screen.dart';
import 'firebase_options.dart';
import 'shared/models/cash_collection_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(UserModelAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(DeliveryModelAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(CashCollectionModelAdapter());
  }

  await Hive.openBox('paperpay_auth');
  await Hive.openBox('user');
  await Hive.openBox<DeliveryModel>(OfflineStorage.deliveriesBox);
  await Hive.openBox<CashCollectionModel>(OfflineStorage.cashCollectionsBox);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Keep the app shell usable even if Firebase config is incomplete.
  }

  runApp(const ProviderScope(child: PaperPayBootstrap()));
}

class PaperPayBootstrap extends ConsumerStatefulWidget {
  const PaperPayBootstrap({super.key});

  @override
  ConsumerState<PaperPayBootstrap> createState() => _PaperPayBootstrapState();
}

class _PaperPayBootstrapState extends ConsumerState<PaperPayBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncStatusProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const PaperPayApp();
  }
}

class PaperPayApp extends StatefulWidget {
  const PaperPayApp({super.key});

  @override
  State<PaperPayApp> createState() => _PaperPayAppState();
}

class _PaperPayAppState extends State<PaperPayApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null) {
        return;
      }

      NotificationService().setContext(ctx);
      try {
        await NotificationService().initialize();
      } catch (_) {
        // Push notifications stay unavailable when Firebase is not configured,
        // which mirrors the tolerant Firebase setup in main().
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
      ],
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.splash:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case AppRoutes.phoneLogin:
          case AppRoutes.login:
            return MaterialPageRoute(builder: (_) => const PhoneLoginScreen());
          case AppRoutes.otp:
            final phone = settings.arguments as String? ?? '';
            return MaterialPageRoute(builder: (_) => OtpScreen(phone: phone));
          case AppRoutes.onboarding:
            return MaterialPageRoute(builder: (_) => const OnboardingScreen());
          case AppRoutes.adminDashboard:
          case AppRoutes.dashboard:
            return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
          case AppRoutes.customerHome:
            return MaterialPageRoute(builder: (_) => const CustomerHomeScreen());
          case AppRoutes.customerBills:
            return MaterialPageRoute(builder: (_) => const CustomerBillsScreen());
          case AppRoutes.customerPapers:
            return MaterialPageRoute(builder: (_) => const MyNewspapersScreen());
          case AppRoutes.customerDelivery:
            return MaterialPageRoute(builder: (_) => const DeliveryStatusScreen());
          case AppRoutes.customerComplaint:
            return MaterialPageRoute(builder: (_) => const RaiseComplaintScreen());
          case AppRoutes.customerProfile:
            return MaterialPageRoute(builder: (_) => const CustomerProfileScreen());
          case AppRoutes.customers:
            return MaterialPageRoute(builder: (_) => const CustomerListScreen());
          case AppRoutes.bills:
            return MaterialPageRoute(builder: (_) => const BillListScreen());
          case AppRoutes.addCustomer:
            return MaterialPageRoute(builder: (_) => const AddCustomerScreen());
          case AppRoutes.customerDetail:
            final customerId = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(customerId: customerId),
            );
          case AppRoutes.billDetail:
            final billId = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => BillDetailScreen(billId: billId),
            );
          case AppRoutes.defaulters:
            return MaterialPageRoute(builder: (_) => const DefaultersScreen());
          case AppRoutes.delivery:
            return MaterialPageRoute(builder: (_) => const DeliveryScreen());
          case AppRoutes.reports:
            return MaterialPageRoute(builder: (_) => const ReportsScreen());
          case AppRoutes.payments:
            return MaterialPageRoute(builder: (_) => const AdminPaymentsScreen());
          case AppRoutes.complaints:
            return MaterialPageRoute(builder: (_) => const ComplaintsScreen());
          case AppRoutes.settings:
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case AppRoutes.newspapers:
            return MaterialPageRoute(builder: (_) => const NewspaperListScreen());
          case AppRoutes.addNewspaper:
            return MaterialPageRoute(builder: (_) => const AddNewspaperScreen());
          case AppRoutes.addSubscription:
            final customerId = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => AddSubscriptionScreen(customerId: customerId),
            );
          case AppRoutes.deliveryBoys:
            return MaterialPageRoute(builder: (_) => const DeliveryBoysScreen());
          case AppRoutes.addDeliveryBoy:
            return MaterialPageRoute(builder: (_) => const AddDeliveryBoyScreen());
          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
      initialRoute: AppRoutes.splash,
    );
  }
}
