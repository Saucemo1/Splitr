// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_bill_splitter/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BillSplitterApp());

    // Verify that our counter starts at 0.
    expect(find.text('Smart Bill Splitter'), findsOneWidget);
    expect(find.text('1. Add Bill'), findsOneWidget);

    // Verify that we can find the upload and camera buttons
    expect(find.byIcon(Icons.upload_file), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });
}
