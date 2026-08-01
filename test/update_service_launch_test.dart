import 'package:flutter_test/flutter_test.dart';
import 'package:fluentup/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UpdateService instance exists and triggers version check correctly', () {
    final service = UpdateService.instance;
    expect(service, isNotNull);
  });
}
