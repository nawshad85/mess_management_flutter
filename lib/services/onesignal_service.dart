import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:mess_manager/utils/secrets.dart';

class OneSignalService {
  OneSignalService._internal();

  static final OneSignalService _instance = OneSignalService._internal();

  factory OneSignalService() => _instance;

  // Credentials loaded from secrets.dart (gitignored)
  static const String _appId = oneSignalAppId;
  static const String _restApiKey = oneSignalRestApiKey;

  /// Initialize OneSignal SDK.
  void initialize() {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(_appId);
    OneSignal.Notifications.requestPermission(true);
  }

  /// Tag the current device with user info so we can target notifications.
  void setUserTags({required String uid, String? messId}) {
    OneSignal.login(uid);
    final tags = <String, String>{'uid': uid};
    if (messId != null && messId.isNotEmpty) {
      tags['messId'] = messId;
    }
    OneSignal.User.addTags(tags);
  }

  /// Update the messId tag (e.g. after joining/creating a mess).
  void updateMessTag(String messId) {
    OneSignal.User.addTags({'messId': messId});
  }

  /// Remove tags and logout from OneSignal (on app logout).
  void removeUserTags() {
    OneSignal.User.removeTags(['uid', 'messId']);
    OneSignal.logout();
  }

  /// Send a push notification to all users in the same mess, excluding sender.
  Future<void> sendChatNotification({
    required String senderName,
    required String senderId,
    required String content,
    required String messId,
    List<String> mentions = const [],
  }) async {
    try {
      final url = Uri.parse('https://api.onesignal.com/notifications');

      final body = {
        'app_id': _appId,
        'filters': [
          {'field': 'tag', 'key': 'messId', 'relation': '=', 'value': messId},
          {'operator': 'AND'},
          {
            'field': 'tag',
            'key': 'uid',
            'relation': '!=',
            'value': senderId,
          },
        ],
        'headings': {'en': senderName},
        'contents': {'en': content},
        'android_channel_id': null, // uses default
        'small_icon': 'ic_stat_onesignal_default',
      };

      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $_restApiKey',
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      // Silently fail — push is best-effort, don't block chat
    }
  }
}
