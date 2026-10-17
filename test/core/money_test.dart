import 'package:careway/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats sen as ringgit', () {
    expect(formatRm(2200), 'RM 22.00');
    expect(formatRm(14400), 'RM 144.00');
    expect(formatRm(50), 'RM 0.50');
  });

  test('zero is Free', () {
    expect(formatRm(0), 'Free');
  });
}
