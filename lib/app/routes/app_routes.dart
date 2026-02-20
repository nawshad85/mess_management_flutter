import 'package:get/get.dart';
import 'package:mess_manager/views/splash/splash_view.dart';
import 'package:mess_manager/views/auth/login_view.dart';
import 'package:mess_manager/views/auth/register_view.dart';
import 'package:mess_manager/views/home/home_view.dart';
import 'package:mess_manager/views/mess/create_mess_view.dart';
import 'package:mess_manager/views/mess/invite_member_view.dart';
import 'package:mess_manager/views/mess/mess_dashboard_view.dart';
import 'package:mess_manager/views/room/room_management_view.dart';
import 'package:mess_manager/views/bazar/bazar_entry_view.dart';
import 'package:mess_manager/views/bazar/meal_entry_view.dart';
import 'package:mess_manager/views/chat/chat_view.dart';
import 'package:mess_manager/views/summary/monthly_summary_view.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String createMess = '/create-mess';
  static const String inviteMember = '/invite-member';
  static const String messDashboard = '/mess-dashboard';
  static const String roomManagement = '/room-management';
  static const String bazarEntry = '/bazar-entry';
  static const String mealEntry = '/meal-entry';
  static const String chat = '/chat';
  static const String monthlySummary = '/monthly-summary';

  static final List<GetPage> pages = [
    GetPage(name: splash, page: () => const SplashView()),
    GetPage(name: login, page: () => const LoginView()),
    GetPage(name: register, page: () => const RegisterView()),
    GetPage(name: home, page: () => const HomeView()),
    GetPage(name: createMess, page: () => const CreateMessView()),
    GetPage(name: inviteMember, page: () => const InviteMemberView()),
    GetPage(name: messDashboard, page: () => const MessDashboardView()),
    GetPage(name: roomManagement, page: () => const RoomManagementView()),
    GetPage(name: bazarEntry, page: () => const BazarEntryView()),
    GetPage(name: mealEntry, page: () => const MealEntryView()),
    GetPage(name: chat, page: () => const ChatView()),
    GetPage(name: monthlySummary, page: () => const MonthlySummaryView()),
  ];
}
