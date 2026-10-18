class Room {
  final int id;
  final int propertyId;
  final String sharingType;
  final double monthlyRent;
  final int availableBeds;

  Room({
    required this.id,
    required this.propertyId,
    required this.sharingType,
    required this.monthlyRent,
    required this.availableBeds,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as int,
      propertyId: json['property_id'] as int,
      sharingType: json['sharing_type'] as String? ?? 'single',
      monthlyRent: (json['monthly_rent'] is num)
          ? (json['monthly_rent'] as num).toDouble()
          : double.tryParse(json['monthly_rent']?.toString() ?? '0') ?? 0.0,
      availableBeds: json['available_beds'] as int? ?? 1,
    );
  }
}

class Amenity {
  final int id;
  final String name;

  Amenity({
    required this.id,
    required this.name,
  });

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class PropertyImage {
  final int id;
  final int propertyId;
  final String imageUrl;
  final String storagePath;
  final DateTime? createdAt;

  PropertyImage({
    required this.id,
    required this.propertyId,
    required this.imageUrl,
    this.storagePath = '',
    this.createdAt,
  });

  factory PropertyImage.fromJson(Map<String, dynamic> json) {
    return PropertyImage(
      id: json['id'] as int,
      propertyId: json['property_id'] as int,
      imageUrl: json['image_url'] as String? ?? '',
      storagePath: json['storage_path'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'property_id': propertyId,
      'image_url': imageUrl,
      'storage_path': storagePath,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

class Property {
  final int id;
  final int ownerId;
  final String title;
  final String? description;
  final String propertyType;
  final String address;
  final String city;
  final double? latitude;
  final double? longitude;
  final double? securityDeposit;
  final bool isVerified;
  final bool isAvailable;
  final double? distanceKm;
  final List<Room> rooms;
  final List<Amenity> amenities;
  final List<PropertyImage> images;

  Property({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.propertyType,
    required this.address,
    required this.city,
    this.latitude,
    this.longitude,
    this.securityDeposit,
    this.isVerified = false,
    this.isAvailable = true,
    this.distanceKm,
    this.rooms = const [],
    this.amenities = const [],
    this.images = const [],
  });

  bool get hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude! >= -90.0 &&
      latitude! <= 90.0 &&
      longitude! >= -180.0 &&
      longitude! <= 180.0;

  String? get primaryImageUrl => images.isNotEmpty ? images.first.imageUrl : null;

  double? get startingRent {
    if (rooms.isEmpty) return null;
    double minRent = rooms.first.monthlyRent;
    for (final room in rooms) {
      if (room.monthlyRent < minRent) {
        minRent = room.monthlyRent;
      }
    }
    return minRent;
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    var rawRooms = json['rooms'];
    List<Room> roomList = [];
    if (rawRooms is List) {
      roomList = rawRooms
          .map((r) => Room.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    var rawAmenities = json['amenities'];
    List<Amenity> amenityList = [];
    if (rawAmenities is List) {
      amenityList = rawAmenities
          .map((a) => Amenity.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    var rawImages = json['images'];
    List<PropertyImage> imageList = [];
    if (rawImages is List) {
      imageList = rawImages
          .map((img) => PropertyImage.fromJson(img as Map<String, dynamic>))
          .toList();
    }

    return Property(
      id: json['id'] as int,
      ownerId: json['owner_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      propertyType: json['property_type'] as String? ?? 'pg',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : (json['latitude'] != null
              ? double.tryParse(json['latitude'].toString())
              : null),
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : (json['longitude'] != null
              ? double.tryParse(json['longitude'].toString())
              : null),
      securityDeposit: (json['security_deposit'] is num)
          ? (json['security_deposit'] as num).toDouble()
          : (json['security_deposit'] != null
              ? double.tryParse(json['security_deposit'].toString())
              : null),
      isVerified: json['is_verified'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      distanceKm: (json['distance_km'] is num)
          ? (json['distance_km'] as num).toDouble()
          : (json['distance_km'] != null
              ? double.tryParse(json['distance_km'].toString())
              : null),
      rooms: roomList,
      amenities: amenityList,
      images: imageList,
    );
  }

  Property copyWith({
    int? id,
    int? ownerId,
    String? title,
    String? description,
    String? propertyType,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    double? securityDeposit,
    bool? isVerified,
    bool? isAvailable,
    double? distanceKm,
    List<Room>? rooms,
    List<Amenity>? amenities,
    List<PropertyImage>? images,
  }) {
    return Property(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      propertyType: propertyType ?? this.propertyType,
      address: address ?? this.address,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      isVerified: isVerified ?? this.isVerified,
      isAvailable: isAvailable ?? this.isAvailable,
      distanceKm: distanceKm ?? this.distanceKm,
      rooms: rooms ?? this.rooms,
      amenities: amenities ?? this.amenities,
      images: images ?? this.images,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (description != null) 'description': description,
      'property_type': propertyType,
      'address': address,
      'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (securityDeposit != null) 'security_deposit': securityDeposit,
    };
  }
}

class PropertyListResult {
  final List<Property> items;
  final int page;
  final int pageSize;
  final int total;

  PropertyListResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  bool get hasMore => (page * pageSize) < total;
}
