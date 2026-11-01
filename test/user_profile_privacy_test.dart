import 'package:flutter_test/flutter_test.dart';
import 'package:mess_manager/models/user_model.dart';

void main() {
  final user = UserModel(
    uid: 'member',
    name: 'Member',
    uniqueId: 'ABCD1234',
    email: 'private@example.test',
    managerPinHash: 'private-hash',
    managerPinSalt: 'private-salt',
    messId: 'mess',
    role: 'manager',
  );

  test('shared member profiles exclude email and all PIN material', () {
    expect(user.toMemberProfileMap(), {
      'uid': 'member',
      'name': 'Member',
      'uniqueId': 'ABCD1234',
      'messId': 'mess',
      'role': 'manager',
      'roomId': null,
    });
  });
  test(
    'invite lookup exposes only the fields needed to send an invitation',
    () {
      expect(user.toInviteCodeMap(), {
        'uid': 'member',
        'name': 'Member',
        'messId': 'mess',
      });
    },
  );
}
