import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;

  // Default coordinate if no prior coordinate (Pune center)
  static const LatLng _defaultCenter = LatLng(18.5204, 73.8567);

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    }
  }

  void _onMapTapped(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
    });
  }

  void _confirmSelection() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap on the map to select a property location.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(_selectedLocation);
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedLocation ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Property Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Confirm Location',
            onPressed: _confirmSelection,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.0,
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
              onTap: _onMapTapped,
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
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white.withValues(alpha: 0.92),
              elevation: 4,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap anywhere on the map to set or move the property marker.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedLocation != null
                                ? 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(5)}, Lon: ${_selectedLocation!.longitude.toStringAsFixed(5)}'
                                : 'No location selected yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedLocation != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      key: const Key('confirm_location_button'),
                      onPressed: _confirmSelection,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Confirm Location'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
