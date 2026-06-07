# State Management Review

Generated: 2026-05-26

## Scope

Reviewed the Flutter app structure, GetX bindings, controllers, Firebase service streams, main views, and current tests. The app uses GetX as the state-management and navigation layer, with Firebase Auth and Firestore streams feeding permanent controllers.

## Executive Summary

GetX itself is not the main problem in this project. The bigger issue is lifecycle ownership: several permanent controllers create Firestore stream subscriptions inside `ever(...)` callbacks without storing or cancelling those subscriptions. This can produce duplicate listeners, stale data after logout or mess changes, extra Firestore reads, and hard-to-debug UI updates.

The highest-value improvements are:

1. Own and cancel every Firebase stream subscription in controllers.
2. Clear feature state when `currentUser` or `currentMess` becomes null.
3. Stop making every feature controller permanent unless it truly needs to live for the full app lifetime.
4. Split broad `Obx` rebuilds into smaller reactive widgets.
5. Add controller tests with fake services; the current test is still the default counter test.

## Current Architecture

- Dependency injection is centralized in `lib/app/bindings/app_binding.dart`.
- State is held in GetX controllers under `lib/controllers/`.
- Services under `lib/services/` expose Firebase reads/writes and Firestore streams.
- Views call controllers with `Get.find<T>()` and use `Obx` for reactive rebuilds.
- Most domain state is global: auth user, current mess, rooms, bazar entries, meal entries, chat messages, notices, and monthly summary.

This is a reasonable small-to-medium app structure, but it needs stricter stream lifecycle handling because the app is real-time and user/mess scoped.

## Findings

### High: Firestore stream subscriptions are not stored or cancelled

Affected examples:

- `lib/controllers/auth_controller.dart:20` listens to `FirebaseAuth.instance.authStateChanges()`.
- `lib/controllers/mess_controller.dart:44`, `52`, and `59` listen to invitation and mess streams.
- `lib/controllers/room_controller.dart:24` and `32` listen to room streams.
- `lib/controllers/bazar_controller.dart:28` and `36` listen to bazar streams.
- `lib/controllers/meal_controller.dart:28` and `36` listen to meal streams.
- `lib/controllers/chat_controller.dart:33` and `41` listen to message streams.
- `lib/controllers/notice_controller.dart:28` and `36` listen to notice streams.

Why this matters:

- Every auth or mess change can open a new stream listener without closing the old one.
- The immediate listener plus the `ever(...)` listener can create duplicate subscriptions for the same mess.
- Old listeners can keep writing into controller state after the user leaves a mess, deletes a mess, logs out, or switches accounts.
- Permanent controllers make the leak last for the whole app session.

Recommended fix:

- Store `StreamSubscription` fields for each active stream.
- Store `Worker` fields returned by `ever(...)`.
- Cancel the previous stream before starting a new one.
- Cancel everything in `onClose()`.
- Clear state when the source becomes null.

Example pattern:

```dart
class RoomController extends GetxController {
  StreamSubscription<List<RoomModel>>? _roomsSub;
  Worker? _messWorker;

  @override
  void onInit() {
    super.onInit();
    _messWorker = ever(_messController.currentMess, _bindRooms);
    _bindRooms(_messController.currentMess.value);
  }

  void _bindRooms(MessModel? mess) {
    _roomsSub?.cancel();
    if (mess == null) {
      rooms.clear();
      return;
    }
    _roomsSub = _firestoreService.roomsStream(mess.messId).listen(
      (roomList) => rooms.value = roomList,
    );
  }

  @override
  void onClose() {
    _roomsSub?.cancel();
    _messWorker?.dispose();
    super.onClose();
  }
}
```

Apply the same pattern to mess, bazar, meal, chat, and notice controllers.

### High: Feature state is not cleared when there is no active mess

Affected examples:

- `RoomController._listenToRooms()` does nothing when `currentMess` becomes null.
- `BazarController._listenToBazarEntries()` does nothing when `currentMess` becomes null.
- `MealController._listenToMealEntries()` does nothing when `currentMess` becomes null.
- `ChatController._listenToMessages()` does nothing when `currentMess` becomes null.
- `NoticeController._listenToNotices()` does nothing when `currentMess` becomes null.

Why this matters:

- After logout, mess deletion, or account switching, old rooms, bazar entries, meal entries, messages, and notices can remain in memory.
- If a new user logs in before the new streams emit, the UI may briefly show previous user or previous mess data.
- Old stream listeners can still overwrite cleared state unless they are also cancelled.

Recommended fix:

