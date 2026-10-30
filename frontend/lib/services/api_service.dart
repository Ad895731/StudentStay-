import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/property.dart';
import '../models/user.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client;

  /// Resolves the appropriate API base URL across platforms:
  /// - `API_BASE_URL` from --dart-define if supplied (e.g. physical device LAN IP or local testing)
  /// - Default production fallback: Render cloud backend
  static String resolveBaseUrl([String? explicitUrl]) {
    String url;
    if (explicitUrl != null && explicitUrl.isNotEmpty) {
      url = explicitUrl;
    } else {
      const fromEnv = String.fromEnvironment('API_BASE_URL');
      if (fromEnv.isNotEmpty) {
        url = fromEnv;
      } else {
        // Deployed Production Backend
        // yaha maine delpoy kara hai render pr usee lga dia ab agr mujhe local me chalna hoga to mai
        // --dart-define=API_BASE_URL=http://127.0.0.1:8000` use krega local machine pr chalane ke liye
        url = 'https://studentstay-8kkr.onrender.com';
      }
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Extracts user-friendly error messages from FastAPI responses (handling both string details and validation error lists).
  static String extractErrorMessage(
    http.Response response, {
    String fallback = 'An error occurred',
  }) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        final detail = body['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
          return detail.join(', ');
        }
        return detail.toString();
      }
    } catch (_) {}
    return fallback;
  }

  ApiService({String? baseUrl, http.Client? client})
    : baseUrl = resolveBaseUrl(baseUrl),
      _client = client ?? http.Client();

  /// Authenticates user and returns JWT access token.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['access_token'] as String;
    } else {
      throw Exception(
        extractErrorMessage(response, fallback: 'Invalid email or password'),
      );
    }
  }

  /// Registers a new user account (student or owner).
  Future<User> register({
    required String name,
    required String email,
    required String password,
    String role = 'student',
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return User.fromJson(data);
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Registration failed (${response.statusCode})',
        ),
      );
    }
  }

  /// Gets the currently authenticated user's profile.
  Future<User> getMe({required String token}) async {
    final uri = Uri.parse('$baseUrl/auth/me');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return User.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    } else {
      throw Exception('Failed to get user profile: ${response.statusCode}');
    }
  }

  /// Fetches public verified and available properties with pagination metadata.
  Future<PropertyListResult> fetchPropertiesPaged({
    String? query,
    String? city,
    String? propertyType,
    String? sharingType,
    double? minRent,
    double? maxRent,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? sortBy,
    int page = 1,
    int pageSize = 10,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    if (query != null && query.isNotEmpty) params['q'] = query;
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (propertyType != null && propertyType.isNotEmpty) {
      params['property_type'] = propertyType;
    }
    if (sharingType != null && sharingType.isNotEmpty) {
      params['sharing_type'] = sharingType;
    }
    if (minRent != null) params['min_rent'] = minRent.toString();
    if (maxRent != null) params['max_rent'] = maxRent.toString();
    if (latitude != null) params['latitude'] = latitude.toString();
    if (longitude != null) params['longitude'] = longitude.toString();
    if (radiusKm != null) params['radius_km'] = radiusKm.toString();
    if (sortBy != null) params['sort_by'] = sortBy;

    final uri = Uri.parse(
      '$baseUrl/properties',
    ).replace(queryParameters: params);
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawItems = data['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .map((e) => Property.fromJson(e as Map<String, dynamic>))
          .toList();
      return PropertyListResult(
        items: items,
        page: data['page'] as int? ?? page,
        pageSize: data['page_size'] as int? ?? pageSize,
        total: data['total'] as int? ?? items.length,
      );
    } else {
      throw Exception(
        'Failed to load properties: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Fetches public verified and available properties with optional search, filters, coordinates, and radius.
  Future<List<Property>> fetchProperties({
    String? query,
    String? city,
    String? propertyType,
    double? minRent,
    double? maxRent,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? sortBy,
    int page = 1,
    int pageSize = 50,
  }) async {
    final result = await fetchPropertiesPaged(
      query: query,
      city: city,
      propertyType: propertyType,
      minRent: minRent,
      maxRent: maxRent,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      sortBy: sortBy,
      page: page,
      pageSize: pageSize,
    );
    return result.items;
  }

  /// Fetches properties belonging to the current owner.
  Future<List<Property>> fetchMyProperties({required String token}) async {
    final uri = Uri.parse('$baseUrl/properties/my');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => Property.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Not authorized to access owner dashboard.');
    } else {
      throw Exception(
        'Failed to load owner properties: ${response.statusCode}',
      );
    }
  }

  /// Deletes a property listing. Requires owner/admin token.
  Future<void> deleteProperty({
    required int propertyId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/properties/$propertyId');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 204) {
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Not authorized to delete this property.');
    } else {
      throw Exception('Failed to delete property: ${response.statusCode}');
    }
  }

  /// Fetches details for a single verified and available property.
  Future<Property> fetchPropertyDetail(int propertyId) async {
    final uri = Uri.parse('$baseUrl/properties/$propertyId');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Property.fromJson(data);
    } else {
      throw Exception(
        'Failed to load property details: ${response.statusCode}',
      );
    }
  }

  /// Creates a new property. Requires owner token and coordinates.
  Future<Property> createProperty({
    required Map<String, dynamic> propertyData,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/properties');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(propertyData),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Property.fromJson(data);
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to create property (${response.statusCode})',
        ),
      );
    }
  }

  /// Updates an existing property. Requires owner/admin token.
  Future<Property> updateProperty({
    required int propertyId,
    required Map<String, dynamic> propertyData,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/properties/$propertyId');
    final response = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(propertyData),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Property.fromJson(data);
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to update property (${response.statusCode})',
        ),
      );
    }
  }

  /// Uploads an image to the given property using multipart/form-data.
  Future<PropertyImage> uploadPropertyImage({
    required int propertyId,
    required List<int> fileBytes,
    required String filename,
    String? contentType,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/properties/$propertyId/images');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    MediaType? mediaType;
    if (contentType != null && contentType.isNotEmpty) {
      try {
        mediaType = MediaType.parse(contentType);
      } catch (_) {
        mediaType = MediaType('image', 'jpeg');
      }
    } else {
      final ext = filename.split('.').last.toLowerCase();
      if (ext == 'png') {
        mediaType = MediaType('image', 'png');
      } else if (ext == 'webp') {
        mediaType = MediaType('image', 'webp');
      } else {
        mediaType = MediaType('image', 'jpeg');
      }
    }

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: filename,
      contentType: mediaType,
    );
    request.files.add(multipartFile);

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PropertyImage.fromJson(data);
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Authentication failed or not authorized to upload images.',
      );
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to upload image (${response.statusCode})',
        ),
      );
    }
  }

  /// Deletes an image belonging to a property.
  Future<void> deletePropertyImage({
    required int propertyId,
    required int imageId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/properties/$propertyId/images/$imageId');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 204) {
      return;
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Authentication failed or not authorized to delete this image.',
      );
    } else if (response.statusCode == 404) {
      throw Exception('Image or property not found.');
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to delete image (${response.statusCode})',
        ),
      );
    }
  }

  // admin related api calls like get pending property , verify property
  Future<List<Property>> fetchPendingProperties({required String token}) async {
    final uri = Uri.parse('$baseUrl/admin/properties/pending');
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['pending_properties'] as List;
      return list
          .map((e) => Property.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback:
              'Failed to load pending properties (${response.statusCode})',
        ),
      );
    }
  }

  Future<bool> verifyProperty({
    required int propertyId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/properties/$propertyId/verify');
    final response = await _client.patch(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to verify property (${response.statusCode})',
        ),
      );
    }
  }
  // Sabhi system amenities (Wi-Fi, AC, Food, etc.) fetch karne ka method
  Future<List<Amenity>> fetchAmenities() async {
    final uri = Uri.parse('$baseUrl/properties/amenities/all');
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Amenity.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to fetch amenities (${response.statusCode})',
        ),
      );
    }
  }

  // Owner property me room configuration add karega (Single, Double, Rent, Beds)
  Future<Room> addRoom({
    required int propertyId,
    required Map<String, dynamic> roomData,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/properties/$propertyId/rooms');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(roomData),
    );
    if (response.statusCode == 201) {
      return Room.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to add room (${response.statusCode})',
        ),
      );
    }
  }

  // Owner property se kisi room configuration ko delete kar sakega
  Future<void> deleteRoom({
    required int propertyId,
    required int roomId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/properties/$propertyId/rooms/$roomId');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 204) {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to delete room (${response.statusCode})',
        ),
      );
    }
  }

  // Selected amenity IDs ko property ke sath link/sync karega
  Future<List<Amenity>> updatePropertyAmenities({
    required int propertyId,
    required List<int> amenityIds,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/properties/$propertyId/amenities');
    final response = await _client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amenity_ids': amenityIds}),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Amenity.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to update amenities (${response.statusCode})',
        ),
      );
    }
  }

  // 1. Property ko favorite / unfavorite toggle karne ke liye
  Future<bool> toggleFavorite({
    required int propertyId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/favorites/$propertyId/toggle');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['is_favorite'] as bool? ?? false;
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to update favorite (${response.statusCode})',
        ),
      );
    }
  }

  // 2. Logged-in student ki saari saved properties fetch karne ke liye
  Future<List<Property>> fetchMyFavorites({required String token}) async {
    final uri = Uri.parse('$baseUrl/favorites/my');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) {
        final propJson = item['property'] as Map<String, dynamic>;
        return Property.fromJson(propJson);
      }).toList();
    } else {
      throw Exception(
        extractErrorMessage(
          response,
          fallback: 'Failed to fetch favorites (${response.statusCode})',
        ),
      );
    }
  }

  // 3. Check karne ke liye ki kya ye property logged-in user ne save ki hui hai
  Future<bool> checkIsFavorite({
    required int propertyId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/favorites/check/$propertyId');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['is_favorite'] as bool? ?? false;
    }
    return false;
  }

}
