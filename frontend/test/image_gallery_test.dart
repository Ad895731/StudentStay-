import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studentstay_app/models/property.dart';
import 'package:studentstay_app/screens/explore_map_screen.dart';
import 'package:studentstay_app/screens/property_detail_screen.dart';
import 'package:studentstay_app/screens/property_form_screen.dart';
import 'package:studentstay_app/services/api_service.dart';

// Mock ImagePicker for testing image selection
class FakeImagePicker implements ImagePicker {
  final List<XFile> filesToReturn;

  FakeImagePicker({this.filesToReturn = const []});

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    return filesToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase 8C: Property Image Models & ApiService', () {
    test('PropertyImage fromJson and toJson serialization', () {
      final json = {
        'id': 10,
        'property_id': 42,
        'image_url': 'https://example.com/storage/prop42_img1.jpg',
        'storage_path': 'properties/42/img1.jpg',
        'created_at': '2026-10-18T00:00:00Z',
      };

      final img = PropertyImage.fromJson(json);
      expect(img.id, equals(10));
      expect(img.propertyId, equals(42));
      expect(img.imageUrl, equals('https://example.com/storage/prop42_img1.jpg'));
      expect(img.storagePath, equals('properties/42/img1.jpg'));
      expect(img.createdAt, isNotNull);

      final outJson = img.toJson();
      expect(outJson['id'], equals(10));
      expect(outJson['property_id'], equals(42));
      expect(outJson['image_url'], equals('https://example.com/storage/prop42_img1.jpg'));
    });

    test('Property model parses images and exposes primaryImageUrl', () {
      final json = {
        'id': 1,
        'owner_id': 2,
        'title': 'Sample PG',
        'property_type': 'pg',
        'address': 'FC Road',
        'city': 'Pune',
        'images': [
          {
            'id': 101,
            'property_id': 1,
            'image_url': 'https://example.com/first.jpg',
            'storage_path': 'properties/1/first.jpg',
          },
          {
            'id': 102,
            'property_id': 1,
            'image_url': 'https://example.com/second.jpg',
            'storage_path': 'properties/1/second.jpg',
          },
        ],
      };

      final property = Property.fromJson(json);
      expect(property.images.length, equals(2));
      expect(property.primaryImageUrl, equals('https://example.com/first.jpg'));
    });

    test('ApiService.uploadPropertyImage sends multipart POST with JWT token', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/properties/42/images'));
        expect(request.headers['Authorization'], equals('Bearer test_jwt_token'));
        expect(request is http.MultipartRequest, isTrue);

        final multipart = request as http.MultipartRequest;
        expect(multipart.files.length, equals(1));
        expect(multipart.files.first.field, equals('file'));
        expect(multipart.files.first.filename, equals('bedroom.jpg'));

        final bodyStr = jsonEncode({
          'id': 55,
          'property_id': 42,
          'image_url': 'https://example.com/bedroom.jpg',
          'storage_path': 'properties/42/uuid_bedroom.jpg',
          'created_at': '2026-10-18T01:00:00Z',
        });

        return http.StreamedResponse(
          Stream.value(utf8.encode(bodyStr)),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(baseUrl: 'http://localhost:8000', client: mockClient);
      final result = await apiService.uploadPropertyImage(
        propertyId: 42,
        fileBytes: [1, 2, 3, 4],
        filename: 'bedroom.jpg',
        contentType: 'image/jpeg',
        token: 'test_jwt_token',
      );

      expect(result.id, equals(55));
      expect(result.propertyId, equals(42));
      expect(result.imageUrl, equals('https://example.com/bedroom.jpg'));
    });

