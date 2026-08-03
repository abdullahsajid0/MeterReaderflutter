import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'store/wattwise_store.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize native notification channel
  await NotificationService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WattWiseStore()),
      ],
      child: const WattWiseApp(),
    ),
  );
}

class WattWiseApp extends StatefulWidget {
  const WattWiseApp({super.key});

  @override
  State<WattWiseApp> createState() => _WattWiseAppState();
}

class _WattWiseAppState extends State<WattWiseApp> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for store changes and sync native notifications
    final store = Provider.of<WattWiseStore>(context);
    NotificationService().syncAlerts(store);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WattWise',
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
