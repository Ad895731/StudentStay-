import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studentstay_app/screens/location_picker_screen.dart';

void main() {
  group('LocationPickerScreen Search Tests', () {
    testWidgets('Renders search field and allows searching for locality', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'Kothrud') {
          final mockResults = [
            {
              'place_id': 12345,
              'lat': '18.5074',
              'lon': '73.8077',
              'display_name': 'Kothrud, Pune, Maharashtra, India',
            }
          ];
          return http.Response(jsonEncode(mockResults), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('[]', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LocationPickerScreen(
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify search field exists
      final searchFieldFinder = find.byKey(const Key('location_search_field'));
      expect(searchFieldFinder, findsOneWidget);

      // Type "Kothrud"
      await tester.enterText(searchFieldFinder, 'Kothrud');
      await tester.pumpAndSettle();

      // Tap search button
      final searchBtn = find.byKey(const Key('location_search_submit_button'));
      expect(searchBtn, findsOneWidget);
      await tester.tap(searchBtn);
      await tester.pumpAndSettle();

      // Result should be visible
      expect(find.text('Kothrud, Pune, Maharashtra, India'), findsOneWidget);

      // Tap the result to select it
      await tester.tap(find.text('Kothrud, Pune, Maharashtra, India'));
      await tester.pumpAndSettle();

      // Coordinates should be updated in the bottom card
      expect(find.textContaining('Lat: 18.50740, Lon: 73.80770'), findsOneWidget);
    });

    testWidgets('Shows error badge when no locations are found', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LocationPickerScreen(
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchFieldFinder = find.byKey(const Key('location_search_field'));
      await tester.enterText(searchFieldFinder, 'NonExistentPlaceXYZ');
      await tester.tap(find.byKey(const Key('location_search_submit_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('No locations found'), findsOneWidget);
    });
  });
}
