import 'package:flutter_test/flutter_test.dart';
import 'package:vellum/vellum.dart';

void main() {
  test('the public API is exported', () {
    expect(const VellumException('x').toString(), 'VellumException: x');
    expect(ZipCompression.values, hasLength(3));
  });
}
