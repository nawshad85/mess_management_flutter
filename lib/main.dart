import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:mess_manager/app/routes/app_routes.dart';
import 'package:mess_manager/app/bindings/app_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
    );
  }
}
