import 'package:echoes/core/services/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares development versions against stable releases', () {
    expect(UpdateChecker.compareVersions('1.0.6-dev', '1.0.5'), greaterThan(0));
    expect(UpdateChecker.compareVersions('1.0.6-dev', '1.0.6'), lessThan(0));
    expect(UpdateChecker.compareVersions('1.0.6', '1.0.6-dev'), greaterThan(0));
  });

  test('compares prerelease identifiers and ignores build metadata', () {
    expect(
      UpdateChecker.compareVersions('v1.0.6-dev.2+17', '1.0.6-dev.10'),
      lessThan(0),
    );
    expect(UpdateChecker.compareVersions('1.0.6+17', '1.0.6+18'), 0);
  });
}
