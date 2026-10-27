import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studentstay_app/models/property.dart';
import 'package:studentstay_app/screens/property_form_screen.dart';
import 'package:studentstay_app/services/api_service.dart';

void main() {
  group('PropertyFormScreen Amenities & Room Configurations Tests', () {
    testWidgets('Loads and renders amenity chips and allows selection',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/amenities/all')) {
          return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'Wi-Fi'},
              {'id': 2, 'name': 'AC'},
              {'id': 3, 'name': 'Power Backup'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiService = ApiService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyFormScreen(
            apiService: apiService,
            ownerToken: 'owner_token_123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('amenities_selector_card')), findsOneWidget);
      expect(find.text('Offered Amenities'), findsOneWidget);
      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.text('AC'), findsOneWidget);
      expect(find.text('Power Backup'), findsOneWidget);

      // Select Wi-Fi
      await tester.tap(find.byKey(const Key('amenity_chip_1')));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      // Select AC
      await tester.tap(find.byKey(const Key('amenity_chip_2')));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('Adds room configuration using the Add Room dialog',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/amenities/all')) {
          return http.Response(jsonEncode([]), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final apiService = ApiService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyFormScreen(
            apiService: apiService,
            ownerToken: 'owner_token_123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows empty state
      expect(find.byKey(const Key('rooms_config_card')), findsOneWidget);
      expect(find.textContaining('No room configurations added yet'), findsOneWidget);

      // Open Add Room Dialog
      await tester.ensureVisible(find.byKey(const Key('add_room_button')));
      await tester.tap(find.byKey(const Key('add_room_button')));
      await tester.pumpAndSettle();

      expect(find.text('Add Room Type'), findsOneWidget);

      // Fill in rent
      await tester.enterText(
          find.byKey(const Key('dialog_room_rent_input')), '8500');
      // Available beds defaults to '1'
      expect(find.byKey(const Key('dialog_room_beds_input')), findsOneWidget);

      // Confirm add
      await tester.tap(find.byKey(const Key('dialog_confirm_add_room')));
      await tester.pumpAndSettle();

      // Dialog closed and room added
      expect(find.text('Single Room'), findsOneWidget);
      expect(find.text('₹8500 / month'), findsOneWidget);
      expect(find.text('1 bed available'), findsOneWidget);
    });

    testWidgets('Submits property with amenities and room configurations',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool amenitiesUpdated = false;
      bool roomAdded = false;

      final existingDraft = Property(
        id: 101,
        ownerId: 1,
        title: 'Draft PG',
        description: 'New PG',
        propertyType: 'pg',
        address: 'MG Road 10',
        city: 'Pune',
        latitude: 18.5204,
        longitude: 73.8567,
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/amenities/all')) {
          return http.Response(
            jsonEncode([
              {'id': 10, 'name': 'Wi-Fi'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.endsWith('/properties/101') &&
            request.method == 'PATCH') {
          return http.Response(
            jsonEncode({
              'id': 101,
              'owner_id': 1,
              'title': 'Draft PG',
              'property_type': 'pg',
              'address': 'MG Road 10',
              'city': 'Pune',
              'latitude': 18.5204,
              'longitude': 73.8567,
              'is_verified': false,
              'is_available': true,
              'images': [],
              'rooms': [],
              'amenities': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/properties/101/amenities') &&
            request.method == 'PUT') {
          amenitiesUpdated = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['amenity_ids'], [10]);
          return http.Response(
            jsonEncode([
              {'id': 10, 'name': 'Wi-Fi'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/properties/101/rooms') &&
            request.method == 'POST') {
          roomAdded = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['sharing_type'], 'single');
          expect(body['monthly_rent'], 6000.0);
          expect(body['available_beds'], 1);
          return http.Response(
            jsonEncode({
              'id': 201,
              'property_id': 101,
              'sharing_type': 'single',
              'monthly_rent': 6000.0,
              'available_beds': 1,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiService = ApiService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyFormScreen(
            propertyToEdit: existingDraft,
            apiService: apiService,
            ownerToken: 'test_token',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Wi-Fi amenity
      await tester.ensureVisible(find.byKey(const Key('amenity_chip_10')));
      await tester.tap(find.byKey(const Key('amenity_chip_10')));
      await tester.pumpAndSettle();

      // Add a room
      await tester.ensureVisible(find.byKey(const Key('add_room_button')));
      await tester.tap(find.byKey(const Key('add_room_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('dialog_room_rent_input')), '6000');
      await tester.tap(find.byKey(const Key('dialog_confirm_add_room')));
      await tester.pumpAndSettle();

      // Check dialog closed
      expect(find.text('Add Room Type'), findsNothing);
      expect(find.text('Single Room'), findsOneWidget);

      // Submit the form
      await tester.ensureVisible(find.byKey(const Key('save_property_button')));
      await tester.tap(find.byKey(const Key('save_property_button')));
      await tester.pumpAndSettle();

      expect(amenitiesUpdated, isTrue);
      expect(roomAdded, isTrue);
    });

    testWidgets('Pre-fills existing property amenities and rooms when editing',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final existingProperty = Property(
        id: 99,
        ownerId: 1,
        title: 'Existing Sunrise PG',
        description: 'Prime location',
        propertyType: 'pg',
        address: '100 FC Road',
        city: 'Pune',
        latitude: 18.5204,
        longitude: 73.8567,
        amenities: [
          Amenity(id: 1, name: 'Wi-Fi'),
          Amenity(id: 2, name: 'AC'),
        ],
        rooms: [
          Room(
            id: 501,
            propertyId: 99,
            sharingType: 'single',
            monthlyRent: 9000.0,
            availableBeds: 1,
          ),
        ],
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/amenities/all')) {
          return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'Wi-Fi'},
              {'id': 2, 'name': 'AC'},
              {'id': 3, 'name': 'Power Backup'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiService = ApiService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyFormScreen(
            propertyToEdit: existingProperty,
            apiService: apiService,
            ownerToken: 'owner_token',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title & Address pre-filled
      expect(find.text('Existing Sunrise PG'), findsOneWidget);

      // Pre-filled amenities badge
      expect(find.text('2 selected'), findsOneWidget);

      // Pre-filled room
      expect(find.text('Single Room'), findsOneWidget);
      expect(find.text('₹9000 / month'), findsOneWidget);

      // Remove the pre-filled room
      await tester.tap(find.byKey(const Key('delete_room_button_0')));
      await tester.pumpAndSettle();

      expect(find.text('Single Room'), findsNothing);
      expect(find.textContaining('No room configurations added yet'), findsOneWidget);
    });
  });
}
