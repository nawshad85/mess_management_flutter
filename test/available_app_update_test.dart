import 'package:flutter_test/flutter_test.dart';
import 'package:mess_manager/models/available_app_update.dart';

void main() {
  group('AvailableAppUpdate', () {
    AvailableAppUpdate buildUpdate(UpdateDistribution distribution) {
      return AvailableAppUpdate(
        distribution: distribution,
        installedVersion: '1.0.0',
        installedBuild: 1,
        availableVersion: '1.1.0',
        availableBuild: 2,
        title: 'Update available',
        message: 'A new version is ready.',
        storeUri: Uri.parse('https://play.google.com/store/apps/details'),
      );
    }

    test('direct releases do not use Google Play', () {
      expect(
        buildUpdate(UpdateDistribution.direct).usesGooglePlay,
        isFalse,
      );
    });

    test('Play releases use Google Play', () {
      expect(buildUpdate(UpdateDistribution.play).usesGooglePlay, isTrue);
    });
  });
}
