import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/views/auth/register_view.dart';

void main() {
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

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter a password'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);
  });

  testWidgets('rejects a password that does not meet the policy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));

    await tester.enterText(find.byType(TextField).at(nameField), 'Jane Doe');
    await tester.enterText(find.byType(TextField).at(emailField), 'jane@example.com');
    await tester.enterText(find.byType(TextField).at(passwordField), 'short');
    await tester.enterText(find.byType(TextField).at(confirmPasswordField), 'short');

    final registerButton = find.widgetWithText(ElevatedButton, 'Register');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pump();

    expect(find.textContaining('Password needs'), findsOneWidget);
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

    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
