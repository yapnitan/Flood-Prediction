import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/views/auth/register_view.dart';

void main() {
  // Like login_view_test.dart, these only exercise RegistrationPage's
  // field-level guard clauses in register(), all of which return before
  // calling AuthController/Supabase.
  const nameField = 0;
  const emailField = 1;
  const passwordField = 2;
  const confirmPasswordField = 3;

  testWidgets('shows a validation error when submitted with empty fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));

    final registerButton = find.widgetWithText(ElevatedButton, 'Register');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pump();

    expect(find.text('Please fill in all fields'), findsOneWidget);
  });

  testWidgets('rejects a password shorter than 8 characters', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));

    await tester.enterText(find.byType(TextField).at(nameField), 'Jane Doe');
    await tester.enterText(find.byType(TextField).at(emailField), 'jane@example.com');
    await tester.enterText(find.byType(TextField).at(passwordField), 'short');
    await tester.enterText(find.byType(TextField).at(confirmPasswordField), 'short');

    final registerButton = find.widgetWithText(ElevatedButton, 'Register');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pump();

    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });

  testWidgets('rejects mismatched password and confirmation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));

    await tester.enterText(find.byType(TextField).at(nameField), 'Jane Doe');
    await tester.enterText(find.byType(TextField).at(emailField), 'jane@example.com');
    await tester.enterText(find.byType(TextField).at(passwordField), 'password123');
    await tester.enterText(find.byType(TextField).at(confirmPasswordField), 'password456');

    final registerButton = find.widgetWithText(ElevatedButton, 'Register');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pump();

    expect(find.text('Password does not match'), findsOneWidget);
  });
}
