import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'router.dart';
import 'state/backend.dart';
import 'state/background.dart';
import 'state/session.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initBackend();
  await session.loadPreferences(); // the profile row, loaded next, wins
  await session.restore();
  await session.reminders.init();
  // keeps the hourly refresh registered (a no-op if it already is)
  if (session.remindersOn) unawaited(startBackgroundSteps());
  runApp(const NutriStepApp());
}

class NutriStepApp extends StatelessWidget {
  const NutriStepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NutriStep AI',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandGreen,
          surface: AppColors.background,
          primary: AppColors.ink,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
      ),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: child!,
      ),
    );
  }
}