- Add a `clear()` or `_resetState()` method to each feature controller.
- Call it when `currentMess == null`.
- Cancel active subscriptions before clearing.
- Consider a single `resetForLogout()` path from `AuthController.logout()`.

### Medium: All controllers are eager permanent singletons

Affected file:

- `lib/app/bindings/app_binding.dart:14-21`

Current behavior:

```dart
Get.put(AuthController(), permanent: true);
Get.put(MessController(), permanent: true);
Get.put(RoomController(), permanent: true);
Get.put(BazarController(), permanent: true);
Get.put(MealController(), permanent: true);
Get.put(ChatController(), permanent: true);
Get.put(SummaryController(), permanent: true);
Get.put(NoticeController(), permanent: true);
```

Why this matters:

- Feature controllers are alive even on login, register, and email verification screens.
- Real-time listeners can stay active even when a feature screen is never opened.
- Permanent controllers make `onClose()` unlikely to run during normal app use, so explicit stream cancellation on auth/mess changes becomes even more important.

Recommended fix:

- Keep `AuthController` permanent.
- Keep `MessController` permanent only if the home/dashboard needs global mess state.
- Register feature controllers with route bindings or `Get.lazyPut` when the feature is opened.
- If keeping them permanent for dashboard stats, make stream cancellation and state clearing non-negotiable.

### Medium: Derived state can become stale

Affected examples:

- `lib/controllers/mess_controller.dart:59-63` reloads members when the mess document stream emits.
- `lib/services/firestore_service.dart:552-562` fetches members one by one using one-time reads.
- `lib/controllers/mess_controller.dart:42-55` listens to pending invitations but does not cancel or clear old invitation streams.

Why this matters:

- `messMembers` is not a live stream of user documents. If a member's name, role, roomId, or profile data changes without the mess document changing, `messMembers` can stay stale.
- Room assignment updates user documents in `FirestoreService.assignMemberToRoom()`, but member list refresh depends on controller calls and unrelated mess updates.
- Invitation state can be written by an old user subscription after account changes.

Recommended fix:

- Stream member profiles based on `mess.memberIds`, or create a mess-scoped member projection/subcollection if the app needs live member metadata.
- Cancel and restart the invitation stream when `currentUser.uid` changes.
- Clear `pendingInvites` when there is no authenticated user.

### Medium: Broad `Obx` scopes rebuild large UI areas

Affected examples:

- `lib/views/home/home_view.dart:29` wraps the main home decision tree in `Obx`.
- `lib/views/room/room_management_view.dart:20` wraps the full body in `Obx`.
- `lib/views/bazar/bazar_entry_view.dart:27` wraps the full body in `Obx`.
- `lib/views/bazar/meal_entry_view.dart:97` wraps the full body in `Obx`.
- `lib/views/chat/chat_view.dart:164` wraps the message list area in `Obx`.
- `lib/views/mess/mess_dashboard_view.dart:26`, `30`, `66`, `252`, and `403` use several reactive sections.

Why this matters:

- Any small reactive change can rebuild large widget subtrees.
- Chat, bazar, meal, and dashboard screens may become janky as lists grow.
- It becomes harder to reason about which state change triggered a UI update.

Recommended fix:

- Keep top-level auth/mess gating reactive, but split heavy content into smaller widgets.
- Wrap only the text, badge, list, button, or stat that depends on a specific `Rx`.
- Prefer computed local variables inside the smallest possible `Obx`.
- For long lists, keep list item widgets stateless and pass immutable model snapshots.

### Medium: Shared `isLoading` flags are too coarse

Affected examples:

- `AuthController.isLoading` is used for login, register, and password reset.
- `MessController.isLoading` is used for create mess, invite, reset, remove member, and delete mess.
- `RoomController.isLoading` is used for assign, schedule, clear, and unassign.
- `BazarController.isLoading` and `MealController.isLoading` are shared across add/update/delete style actions.

Why this matters:

- If two operations overlap, the first one to finish can set `isLoading` to false while another operation is still running.
- One action can disable or show loading on unrelated UI controls.
- Loading state does not tell the UI which action is pending.

Recommended fix:

- Use action-specific flags such as `isInviting`, `isDeletingMess`, `isSavingSchedule`.
- Or use an enum/state object per controller, for example `Rx<MessAction?> activeAction`.
- For repeated row actions, use `RxSet<String> pendingEntryIds` or `RxMap<String, bool>`.

### Medium: Controllers mix business state, navigation, and UI notifications

Affected examples:

- `lib/controllers/auth_controller.dart:27`, `47`, `53`, and `111` navigate directly.
- `lib/controllers/auth_controller.dart:191-204` owns snackbar styling.
- Most controllers call `_authController.showSnackbar(...)`.
- Views also navigate after auth actions, for example `lib/views/auth/login_view.dart:154` and `lib/views/auth/register_view.dart:167`.

