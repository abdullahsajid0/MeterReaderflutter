import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'store/wattwise_store.dart';
import 'theme/app_theme.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WattWiseStore()),
      ],
      child: const WattWiseApp(),
    ),
  );
}

class WattWiseApp extends StatelessWidget {
  const WattWiseApp({super.key});

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