    test('ApiService.deletePropertyImage sends DELETE with JWT token', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('DELETE'));
        expect(request.url.path, equals('/properties/42/images/55'));
        expect(request.headers['Authorization'], equals('Bearer test_jwt_token'));
        return http.Response('', 204);
      });

      final apiService = ApiService(baseUrl: 'http://localhost:8000', client: mockClient);
      await apiService.deletePropertyImage(
        propertyId: 42,
        imageId: 55,
        token: 'test_jwt_token',
      );
      // No exception means 204 success
    });
  });

  group('Phase 8C: PropertyDetailScreen Gallery & Management', () {
    testWidgets('Displays empty state when property has no images', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final propertyNoImages = Property(
        id: 1,
        ownerId: 2,
        title: 'PG Without Images',
        propertyType: 'pg',
        address: '10 Senapati Bapat Road',
        city: 'Pune',
        images: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyDetailScreen(property: propertyNoImages),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No images uploaded yet'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    });

    testWidgets('Displays image carousel and allows owner to delete image with confirmation',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool deleteEndpointCalled = false;
      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE' && request.url.path == '/properties/1/images/201') {
          deleteEndpointCalled = true;
          return http.Response('', 204);
        }
        return http.Response('Not Found', 404);
      });

      final propertyWithImages = Property(
        id: 1,
        ownerId: 2,
        title: 'PG With Images',
        propertyType: 'pg',
        address: '10 Senapati Bapat Road',
        city: 'Pune',
        images: [
          PropertyImage(
            id: 201,
            propertyId: 1,
            imageUrl: 'https://example.com/img1.jpg',
          ),
          PropertyImage(
            id: 202,
            propertyId: 1,
            imageUrl: 'https://example.com/img2.jpg',
          ),
        ],
      );

      final apiService = ApiService(baseUrl: 'http://localhost:8000', client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyDetailScreen(
            property: propertyWithImages,
            ownerToken: 'owner_secret_token',
            apiService: apiService,
          ),
        ),
      );
      await tester.pump();

      // Carousel is rendered
      expect(find.byKey(const Key('property_image_carousel')), findsOneWidget);
      // Carousel counter badge indicates 1 / 2
      expect(find.text('1 / 2'), findsOneWidget);

      // Owner delete button is visible for the current slide
      final deleteBtn = find.byKey(const Key('delete_image_btn_201'));
      expect(deleteBtn, findsOneWidget);

      // Tap delete button -> Confirmation dialog appears
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Delete Image'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byKey(const Key('confirm_delete_image_button')), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.byKey(const Key('confirm_delete_image_button')));
      await tester.pumpAndSettle();

      expect(deleteEndpointCalled, isTrue);
      expect(find.text('Image deleted successfully.'), findsOneWidget);
    });
  });

  group('Phase 8C: PropertyFormScreen Image Selection & 5 MB Limit', () {
    testWidgets('Shows photo selection card, picks images, and allows removing before upload',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final validPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      final fakeImages = [
        XFile.fromData(
          validPngBytes,
          name: 'room_valid.jpg',
          path: '/tmp/room_valid.jpg',
        ),
        XFile.fromData(
          validPngBytes,
          name: 'living_valid.png',
          path: '/tmp/living_valid.png',
        ),
      ];

      final fakePicker = FakeImagePicker(filesToReturn: fakeImages);

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyFormScreen(
            imagePicker: fakePicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify photo section exists
      expect(find.byKey(const Key('image_picker_card')), findsOneWidget);
      expect(find.byKey(const Key('pick_images_button')), findsOneWidget);
      expect(find.text('Select Photos from Gallery'), findsOneWidget);

      // Tap to pick images
      await tester.ensureVisible(find.byKey(const Key('pick_images_button')));
      await tester.tap(find.byKey(const Key('pick_images_button')));
      await tester.pumpAndSettle();

      // Selected images preview is displayed
      expect(find.byKey(const Key('selected_images_preview_list')), findsOneWidget);
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.byKey(const Key('remove_selected_image_0')), findsOneWidget);

      // Remove the first image before saving
      await tester.tap(find.byKey(const Key('remove_selected_image_0')));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('Rejects files exceeding 5 MB limit', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 6 MB oversized file
      final oversizedBytes = Uint8List(6 * 1024 * 1024);
      final oversizedFile = XFile.fromData(
        oversizedBytes,
        name: 'huge_photo.jpg',
        path: '/tmp/huge_photo.jpg',
      );

      final fakePicker = FakeImagePicker(filesToReturn: [oversizedFile]);

      await tester.pumpWidget(
        MaterialApp(
          home: PropertyFormScreen(
            imagePicker: fakePicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('pick_images_button')));
      await tester.tap(find.byKey(const Key('pick_images_button')));
      await tester.pumpAndSettle();

      // File was rejected and not added to selected list
      expect(find.byKey(const Key('selected_images_preview_list')), findsNothing);
      expect(find.textContaining('exceeds 5 MB limit'), findsOneWidget);
    });
  });

  group('Phase 8C: ExploreMapScreen Thumbnail Integration', () {
    testWidgets('Displays thumbnail image in property marker preview card',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final propertyWithImage = Property(
        id: 77,
        ownerId: 3,
        title: 'Skyview PG with Photos',
        propertyType: 'pg',
        address: '45 Law College Road',
        city: 'Pune',
        latitude: 18.5144,
        longitude: 73.8322,
        isVerified: true,
        isAvailable: true,
        images: [
          PropertyImage(
            id: 301,
            propertyId: 77,
            imageUrl: 'https://example.com/thumbnail.jpg',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExploreMapScreen(
            initialProperties: [propertyWithImage],
          ),
        ),
      );
      await tester.pump();

      // Marker preview card contains the thumbnail
      expect(find.byKey(const Key('property_preview_card')), findsOneWidget);
      expect(find.byKey(const Key('map_preview_thumbnail')), findsOneWidget);
      expect(find.text('Skyview PG with Photos'), findsOneWidget);
    });
  });
}
