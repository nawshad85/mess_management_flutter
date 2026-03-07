import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:mess_manager/app/routes/app_routes.dart';
import 'package:mess_manager/app/bindings/app_binding.dart';
import 'package:mess_manager/services/notification_service.dart';
import 'package:mess_manager/services/onesignal_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().initialize();
  OneSignalService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Mess Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialBinding: AppBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.pages,
      // Clamp system text scaling so large accessibility fonts
      // don't break fixed-size layouts on small phones.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // scale(1.0) returns the raw scale factor value.
        final factor = mq.textScaler.scale(1.0).clamp(1.0, 1.2);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(factor)),
          child: child!,
        );
      },
    );
  }
}
