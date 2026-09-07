import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/views/auth/login_view.dart';

void main() {
  // These only exercise the empty-field guard clause in LoginView.login(),
  // which returns before ever touching AuthController/Supabase — so no
  // Supabase initialization or mocking is needed for this path.
  testWidgets('shows a validation error when submitted with empty fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginView()));

    expect(find.text('Please enter your email'), findsNothing);
    expect(find.text('Please enter your password'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('shows a validation error when only the password is filled in', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginView()));

    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsNothing);
  });
}
