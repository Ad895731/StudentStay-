import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studentstay_app/models/property.dart';
import 'package:studentstay_app/screens/explore_stays_screen.dart';
import 'package:studentstay_app/screens/owner_dashboard_screen.dart';
import 'package:studentstay_app/screens/profile_screen.dart';
import 'package:studentstay_app/screens/property_detail_screen.dart';
import 'package:studentstay_app/services/api_service.dart';
import 'package:studentstay_app/services/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 9: AuthService Tests', () {
    test('Restore session with no saved token leaves unauthenticated', () async {
      SharedPreferences.setMockInitialValues({});
      final authService = AuthService(apiService: ApiService());

      await authService.restoreSession();

      expect(authService.isAuthenticated, isFalse);
      expect(authService.token, isNull);
      expect(authService.currentUser, isNull);
    });

    test('Restore session with valid saved token restores user and role', () async {
      SharedPreferences.setMockInitialValues({
        'studentstay_auth_token': 'valid_jwt_token_123',
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          expect(request.headers['Authorization'], 'Bearer valid_jwt_token_123');
          return http.Response(
            jsonEncode({
              'id': 1,
              'email': 'owner@studentstay.com',
              'full_name': 'Test Owner',
              'phone': '9876543210',
              'role': 'owner',
              'is_active': true,
              'created_at': '2026-10-18T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiService = ApiService(client: mockClient);
      final authService = AuthService(apiService: apiService);

      await authService.restoreSession();

      expect(authService.isAuthenticated, isTrue);
      expect(authService.token, 'valid_jwt_token_123');
      expect(authService.currentUser?.email, 'owner@studentstay.com');
      expect(authService.isOwner, isTrue);
      expect(authService.isStudent, isFalse);
    });

    test('Restore session with expired token clears storage', () async {
      SharedPreferences.setMockInitialValues({
        'studentstay_auth_token': 'expired_jwt_token',
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return http.Response(
            jsonEncode({'detail': 'Could not validate credentials'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiService = ApiService(client: mockClient);
      final authService = AuthService(apiService: apiService);

      await authService.restoreSession();

      expect(authService.isAuthenticated, isFalse);
      expect(authService.token, isNull);
      expect(authService.currentUser, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('studentstay_auth_token'), isNull);
    });

    test('Login success stores token and sets current user', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'access_token': 'fresh_jwt_token_xyz',
              'token_type': 'bearer',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.endsWith('/auth/me')) {
          return http.Response(
            jsonEncode({
              'id': 2,
              'email': 'student@example.com',
              'full_name': 'Student Jane',
              'phone': '9123456780',
              'role': 'student',
              'is_active': true,
              'created_at': '2026-10-18T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiService = ApiService(client: mockClient);
      final authService = AuthService(apiService: apiService);

      final ok = await authService.login(email: 'student@example.com', password: 'password123');

      expect(ok, isTrue);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.isStudent, isTrue);
      expect(authService.token, 'fresh_jwt_token_xyz');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('studentstay_auth_token'), 'fresh_jwt_token_xyz');
    });

    test('Login failure surfaces error message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid email or password'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(client: mockClient);
      final authService = AuthService(apiService: apiService);

      final ok = await authService.login(email: 'wrong@example.com', password: 'wrongpassword');

      expect(ok, isFalse);
      expect(authService.isAuthenticated, isFalse);
      expect(authService.authError, contains('Invalid email or password'));
    });

    test('Logout clears session and preferences', () async {
      SharedPreferences.setMockInitialValues({
        'studentstay_auth_token': 'active_token',
      });

      final authService = AuthService(apiService: ApiService());
      await authService.logout();

      expect(authService.isAuthenticated, isFalse);
      expect(authService.token, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('studentstay_auth_token'), isNull);
    });
  });

  group('Phase 9: ExploreStaysScreen Widget Tests', () {
    testWidgets('Renders property cards with thumbnail, rent, city and badges',
        (WidgetTester tester) async {
      final propertiesJson = [
        {
          'id': 101,
          'title': 'Green Nest PG',
          'description': 'Near FC College with high speed wifi',
          'property_type': 'pg',
          'address': 'Ferguson College Road',
          'city': 'Pune',
          'latitude': 18.5204,
          'longitude': 73.8567,
          'is_verified': true,
          'is_available': true,
          'starting_rent': 6500.0,
          'rooms': [
            {
              'id': 1,
              'property_id': 101,
              'sharing_type': 'single',
              'monthly_rent': 6500.0,
              'available_beds': 1,
            }
          ],
          'amenities': [],
          'images': [],
        }
      ];

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/properties')) {
          return http.Response(
            jsonEncode({
              'items': propertiesJson,
              'total': 1,
              'page': 1,
              'page_size': 10,
              'pages': 1,
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
        MaterialApp(
          home: ExploreStaysScreen(
            apiService: apiService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Green Nest PG'), findsOneWidget);
      expect(find.textContaining('Pune'), findsWidgets);
      expect(find.text('₹6500/mo'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Search bar
    });

    testWidgets('Shows empty state when no properties found',
        (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
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
      });

      final apiService = ApiService(client: mockClient);
      final authService = AuthService(apiService: apiService);

      await tester.pumpWidget(
        MaterialApp(
          home: ExploreStaysScreen(
            apiService: apiService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No accommodations found'), findsOneWidget);
    });

    testWidgets('Opens filter modal when filter button tapped',
        (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
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
      });

      final apiService = ApiService(client: mockClient);
      final authService = AuthService(apiService: apiService);

      await tester.pumpWidget(
        MaterialApp(
          home: ExploreStaysScreen(
            apiService: apiService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap filter icon
      await tester.tap(find.byKey(const Key('filter_button')));
      await tester.pumpAndSettle();

      expect(find.text('Filter & Sort Accommodations'), findsOneWidget);
      expect(find.text('Property Type'), findsOneWidget);
      expect(find.text('Room Sharing'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);
    });
  });

  group('Phase 9: PropertyDetailScreen Widget Tests', () {
    testWidgets('Displays rooms, amenities, availability and directions button',
        (WidgetTester tester) async {
      final property = Property(
        id: 101,
        ownerId: 1,
        title: 'Shree Krishna Hostel',
        description: 'Spacious student hostel with mess facility.',
        propertyType: 'hostel',
        address: '123 Model Colony',
        city: 'Pune',
        latitude: 18.5300,
        longitude: 73.8400,
        isVerified: true,
        isAvailable: true,
        securityDeposit: 10000.0,
        rooms: [
          Room(
            id: 1,
            propertyId: 101,
            sharingType: 'double',
            monthlyRent: 7500.0,
            availableBeds: 1,
          ),
        ],
        amenities: [
          Amenity(id: 1, name: 'High-Speed Wi-Fi'),
          Amenity(id: 2, name: 'Mess / Food'),
        ],
        images: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyDetailScreen(
            property: property,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shree Krishna Hostel'), findsWidgets);
      expect(find.text('About Property'), findsOneWidget);
      expect(find.text('Spacious student hostel with mess facility.'), findsOneWidget);
      expect(find.text('Currently Available for Students'), findsOneWidget);
      expect(find.text('Rooms & Sharing Options'), findsOneWidget);
      expect(find.text('DOUBLE SHARING'), findsOneWidget);
      expect(find.text('₹7500/mo'), findsOneWidget);
      expect(find.text('Amenities & Features'), findsOneWidget);
      expect(find.text('High-Speed Wi-Fi'), findsOneWidget);
      expect(find.text('Mess / Food'), findsOneWidget);
      expect(find.byKey(const Key('get_directions_button')), findsOneWidget);
    });
  });

  group('Phase 9: OwnerDashboardScreen Widget Tests', () {
    testWidgets('Shows sign in required prompt when unauthenticated',
        (WidgetTester tester) async {
      final authService = AuthService(apiService: ApiService());

      await tester.pumpWidget(
        MaterialApp(
          home: OwnerDashboardScreen(
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Owner Sign-In Required'), findsOneWidget);
      expect(find.text('Sign In or Register as Owner'), findsOneWidget);
    });

    testWidgets('Shows owner access only when logged in as a student',
        (WidgetTester tester) async {
      // Simulate student login
      SharedPreferences.setMockInitialValues({
        'studentstay_auth_token': 'student_token',
      });

      final studentClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 5,
            'email': 'student@test.com',
            'name': 'Student Dave',
            'role': 'student',
            'is_active': true,
            'created_at': '2026-10-18T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final studentAuth = AuthService(apiService: ApiService(client: studentClient));
      await studentAuth.restoreSession();

      await tester.pumpWidget(
        MaterialApp(
          home: OwnerDashboardScreen(
            authService: studentAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Student Account Active'), findsOneWidget);
      expect(find.textContaining('Property creation and management is reserved for accommodation owners'), findsOneWidget);
    });

    testWidgets('Shows owner listings with verification and availability status when logged in as owner',
        (WidgetTester tester) async {
      final ownerListings = [
        {
          'id': 201,
          'owner_id': 10,
          'title': 'Sunflower Girls PG',
          'description': 'Safe PG for female students',
          'property_type': 'pg',
          'address': 'Kothrud, Pune',
          'city': 'Pune',
          'latitude': 18.5074,
          'longitude': 73.8077,
          'is_verified': false,
          'is_available': true,
          'starting_rent': 8000.0,
          'rooms': [],
          'amenities': [],
          'images': [],
        }
      ];

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/properties/my')) {
          return http.Response(
            jsonEncode(ownerListings),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.endsWith('/auth/me')) {
          return http.Response(
            jsonEncode({
              'id': 10,
              'email': 'owner@test.com',
              'name': 'Owner Bob',
              'role': 'owner',
              'is_active': true,
              'created_at': '2026-10-18T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiService = ApiService(client: mockClient);
      final authService = AuthService(apiService: apiService);

      SharedPreferences.setMockInitialValues({
        'studentstay_auth_token': 'owner_token_123',
      });
      await authService.restoreSession();

      await tester.pumpWidget(
        MaterialApp(
          home: OwnerDashboardScreen(
            apiService: apiService,
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Property Listings'), findsOneWidget);
      expect(find.text('Sunflower Girls PG'), findsOneWidget);
      expect(find.text('PENDING REVIEW'), findsOneWidget);
      expect(find.text('Add Property'), findsOneWidget);
    });
  });

  group('Phase 9: ProfileScreen Widget Tests', () {
    testWidgets('Shows login and registration tabs when unauthenticated',
        (WidgetTester tester) async {
      final authService = AuthService(apiService: ApiService());

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.byKey(const Key('login_email_input')), findsOneWidget);
      expect(find.byKey(const Key('login_password_input')), findsOneWidget);
      expect(find.byKey(const Key('submit_login_button')), findsOneWidget);
    });

    testWidgets('Shows user profile card and logout option when authenticated',
        (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 42,
            'email': 'rohit@studentstay.in',
            'name': 'Rohit Sharma',
            'phone': '9811223344',
            'role': 'student',
            'is_active': true,
            'created_at': '2026-10-18T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authService = AuthService(apiService: ApiService(client: mockClient));
      SharedPreferences.setMockInitialValues({
        'studentstay_auth_token': 'rohit_token',
      });
      await authService.restoreSession();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            authService: authService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rohit Sharma'), findsOneWidget);
      expect(find.text('rohit@studentstay.in'), findsOneWidget);
      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });
}
