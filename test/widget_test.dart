import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:campusride_flutter/main.dart';

void main() {
  test('CampusRide root widget can be constructed', () {
    expect(const CampusRideApp(), isA<Widget>());
  });
}
