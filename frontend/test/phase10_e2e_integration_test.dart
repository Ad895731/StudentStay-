import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studentstay_app/services/api_service.dart';
import 'package:studentstay_app/services/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 10: Base URL Resolution & Error Extraction', () {
    test('resolveBaseUrl strips trailing slashes', () {
      expect(
        ApiService.resolveBaseUrl('http://192.168.1.100:8000/'),
        equals('http://192.168.1.100:8000'),
      );
      expect(
        ApiService.resolveBaseUrl('http://custom-api.com:8000'),
        equals('http://custom-api.com:8000'),
      );
    });

    test('extractErrorMessage handles string detail, list detail, and fallback', () {
      final strResponse = http.Response(jsonEncode({'detail': 'Invalid credentials'}), 401);
      expect(ApiService.extractErrorMessage(strResponse), equals('Invalid credentials'));

      final listResponse = http.Response(
        jsonEncode({
          'detail': [
            {'loc': ['body', 'password'], 'msg': 'Password too short', 'type': 'value_error'}
          ]
        }),
        422,
      );
      expect(ApiService.extractErrorMessage(listResponse), equals('Password too short'));

      final htmlResponse = http.Response('<html>502 Bad Gateway</html>', 502);
      expect(ApiService.extractErrorMessage(htmlResponse, fallback: 'Server unavailable'), equals('Server unavailable'));
    });
  });

  group('Phase 10: Complete Student Flow', () {
    test('Student registration, login, profile check, explore, details, and logout', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('/auth/register') && request.method == 'POST') {
          final body = jsonDecode(request.body);
          expect(body['email'], 'student@studentstay.com');
          expect(body['role'], 'student');
          return http.Response(
            jsonEncode({
              'id': 101,
              'name': 'Aarav Patel',
              'email': 'student@studentstay.com',
              'role': 'student',
              'created_at': '2026-10-19T00:00:00Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/auth/login') && request.method == 'POST') {
          final body = jsonDecode(request.body);
          expect(body['email'], 'student@studentstay.com');
          expect(body['password'], 'secretPass123');
          return http.Response(
            jsonEncode({'access_token': 'student_jwt_token_999', 'token_type': 'bearer'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/auth/me') && request.method == 'GET') {
          expect(request.headers['Authorization'], 'Bearer student_jwt_token_999');
          return http.Response(
            jsonEncode({
              'id': 101,
              'name': 'Aarav Patel',
              'email': 'student@studentstay.com',
              'role': 'student',
              'created_at': '2026-10-19T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/properties') && request.method == 'GET') {
          final q = request.url.queryParameters['q'];
          final city = request.url.queryParameters['city'];
          final sortBy = request.url.queryParameters['sort_by'];

          expect(q, 'College');
          expect(city, 'Pune');
          expect(sortBy, 'rent_low_to_high');

          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 501,
                  'owner_id': 201,
                  'title': 'FC Road Student Stay',
                  'description': 'Opposite Ferguson College',
                  'property_type': 'pg',
                  'address': 'FC Road',
                  'city': 'Pune',
                  'latitude': 18.5204,
                  'longitude': 73.8567,
                  'security_deposit': 5000.0,
                  'is_verified': true,
                  'is_available': true,
                  'distance_km': 1.2,
                  'images': [
                    {
                      'id': 1,
                      'property_id': 501,
                      'image_url': 'https://example.com/img1.jpg',
                      'storage_path': 'properties/501/img1.jpg',
                    }
                  ],
                }
              ],
              'page': 1,
              'page_size': 10,
              'total': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/properties/501') && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 501,
              'owner_id': 201,
              'title': 'FC Road Student Stay',
              'description': 'Opposite Ferguson College with WiFi and Food',
              'property_type': 'pg',
              'address': 'FC Road',
              'city': 'Pune',
              'latitude': 18.5204,
              'longitude': 73.8567,
              'security_deposit': 5000.0,
              'is_verified': true,
              'is_available': true,
              'rooms': [
                {
                  'id': 10,
                  'property_id': 501,
                  'sharing_type': 'double',
                  'monthly_rent': 6000.0,
                  'available_beds': 2,
                }
              ],
              'amenities': [
                {'id': 1, 'name': 'High-Speed Wi-Fi'},
                {'id': 2, 'name': 'Power Backup'},
              ],
              'images': [
                {
                  'id': 1,
                  'property_id': 501,
                  'image_url': 'https://example.com/img1.jpg',
                  'storage_path': 'properties/501/img1.jpg',
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(baseUrl: 'http://test-server:8000', client: mockClient);
      final authService = AuthService(apiService: apiService);

      // 1. Register student
      final registeredUser = await authService.register(
        name: 'Aarav Patel',
        email: 'student@studentstay.com',
        password: 'secretPass123',
        role: 'student',
      );
      expect(registeredUser, isTrue);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.isStudent, isTrue);
      expect(authService.isOwner, isFalse);
      expect(authService.token, equals('student_jwt_token_999'));

      // 2. Search & filter properties
      final searchResult = await apiService.fetchPropertiesPaged(
        query: 'College',
        city: 'Pune',
        sortBy: 'rent_low_to_high',
      );
      expect(searchResult.total, equals(1));
      expect(searchResult.items.first.title, equals('FC Road Student Stay'));
      expect(searchResult.items.first.primaryImageUrl, equals('https://example.com/img1.jpg'));

      // 3. View property detail
      final detail = await apiService.fetchPropertyDetail(501);
      expect(detail.id, equals(501));
      expect(detail.rooms.length, equals(1));
      expect(detail.startingRent, equals(6000.0));
      expect(detail.amenities.length, equals(2));
      expect(detail.hasValidCoordinates, isTrue);

      // 4. Logout
      await authService.logout();
      expect(authService.isAuthenticated, isFalse);
      expect(authService.token, isNull);
    });
  });

  group('Phase 10: Complete Owner Flow', () {
    test('Owner registration, listing creation, image upload, update, and deletion', () async {
      int createdPropertyId = 888;

      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('/auth/register') && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 201,
              'name': 'Meera Joshi',
              'email': 'meera@studentstay.com',
              'role': 'owner',
              'created_at': '2026-10-19T00:00:00Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/auth/login') && request.method == 'POST') {
          return http.Response(
            jsonEncode({'access_token': 'owner_jwt_token_777', 'token_type': 'bearer'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/auth/me') && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 201,
              'name': 'Meera Joshi',
              'email': 'meera@studentstay.com',
              'role': 'owner',
              'created_at': '2026-10-19T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/properties') && request.method == 'POST') {
          expect(request.headers['Authorization'], 'Bearer owner_jwt_token_777');
          final body = jsonDecode(request.body);
          expect(body['title'], 'Shanti Niwas Girls PG');
          expect(body['latitude'], 18.5074);
          expect(body['longitude'], 73.8077);

          return http.Response(
            jsonEncode({
              'id': createdPropertyId,
              'owner_id': 201,
              'title': body['title'],
              'description': body['description'],
              'property_type': body['property_type'],
              'address': body['address'],
              'city': body['city'],
              'latitude': body['latitude'],
              'longitude': body['longitude'],
              'security_deposit': body['security_deposit'],
              'is_verified': false,
              'is_available': true,
              'images': [],
              'created_at': '2026-10-19T00:00:00Z',
              'updated_at': '2026-10-19T00:00:00Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/properties/my') && request.method == 'GET') {
          expect(request.headers['Authorization'], 'Bearer owner_jwt_token_777');
          return http.Response(
            jsonEncode([
              {
                'id': createdPropertyId,
                'owner_id': 201,
                'title': 'Shanti Niwas Girls PG',
                'description': 'Safe and secure PG for students',
                'property_type': 'pg',
                'address': 'Paud Road, Kothrud',
                'city': 'Pune',
                'latitude': 18.5074,
                'longitude': 73.8077,
                'is_verified': false,
                'is_available': true,
                'images': [],
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/properties/$createdPropertyId/images') && request.method == 'POST') {
          expect(request.headers['Authorization'], 'Bearer owner_jwt_token_777');
          expect(request.headers['content-type'], contains('multipart/form-data'));

          return http.Response(
            jsonEncode({
              'id': 701,
              'property_id': createdPropertyId,
              'image_url': 'https://example.com/storage/prop_888_front.jpg',
              'storage_path': 'properties/888/front.jpg',
              'created_at': '2026-10-19T00:00:00Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/properties/$createdPropertyId') && request.method == 'PATCH') {
          expect(request.headers['Authorization'], 'Bearer owner_jwt_token_777');
          final body = jsonDecode(request.body);

          return http.Response(
            jsonEncode({
              'id': createdPropertyId,
              'owner_id': 201,
              'title': body['title'],
              'description': 'Updated description with AC',
              'property_type': 'pg',
              'address': 'Paud Road, Kothrud',
              'city': 'Pune',
              'latitude': 18.5074,
              'longitude': 73.8077,
              'is_verified': false,
              'is_available': true,
              'images': [],
              'created_at': '2026-10-19T00:00:00Z',
              'updated_at': '2026-10-19T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/properties/$createdPropertyId/images/701') && request.method == 'DELETE') {
          expect(request.headers['Authorization'], 'Bearer owner_jwt_token_777');
          return http.Response('', 204);
        }

        if (path.endsWith('/properties/$createdPropertyId') && request.method == 'DELETE') {
          expect(request.headers['Authorization'], 'Bearer owner_jwt_token_777');
          return http.Response('', 204);
        }

        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(baseUrl: 'http://test-server:8000', client: mockClient);
      final authService = AuthService(apiService: apiService);

      // 1. Owner Login
      final loggedIn = await authService.login(email: 'meera@studentstay.com', password: 'password123');
      expect(loggedIn, isTrue);
      expect(authService.isOwner, isTrue);

      // 2. Create listing
      final createdProp = await apiService.createProperty(
        propertyData: {
          'title': 'Shanti Niwas Girls PG',
          'description': 'Safe and secure PG for students',
          'property_type': 'pg',
          'address': 'Paud Road, Kothrud',
          'city': 'Pune',
          'latitude': 18.5074,
          'longitude': 73.8077,
          'security_deposit': 8000.0,
        },
        token: authService.token!,
      );
      expect(createdProp.id, equals(888));
      expect(createdProp.isVerified, isFalse);

      // 3. View owner listings
      final myList = await apiService.fetchMyProperties(token: authService.token!);
      expect(myList.length, equals(1));
      expect(myList.first.title, equals('Shanti Niwas Girls PG'));

      // 4. Upload photo
      final uploadedImage = await apiService.uploadPropertyImage(
        propertyId: createdProp.id,
        fileBytes: Uint8List.fromList([137, 80, 78, 71]), // mock PNG header bytes
        filename: 'front.png',
        token: authService.token!,
      );
      expect(uploadedImage.id, equals(701));
      expect(uploadedImage.imageUrl, contains('prop_888_front.jpg'));

      // 5. Update listing
      final updatedProp = await apiService.updateProperty(
        propertyId: createdProp.id,
        propertyData: {'title': 'Shanti Niwas Girls PG (Updated)'},
        token: authService.token!,
      );
      expect(updatedProp.title, equals('Shanti Niwas Girls PG (Updated)'));

      // 6. Delete image
      await apiService.deletePropertyImage(
        propertyId: createdProp.id,
        imageId: 701,
        token: authService.token!,
      );

      // 7. Delete listing
      await apiService.deleteProperty(
        propertyId: createdProp.id,
        token: authService.token!,
      );
    });
  });

  group('Phase 10: Authorization & Error Resilience', () {
    test('Student attempting owner operation throws authorization error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Operation not permitted'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(baseUrl: 'http://test-server:8000', client: mockClient);

      expect(
        () => apiService.createProperty(
          propertyData: {'title': 'Test'},
          token: 'student_token',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'error message',
          contains('Operation not permitted'),
        )),
      );
    });

    test('Network failure or invalid JSON does not crash app', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final apiService = ApiService(baseUrl: 'http://test-server:8000', client: mockClient);
      final authService = AuthService(apiService: apiService);

      final ok = await authService.login(email: 'fail@test.com', password: 'fail');
      expect(ok, isFalse);
      expect(authService.isAuthenticated, isFalse);
      expect(authService.authError, contains('Invalid email or password'));
    });
  });
}
