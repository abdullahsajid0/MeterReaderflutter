import 'package:go_router/go_router.dart';
import 'screens/main_screen.dart';
import 'screens/meter_details_screen.dart';
import 'screens/meter_scan_screen.dart';
import 'screens/add_meter_screen.dart';
import 'screens/alerts_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/alerts',
      builder: (context, state) => const AlertsScreen(),
    ),
    GoRoute(
      path: '/meters/new',
      builder: (context, state) => const AddMeterScreen(),
    ),
    GoRoute(
      path: '/meters/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MeterDetailsScreen(meterId: id);
      },
    ),
    GoRoute(
      path: '/meters/:id/scan',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MeterScanScreen(meterId: id);
      },
    ),
  ],
);