Why this matters:

- Controller tests become harder because actions trigger routes and snackbars.
- Auth navigation can race or duplicate because both views and `AuthController` navigate.
- Domain controllers become coupled to `AuthController` as a UI notification service.

Recommended fix:

- Move global route decisions into a small auth gate, middleware, or routing service.
- Return typed action results from controllers and let views decide how to show feedback.
- If keeping snackbars centralized, create a dedicated notification service instead of routing all UI messages through `AuthController`.

### Low: Null assertions can crash during auth or mess transitions

Affected examples:

- `lib/controllers/bazar_controller.dart:49-50`, `98-99`, `132-133`
- `lib/controllers/meal_controller.dart:49-50`, `97-98`
- `lib/controllers/chat_controller.dart:80-81`
- `lib/controllers/mess_controller.dart:114-115`, `182`
- `lib/controllers/room_controller.dart:44`, `81`, `107`

Why this matters:

- These actions assume user and mess state still exists after async UI interactions.
- During logout, mess deletion, auth refresh, or slow stream updates, these values can become null.

Recommended fix:

- Replace `value!` with guards and user-facing failures.
- Capture the user/mess at the start of an action and use those local values consistently.
- Disable action controls when required state is absent.

### Low: Local view state is inconsistent but mostly acceptable

Affected examples:

- `lib/views/auth/email_verification_view.dart:17-18` uses local `RxBool` and `RxInt`.
- `lib/views/bazar/bazar_entry_view.dart:103` and `267` use local `RxList` inside view methods.
- Several screens use `setState()` for purely local selection/input state.

This is not inherently wrong. Local `setState()` is appropriate for tab indices, selected dates, form fields, temporary dialog state, and countdown UI. The improvement is consistency: avoid using GetX `Rx` for short-lived local state unless it clearly simplifies a modal or bottom sheet.

Recommended fix:

- Use `setState()` or `ValueNotifier` for widget-local state.
- Use GetX `Rx` for app/domain state shared across widgets or routes.

## Analyzer Results

`flutter analyze` was run. It completed with 7 info-level issues:

- `lib/models/meal_entry_model.dart:44` - parameter name matches a type name.
- `lib/utils/secrets.dart:1` - dangling library doc comment.
- `lib/views/bazar/meal_entry_view.dart:737` - `BuildContext` used across async gap.
- `lib/views/mess/mess_dashboard_view.dart:537` - `BuildContext` used across async gap.
- `lib/views/mess/mess_dashboard_view.dart:584` - `BuildContext` used across async gap.
- `lib/views/room/room_management_view.dart:407` - `BuildContext` used across async gap.
- `lib/views/summary/monthly_summary_view.dart:684` - deprecated `activeColor`.

These are not all state-management issues, but the async context warnings are worth fixing because they can surface during navigation or controller-driven async actions.

## Test Coverage Gap

Affected file:

- `test/widget_test.dart:14-29`

The test file is still the default counter smoke test and does not match this app. There are no visible tests for controller stream binding, logout cleanup, mess switching, permissions, or loading states.

Recommended tests:

- `AuthController` auth-state transitions: unauthenticated, unverified, verified.
- `MessController` stream cancellation and pending invitation cleanup on user change.
- `RoomController`, `BazarController`, `MealController`, `ChatController`, and `NoticeController` state clears when `currentMess` becomes null.
- Permission methods such as `canEditBazar` and `canEditBazarEntry`.
- Loading-state behavior for overlapping operations if action-specific flags are added.

## Suggested Remediation Order

1. Add subscription and worker ownership to all stream-based controllers.
2. Clear all feature controller state on `currentMess == null` and logout.
3. Refactor `AppBinding` so only truly global controllers are permanent.
4. Replace broad `Obx` wrappers with smaller reactive widgets on high-traffic screens.
5. Replace shared `isLoading` flags with action-specific state for manager actions and row-level operations.
6. Move navigation/snackbar side effects out of domain controllers or wrap them in dedicated services.
7. Replace null assertions in controller actions with guards.
8. Replace the default widget test with controller tests using fake services.

## Overall Assessment

The project has a workable GetX architecture, but it is currently fragile around realtime stream lifecycle. I would not recommend a state-management migration as the first fix. Clean up stream ownership, auth/mess scoped resets, and rebuild boundaries first. If the app grows significantly after that, Riverpod or Bloc could provide stronger dependency and lifecycle boundaries, but the current codebase can be improved substantially without changing libraries.
