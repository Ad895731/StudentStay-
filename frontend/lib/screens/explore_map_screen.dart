import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import 'property_detail_screen.dart';

class ExploreMapScreen extends StatefulWidget {
  final ApiService? apiService;
  final List<Property>? initialProperties;

  const ExploreMapScreen({
    super.key,
    this.apiService,
    this.initialProperties,
  });

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  late final ApiService _apiService;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedPropertyType = 'all';


  List<Property> _properties = [];
  Property? _selectedProperty;
  bool _isLoading = false;
  String? _errorMessage;

  static const LatLng _defaultCenter = LatLng(18.5204, 73.8567); // Pune center

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    if (widget.initialProperties != null) {
      _properties = widget.initialProperties!
          .where((p) => p.isVerified && p.isAvailable && p.hasValidCoordinates)
          .toList();
      if (_properties.isNotEmpty) {
        _selectedProperty = _properties.first;
      }
    } else {
      _loadProperties();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  
  Future<void> _loadProperties({String? query, String? propertyType}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final typeFilter = (propertyType ?? _selectedPropertyType) == 'all'
          ? null
          : (propertyType ?? _selectedPropertyType);

      final properties = await _apiService.fetchProperties(
        query: query ?? _searchController.text.trim(),
        propertyType: typeFilter,
        pageSize: 50,
      );

      if (mounted) {
        setState(() {
          _properties = properties
              .where((p) => p.isVerified && p.isAvailable && p.hasValidCoordinates)
              .toList();

          if (_properties.isNotEmpty) {
            _selectedProperty = _properties.first;
            // Search result aane par map camera ko pehli matching stay par move kiya
            _mapController.move(
              LatLng(_properties.first.latitude!, _properties.first.longitude!),
              13.0,
            );
          } else {
            _selectedProperty = null;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onMarkerTapped(Property property) {
    setState(() {
      _selectedProperty = property;
    });
    if (property.hasValidCoordinates) {
      _mapController.move(
        LatLng(property.latitude!, property.longitude!),
        _mapController.camera.zoom,
      );
    }
  }

  void _openPropertyDetails(Property property) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PropertyDetailScreen(property: property),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = (_selectedProperty != null && _selectedProperty!.hasValidCoordinates)
        ? LatLng(_selectedProperty!.latitude!, _selectedProperty!.longitude!)
        : (_properties.isNotEmpty && _properties.first.hasValidCoordinates
            ? LatLng(_properties.first.latitude!, _properties.first.longitude!)
            : _defaultCenter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Accommodations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Properties',
            onPressed: _loadProperties,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Base OpenStreetMap Layer & Interactive Markers
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13.0,
              minZoom: 4.5,
              maxZoom: 18.5,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(-85.0511, -180.0),
                  const LatLng(85.0511, 180.0),
                ),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.studentstay.app',
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
              MarkerLayer(
                markers: _properties
                    .where((prop) =>
                        prop.latitude != null &&
                        prop.longitude != null &&
                        prop.latitude! >= -85.0 &&
                        prop.latitude! <= 85.0 &&
                        prop.longitude! >= -180.0 &&
                        prop.longitude! <= 180.0)
                    .map((prop) {
                  final isSelected = _selectedProperty?.id == prop.id;
                  return Marker(
                    key: Key('property_marker_${prop.id}'),
                    point: LatLng(prop.latitude!, prop.longitude!),
                    width: isSelected ? 48 : 38,
                    height: isSelected ? 48 : 38,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _onMarkerTapped(prop),
                      child: Icon(
                        Icons.location_on,
                        color: isSelected ? Colors.red.shade700 : Colors.blue.shade700,
                        size: isSelected ? 48 : 38,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Map ke upar floating search bar aur category filter chips render kiya hai
          _buildFloatingSearchBar(),

          // Search request chalte waqt loading indicator show kiya hai
          if (_isLoading)
            Positioned(
              top: 110,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Searching stays on map...'),
                    ],
                  ),
                ),
              ),
            ),

          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Recenter / Location Button
          Positioned(
            right: 16,
            bottom: _selectedProperty != null ? 175 : 20,
            child: FloatingActionButton.small(
              key: const Key('recenter_map_button'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              tooltip: 'Center on Stays',
              onPressed: () {
                final target = (_selectedProperty != null && _selectedProperty!.hasValidCoordinates)
                    ? LatLng(_selectedProperty!.latitude!, _selectedProperty!.longitude!)
                    : (_properties.isNotEmpty && _properties.first.hasValidCoordinates
                        ? LatLng(_properties.first.latitude!, _properties.first.longitude!)
                        : _defaultCenter);
                _mapController.move(target, 13.0);
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // Property Preview Card
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: _selectedProperty != null
                ? Card(
                    key: const Key('property_preview_card'),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Optional thumbnail if property images are available
                              if (_selectedProperty!.primaryImageUrl != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _selectedProperty!.primaryImageUrl!,
                                    key: const Key('map_preview_thumbnail'),
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        width: 64,
                                        height: 64,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 64,
                                      height: 64,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _selectedProperty!.propertyType.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (_selectedProperty!.startingRent != null)
                                          Text(
                                            '₹${_selectedProperty!.startingRent!.toStringAsFixed(0)}/mo',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _selectedProperty!.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${_selectedProperty!.address}, ${_selectedProperty!.city}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              key: const Key('view_details_button'),
                              onPressed: () => _openPropertyDetails(_selectedProperty!),
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('View Property Details'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Showing ${_properties.length} verified stays on the map. Tap any marker to view details.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

    Widget _buildFloatingSearchBar() {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // 1. Search TextField Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (val) => _loadProperties(),
              decoration: InputDecoration(
                hintText: 'Search city, area, stay name...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _loadProperties();
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Colors.blue),
                        onPressed: () => _loadProperties(),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'pg', 'hostel', 'flat', 'room'].map((type) {
                final isSelected = _selectedPropertyType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(type.toUpperCase()),
                    selected: isSelected,
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue.shade800,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue.shade900 : Colors.black87,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedPropertyType = type;
                      });
                      _loadProperties(propertyType: type);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

}
