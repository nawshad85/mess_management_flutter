import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mess_manager/app/routes/app_routes.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/models/user_model.dart';
import 'package:mess_manager/services/auth_service.dart';
import 'package:mess_manager/services/onesignal_service.dart';
import 'package:mess_manager/views/splash/splash_view.dart';

class TestUser implements User {
  TestUser(this.uid, {this.emailVerified = true});
  @override
  final String uid;
  @override
  bool emailVerified;
  bool verifyOnReload = false;
  @override
  Future<void> reload() async {
    if (verifyOnReload) emailVerified = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuthService implements AuthService {
  TestAuthService({this.currentUser, this.emitInitial = true});
  @override
  User? currentUser;
  final bool emitInitial;
  final events = StreamController<User?>.broadcast(sync: true);
  int signOuts = 0;
  int passwordLogins = 0;
  Future<UserModel?> Function()? loadProfile;
  UserModel profile(String uid) => UserModel(
    uid: uid,
    name: 'Member',
    uniqueId: 'ABCD1234',
    email: 'test@example.test',
  );
  @override
  Stream<User?> get authStateChanges async* {
    if (emitInitial) yield currentUser;
    yield* events.stream;
  }

  @override
  Future<UserModel?> getCurrentUserModel() async =>
      loadProfile != null ? loadProfile!() : profile(currentUser!.uid);
  void changeUser(User? user) {
    currentUser = user;
    events.add(user);
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    passwordLogins++;
    changeUser(TestUser('member', emailVerified: false));
    return profile('member');
  }

  @override
  Future<void> logout() async {
    signOuts++;
    changeUser(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestNotifications implements OneSignalService {
  bool fail = false;
  @override
  Future<void> setUserTags({required String uid, String? messId}) async {
    if (fail) throw StateError('Notifications unavailable');
  }

  @override
  Future<void> removeUserTags() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<AuthController> mount(
  WidgetTester tester,
  TestAuthService service, {
  TestNotifications? notifications,
}) async {
  final controller = AuthController(
    authService: service,
    oneSignalService: notifications ?? TestNotifications(),
  );
  await tester.pumpWidget(
    GetMaterialApp(
      defaultTransition: Transition.noTransition,
      initialBinding: BindingsBuilder(() {
        Get.put<AuthController>(controller, permanent: true);
      }),
      initialRoute: AppRoutes.splash,
      getPages: [
        GetPage(name: AppRoutes.splash, page: () => const SplashView()),
        GetPage(
          name: AppRoutes.login,
          page: () => const Scaffold(body: Text('LOGIN SCREEN')),
        ),
        GetPage(
          name: AppRoutes.home,
          page: () => const Scaffold(body: Text('SIGNED-IN HOME')),
        ),
        GetPage(
          name: AppRoutes.emailVerification,
          page: () => const Scaffold(body: Text('VERIFY EMAIL')),
        ),
      ],
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  testWidgets(
    'saved verified Firebase session restores home after first frame',
    (tester) async {
      final service = TestAuthService(currentUser: TestUser('member'));
      final controller = await mount(tester, service);
      await tester.pumpAndSettle();
      expect(find.text('SIGNED-IN HOME'), findsOneWidget);
      expect(controller.currentUser.value?.uid, 'member');
      expect(service.passwordLogins, 0);
      expect(service.signOuts, 0);
    },
  );
  testWidgets(
    'controller restart reuses the SDK session without password login',
    (tester) async {
      final service = TestAuthService(currentUser: TestUser('member'));
      await mount(tester, service);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      Get.reset();
      await mount(tester, service);
      await tester.pumpAndSettle();
      expect(find.text('SIGNED-IN HOME'), findsOneWidget);
      expect(service.passwordLogins, 0);
      expect(service.signOuts, 0);
    },
  );
  testWidgets(
    'startup waits for the first SDK event instead of showing login',
    (tester) async {
      final service = TestAuthService(
        currentUser: TestUser('member'),
        emitInitial: false,
      );
      await mount(tester, service);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('LOGIN SCREEN'), findsNothing);
      service.events.add(service.currentUser);
      await tester.pumpAndSettle();
      expect(find.text('SIGNED-IN HOME'), findsOneWidget);
    },
  );
  testWidgets('signed-out SDK state shows login', (tester) async {
    await mount(tester, TestAuthService());
    await tester.pumpAndSettle();
    expect(find.text('LOGIN SCREEN'), findsOneWidget);
  });
  testWidgets('profile load failure retains SDK session and supports retry', (
    tester,
  ) async {
    final service = TestAuthService(currentUser: TestUser('member'));
    service.loadProfile = () => Future.error(StateError('Offline'));
    final controller = await mount(tester, service);
    await tester.pumpAndSettle();
    expect(service.currentUser?.uid, 'member');
    expect(service.signOuts, 0);
    expect(controller.sessionRestoreError.value, contains('still signed in'));
    expect(find.text('LOGIN SCREEN'), findsNothing);
    service.loadProfile = () => Future.value(service.profile('member'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('SIGNED-IN HOME'), findsOneWidget);
  });
  testWidgets('missing profile is not silently treated as logout', (
    tester,
  ) async {
    final service = TestAuthService(currentUser: TestUser('member'));
    service.loadProfile = () => Future.value(null);
    final controller = await mount(tester, service);
    await tester.pumpAndSettle();
    expect(controller.sessionRestoreError.isNotEmpty, true);
    expect(service.currentUser, isNotNull);
    expect(service.signOuts, 0);
    expect(find.text('LOGIN SCREEN'), findsNothing);
  });
  testWidgets('slow profile completion cannot resurrect a signed-out user', (
    tester,
  ) async {
    final service = TestAuthService(currentUser: TestUser('member'));
    final pending = Completer<UserModel?>();
    service.loadProfile = () => pending.future;
    final controller = await mount(tester, service);
    service.changeUser(null);
    await tester.pumpAndSettle();
    pending.complete(service.profile('member'));
    await tester.pumpAndSettle();
    expect(controller.currentUser.value, isNull);
    expect(find.text('LOGIN SCREEN'), findsOneWidget);
  });
  testWidgets('stale null notification does not override a current SDK user', (
    tester,
  ) async {
    final service = TestAuthService(currentUser: TestUser('member'));
    await mount(tester, service);
    await tester.pumpAndSettle();
    service.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('SIGNED-IN HOME'), findsOneWidget);
    expect(service.signOuts, 0);
  });
  testWidgets('notification failures cannot interrupt restored login', (
    tester,
  ) async {
    final service = TestAuthService(currentUser: TestUser('member'));
    await mount(
      tester,
      service,
      notifications: TestNotifications()..fail = true,
    );
    await tester.pumpAndSettle();
    expect(find.text('SIGNED-IN HOME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unverified password login cannot bypass verification routing', (
    tester,
  ) async {
    final service = TestAuthService();
    final controller = await mount(tester, service);
    await tester.pumpAndSettle();
    await controller.login(email: 'test@example.test', password: 'test-only');
    await tester.pumpAndSettle();
    expect(find.text('VERIFY EMAIL'), findsOneWidget);
    expect(find.text('SIGNED-IN HOME'), findsNothing);
    expect(service.signOuts, 0);
  });
  testWidgets('verification refresh restores home without signing out', (
    tester,
  ) async {
    final user = TestUser('member', emailVerified: false)
      ..verifyOnReload = true;
    final service = TestAuthService(currentUser: user);
    await mount(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('SIGNED-IN HOME'), findsOneWidget);
    expect(service.signOuts, 0);
  });
  testWidgets('explicit logout still clears the authenticated UI', (
    tester,
  ) async {
    final service = TestAuthService(currentUser: TestUser('member'));
    final controller = await mount(tester, service);
    await tester.pumpAndSettle();
    await controller.logout();
    await tester.pumpAndSettle();
    expect(service.signOuts, 1);
    expect(controller.currentUser.value, isNull);
    expect(find.text('LOGIN SCREEN'), findsOneWidget);
  });
}
