import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:studentstay_app/models/property.dart';
import 'package:studentstay_app/screens/explore_map_screen.dart';
import 'package:studentstay_app/screens/location_picker_screen.dart';
import 'package:studentstay_app/screens/property_detail_screen.dart';
import 'package:studentstay_app/screens/property_form_screen.dart';
import 'package:studentstay_app/services/directions_service.dart';

void main() {
  group('Phase 7: Maps, Location & Directions Tests', () {
    test('DirectionsService builds correct Google Maps destination URL', () {
      final url = DirectionsService.buildDirectionsUrl(18.5204, 73.8567);
      expect(
        url,
        equals('https://www.google.com/maps/dir/?api=1&destination=18.5204,73.8567'),
      );
    });

    testWidgets('Owner can select and change map marker on LocationPickerScreen',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      LatLng? confirmedLocation;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                confirmedLocation = await Navigator.of(context).push<LatLng>(
                  MaterialPageRoute(
                    builder: (_) => const LocationPickerScreen(),
                  ),
                );
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      );

      // Open picker
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Initially no location selected
      expect(find.text('No location selected yet'), findsOneWidget);

      // 1. First tap on the map to place marker
      final mapFinder = find.byType(LocationPickerScreen);
      expect(mapFinder, findsOneWidget);

      await tester.tapAt(const Offset(400, 400));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify coordinate text is now displayed
      expect(find.textContaining('Lat:'), findsOneWidget);
      expect(find.textContaining('Lon:'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);

      // 2. Second tap at a different location to change marker
      await tester.tapAt(const Offset(450, 450));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.location_on), findsOneWidget);

      // 3. Confirm selection
      await tester.tap(find.byKey(const Key('confirm_location_button')));
      await tester.pumpAndSettle();

      // Returned location must not be null
      expect(confirmedLocation, isNotNull);
    });

    testWidgets('Saved coordinates appear when editing a property',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final existingProperty = Property(
        id: 42,
        ownerId: 5,
        title: 'Existing Pune Stay',
        description: 'Near Symbiosis Campus',
        propertyType: 'pg',
        address: '15 Viman Nagar',
        city: 'Pune',
        latitude: 18.5678,
        longitude: 73.9143,
        securityDeposit: 5000,
        isVerified: true,
        isAvailable: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyFormScreen(
            propertyToEdit: existingProperty,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify form is populated with existing property data
      expect(find.text('Existing Pune Stay'), findsOneWidget);
      expect(find.text('15 Viman Nagar'), findsOneWidget);
      expect(find.text('Pune'), findsOneWidget);

      // Verify previously saved coordinates appear clearly in the location card
      expect(find.textContaining('Lat 18.56780, Lon 73.91430'), findsOneWidget);
      expect(find.text('Change Location on Map'), findsOneWidget);
    });

    testWidgets('Property markers open the correct preview on ExploreMapScreen',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testProperties = [
        Property(
          id: 101,
          ownerId: 1,
          title: 'Orchid PG Stay',
          propertyType: 'pg',
          address: '12 MG Road',
          city: 'Pune',
          latitude: 18.5204,
          longitude: 73.8567,
          isVerified: true,
          isAvailable: true,
          rooms: [
            Room(
              id: 1,
              propertyId: 101,
              sharingType: 'single',
              monthlyRent: 8000,
              availableBeds: 1,
            ),
          ],
        ),
        Property(
          id: 102,
          ownerId: 1,
          title: 'Silver Oaks Hostel',
          propertyType: 'hostel',
          address: '45 FC Road',
          city: 'Pune',
          latitude: 18.5300,
          longitude: 73.8400,
          isVerified: true,
          isAvailable: true,
          rooms: [
            Room(
              id: 2,
              propertyId: 102,
              sharingType: 'double',
              monthlyRent: 6000,
              availableBeds: 2,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ExploreMapScreen(
            initialProperties: testProperties,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify markers are rendered
      expect(find.byKey(const Key('property_marker_101')), findsOneWidget);
      expect(find.byKey(const Key('property_marker_102')), findsOneWidget);

      // Initially first property is selected
      expect(find.text('Orchid PG Stay'), findsOneWidget);
      expect(find.text('₹8000/mo'), findsOneWidget);
      expect(find.text('12 MG Road, Pune'), findsOneWidget);

      // Tap second marker
      await tester.tap(find.byKey(const Key('property_marker_102')));
      await tester.pumpAndSettle();

      // Verify preview card updates to second property details
      expect(find.text('Silver Oaks Hostel'), findsOneWidget);
      expect(find.text('₹6000/mo'), findsOneWidget);
      expect(find.text('45 FC Road, Pune'), findsOneWidget);
      expect(find.byKey(const Key('view_details_button')), findsOneWidget);
    });

    testWidgets('PropertyDetailScreen displays Get Directions button',
        (WidgetTester tester) async {
      final prop = Property(
        id: 201,
        ownerId: 1,
        title: 'Green View PG',
        propertyType: 'pg',
        address: '5 Senapati Bapat Road',
        city: 'Pune',
        latitude: 18.5314,
        longitude: 73.8288,
        isVerified: true,
        isAvailable: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyDetailScreen(property: prop),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Get Directions button is present
      final getDirectionsFinder = find.byKey(const Key('get_directions_button'));
      expect(getDirectionsFinder, findsOneWidget);

      // Verify attribution is displayed on mini map
      expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
    });
  });
}
