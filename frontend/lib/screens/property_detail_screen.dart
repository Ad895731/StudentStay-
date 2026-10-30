import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../services/directions_service.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Property property;
  final String? ownerToken;
  final ApiService? apiService;

  const PropertyDetailScreen({
    super.key,
    required this.property,
    this.ownerToken,
    this.apiService,
  });

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  late Property _property;
  late final ApiService _apiService;
  int _currentImageIndex = 0;
  bool _isDeletingImage = false;
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;

  @override
  void initState() {
    super.initState();
    _property = widget.property;
    _apiService = widget.apiService ?? ApiService();
    if (_property.rooms.isEmpty && _property.amenities.isEmpty) {
      _fetchFullDetails();
    }
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final token = widget.ownerToken;
    if (token == null) return;
    try {
      final isFav = await _apiService.checkIsFavorite(
        propertyId: _property.id,
        token: token,
      );
      if (mounted) {
        setState(() => _isFavorite = isFav);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final token = widget.ownerToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save this stay to your favorites.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoadingFavorite = true);
    try {
      final newStatus = await _apiService.toggleFavorite(
        propertyId: _property.id,
        token: token,
      );
      if (mounted) {
        setState(() {
          _isFavorite = newStatus;
          _isLoadingFavorite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Saved to favorites!'
                  : 'Removed from favorites',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFavorite = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchFullDetails() async {
    try {
      final full = await _apiService.fetchPropertyDetail(_property.id);
      if (mounted) {
        setState(() {
          _property = full;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleGetDirections() async {
    if (!_property.hasValidCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coordinates are not available for this property.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await DirectionsService.launchDirections(
      _property.latitude!,
      _property.longitude!,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open map directions. Please check your browser or maps app.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteImage(PropertyImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this property photo? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_image_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeletingImage = true;
    });

    try {
      await _apiService.deletePropertyImage(
        propertyId: _property.id,
        imageId: image.id,
        token: widget.ownerToken ?? 'dummy_test_token',
      );

      if (mounted) {
        setState(() {
          final updatedImages = List<PropertyImage>.from(_property.images)
            ..removeWhere((i) => i.id == image.id);
          _property = _property.copyWith(images: updatedImages);
          if (_currentImageIndex >= _property.images.length && _property.images.isNotEmpty) {
            _currentImageIndex = _property.images.length - 1;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingImage = false;
        });
      }
    }
  }

  Widget _buildImageGallery() {
    final images = _property.images;

    if (images.isEmpty) {
      return Container(
        height: 220,
        color: Colors.grey.shade100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'No images uploaded yet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          PageView.builder(
            key: const Key('property_image_carousel'),
            itemCount: images.length,
            onPageChanged: (idx) {
              setState(() {
                _currentImageIndex = idx;
              });
            },
            itemBuilder: (context, index) {
              final img = images[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    img.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 6),
                              Text(
                                'Unable to load image',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Delete button for property owners
                  if (widget.ownerToken != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          key: Key('delete_image_btn_${img.id}'),
                          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                          tooltip: 'Delete image',
                          onPressed: _isDeletingImage ? null : () => _confirmDeleteImage(img),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Carousel slide counter badge
          if (images.length > 1)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentImageIndex + 1} / ${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_isDeletingImage)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = _property.hasValidCoordinates;
    final propertyLocation = hasCoords
        ? LatLng(_property.latitude!, _property.longitude!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_property.title),
        actions: [
          IconButton(
            key: const Key('favorite_toggle_button'),
            icon: _isLoadingFavorite
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : null,
                  ),
            tooltip: _isFavorite ? 'Remove from Saved' : 'Save to Favorites',
            onPressed: _isLoadingFavorite ? null : _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Property Image Carousel Gallery
            _buildImageGallery(),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(_property.propertyType.toUpperCase()),
                        backgroundColor: Colors.blue.shade50,
                      ),
                      const SizedBox(width: 8),
                      if (_property.isVerified)
                        const Chip(
                          avatar: Icon(Icons.verified, color: Colors.green, size: 18),
                          label: Text('Verified'),
                          backgroundColor: Color(0xFFE8F5E9),
                        ),
                      const Spacer(),
                      if (_property.distanceKm != null)
                        Text(
                          '${_property.distanceKm!.toStringAsFixed(1)} km away',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _property.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${_property.address}, ${_property.city}',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (hasCoords) ...[
                    const SizedBox(height: 4),
                    Text(
                      'GPS: ${_property.latitude!.toStringAsFixed(5)}, ${_property.longitude!.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  const Divider(height: 28),

                  // Rent & Deposit Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_property.startingRent != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Starting from',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              '₹${_property.startingRent!.toStringAsFixed(0)} / mo',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      if (_property.securityDeposit != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Security Deposit',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              '₹${_property.securityDeposit!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Get Directions Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      key: const Key('get_directions_button'),
                      onPressed: hasCoords ? _handleGetDirections : null,
                      icon: const Icon(Icons.directions),
                      label: const Text(
                        'Get Directions in Google Maps',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  if (_property.description != null && _property.description!.isNotEmpty) ...[
                    const Text(
                      'About Property',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _property.description!,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Availability Status Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _property.isAvailable ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _property.isAvailable ? Colors.green.shade300 : Colors.red.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _property.isAvailable ? Icons.check_circle : Icons.cancel_outlined,
                          color: _property.isAvailable ? Colors.green.shade700 : Colors.red.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _property.isAvailable
                              ? 'Currently Available for Students'
                              : 'Currently Fully Occupied / Unavailable',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _property.isAvailable ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Rooms and Sharing Details
                  if (_property.rooms.isNotEmpty) ...[
                    const Text(
                      'Rooms & Sharing Options',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ..._property.rooms.map((room) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade50,
                              child: Icon(Icons.bed, color: Colors.blue.shade700, size: 20),
                            ),
                            title: Text(
                              '${room.sharingType.toUpperCase()} SHARING',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text('${room.availableBeds} beds available'),
                            trailing: Text(
                              '₹${room.monthlyRent.toStringAsFixed(0)}/mo',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Amenities Chips
                  if (_property.amenities.isNotEmpty) ...[
                    const Text(
                      'Amenities & Features',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _property.amenities
                          .map((a) => Chip(
                                avatar: const Icon(Icons.check_circle_outline, color: Colors.teal, size: 16),
                                label: Text(a.name),
                                backgroundColor: const Color(0xFFE0F2F1),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Mini Map section if coordinates are available
                  if (hasCoords && propertyLocation != null) ...[
                    const Text(
                      'Location on Map',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 200,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: propertyLocation,
                            initialZoom: 15.0,
                            minZoom: 4.5,
                            maxZoom: 18.5,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.studentstay.app',
                            ),
                            const RichAttributionWidget(
                              attributions: [
                                TextSourceAttribution(
                                  '© OpenStreetMap contributors',
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: propertyLocation,
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.topCenter,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 42,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
