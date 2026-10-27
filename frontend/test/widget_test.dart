import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studentstay_app/main.dart';
import 'package:studentstay_app/services/api_service.dart';
import 'package:studentstay_app/services/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StudentStay app launches with LoginScreen and navigates into shell',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.contains('/properties')) {
        return http.Response(
          jsonEncode({
            'items': [],
            'total': 0,
            'page': 1,
            'page_size': 10,
            'pages': 0,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not found', 404);
    });

    final apiService = ApiService(client: mockClient);
    final authService = AuthService(apiService: apiService);

    await tester.pumpWidget(
      StudentStayApp(
        apiService: apiService,
        authService: authService,
      ),
    );
    await tester.pumpAndSettle();

    // 1. By default, unauthenticated user sees LoginScreen
    expect(find.text('StudentStay'), findsWidgets);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Create Account'), findsWidgets);

    // 2. Continuing as guest (or logging in) opens Main Navigation destinations
    await tester.tap(find.text('Explore as Guest without login'));
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Map View'), findsWidgets);
    expect(find.text('Owner Portal'), findsWidgets);
    expect(find.text('Account'), findsWidgets);
  });
}
