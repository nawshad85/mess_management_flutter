import 'package:get/get.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/controllers/mess_controller.dart';
import 'package:mess_manager/controllers/room_controller.dart';
import 'package:mess_manager/controllers/bazar_controller.dart';
import 'package:mess_manager/controllers/meal_controller.dart';
import 'package:mess_manager/controllers/chat_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController(), permanent: true);
    Get.put(MessController(), permanent: true);
    Get.put(RoomController(), permanent: true);
    Get.put(BazarController(), permanent: true);
    Get.put(MealController(), permanent: true);
    Get.put(ChatController(), permanent: true);
  }
}
