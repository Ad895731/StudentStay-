import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import 'location_picker_screen.dart';

class PropertyFormScreen extends StatefulWidget {
  final Property? propertyToEdit;
  final String ownerToken;
  final ApiService? apiService;
  final ImagePicker? imagePicker;

  const PropertyFormScreen({
    super.key,
    this.propertyToEdit,
    this.ownerToken = 'dummy_test_token',
    this.apiService,
    this.imagePicker,
  });

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiService _apiService;
  late final ImagePicker _imagePicker;

  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _depositController;

  String _propertyType = 'pg';
  double? _latitude;
  double? _longitude;
  bool _isSaving = false;
  String _savingStatus = '';

  // Selected images waiting for explicit confirmation and upload
  final List<XFile> _selectedImages = [];
  final Map<String, Uint8List> _imageBytesCache = {};

  final List<String> _propertyTypes = ['pg', 'hostel', 'flat', 'room'];
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _imagePicker = widget.imagePicker ?? ImagePicker();

    final p = widget.propertyToEdit;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _addressController = TextEditingController(text: p?.address ?? '');
    _cityController = TextEditingController(text: p?.city ?? '');
    _depositController = TextEditingController(
      text: p?.securityDeposit != null ? p!.securityDeposit!.toStringAsFixed(0) : '',
    );

    if (p != null) {
      _propertyType = p.propertyType;
      _latitude = p.latitude;
      _longitude = p.longitude;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  /// Pick multiple images from gallery and enforce format and 5 MB limit.
  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      final List<String> rejected = [];
      final List<XFile> valid = [];

      for (final file in pickedFiles) {
        final ext = file.name.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
          rejected.add('${file.name}: unsupported format (must be JPEG, PNG, or WebP)');
          continue;
        }

        final length = await file.length();
        if (length > maxFileSizeBytes) {
          final mb = (length / (1024 * 1024)).toStringAsFixed(1);
          rejected.add('${file.name}: exceeds 5 MB limit ($mb MB)');
          continue;
        }

        final bytes = await file.readAsBytes();
        _imageBytesCache[file.path] = bytes;
        valid.add(file);
      }

      setState(() {
        _selectedImages.addAll(valid);
      });

      if (rejected.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Skipped ${rejected.length} file(s):\n${rejected.join('\n')}',
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeSelectedImage(int index) {
    setState(() {
      final removed = _selectedImages.removeAt(index);
      _imageBytesCache.remove(removed.path);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the exact property location on the map.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _savingStatus = 'Saving property details...';
    });

    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
      'property_type': _propertyType,
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
      if (_depositController.text.isNotEmpty)
        'security_deposit': double.tryParse(_depositController.text.trim()),
    };

    try {
      Property savedProperty;
      if (widget.propertyToEdit == null) {
        savedProperty = await _apiService.createProperty(
          propertyData: payload,
          token: widget.ownerToken,
        );
      } else {
        savedProperty = await _apiService.updateProperty(
          propertyId: widget.propertyToEdit!.id,
          propertyData: payload,
          token: widget.ownerToken,
        );
      }

      // Upload selected images if any
      final uploadedImages = <PropertyImage>[...savedProperty.images];
      final failedUploads = <String>[];

      if (_selectedImages.isNotEmpty) {
        for (int i = 0; i < _selectedImages.length; i++) {
          final file = _selectedImages[i];
          if (mounted) {
            setState(() {
              _savingStatus = 'Uploading photo ${i + 1} of ${_selectedImages.length}...';
            });
          }

          try {
            final bytes = _imageBytesCache[file.path] ?? await file.readAsBytes();
            final uploaded = await _apiService.uploadPropertyImage(
              propertyId: savedProperty.id,
              fileBytes: bytes,
              filename: file.name,
              token: widget.ownerToken,
            );
            uploadedImages.add(uploaded);
          } catch (e) {
            failedUploads.add('${file.name}: $e');
          }
        }
      }

      savedProperty = savedProperty.copyWith(images: uploadedImages);

      if (mounted) {
        if (failedUploads.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Property saved, but ${failedUploads.length} photo(s) failed to upload:\n${failedUploads.join('\n')}',
              ),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.propertyToEdit == null
                    ? 'Property and photos saved successfully!'
                    : 'Property updated successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        Navigator.of(context).pop(savedProperty);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving property: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingStatus = '';
        });
      }
    }
  }

  Widget _buildImagePickerCard() {
    return Card(
      key: const Key('image_picker_card'),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Property Photos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_selectedImages.isNotEmpty)
                  Text(
                    '${_selectedImages.length} selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Select multiple photos from gallery (JPEG, PNG, WebP up to 5 MB each).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            // Previews of selected images with remove buttons
            if (_selectedImages.isNotEmpty) ...[
              SizedBox(
                height: 110,
                child: ListView.separated(
                  key: const Key('selected_images_preview_list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final file = _selectedImages[index];
                    final bytes = _imageBytesCache[file.path];

                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: bytes != null
                              ? Image.memory(
                                  bytes,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.image, color: Colors.grey),
                                  ),
                                ),
                        ),
                        // Remove button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            key: Key('remove_selected_image_$index'),
                            onTap: () => _removeSelectedImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Photos are queued and will only upload after you confirm and save.',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            OutlinedButton.icon(
              key: const Key('pick_images_button'),
              onPressed: _isSaving ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(
                _selectedImages.isEmpty ? 'Select Photos from Gallery' : 'Add More Photos',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade300),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.propertyToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Property' : 'List New Property'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('property_title_input'),
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Property Title *',
                  hintText: 'e.g. Sunshine PG for Boys',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter a property title' : null,
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                key: const Key('property_type_select'),
                initialValue: _propertyType,
                decoration: const InputDecoration(
                  labelText: 'Property Type *',
                  border: OutlineInputBorder(),
                ),
                items: _propertyTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _propertyType = val);
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                key: const Key('property_address_input'),
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Street Address *',
                  hintText: 'e.g. 42 MG Road, Near Metro',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter the street address' : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('property_city_input'),
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        hintText: 'e.g. Pune',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Enter city' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('property_deposit_input'),
                      controller: _depositController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Security Deposit (₹)',
                        hintText: 'e.g. 5000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextFormField(
                key: const Key('property_desc_input'),
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Describe amenities, rules, nearby landmarks...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Location Selector Card
              Card(
                key: const Key('location_selector_card'),
                elevation: 2,
                color: _latitude != null ? Colors.blue.shade50 : Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: _latitude != null ? Colors.blue.shade300 : Colors.orange.shade300,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.map,
                            color: _latitude != null ? Colors.blue.shade700 : Colors.deepOrange,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Exact Property Location *',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _latitude != null && _longitude != null
                            ? 'Selected: Lat ${_latitude!.toStringAsFixed(5)}, Lon ${_longitude!.toStringAsFixed(5)}'
                            : 'No location selected. Tap below to pick on the map.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _latitude != null ? FontWeight.w600 : FontWeight.normal,
                          color: _latitude != null ? Colors.black87 : Colors.deepOrange.shade800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        key: const Key('pick_location_button'),
                        onPressed: _openLocationPicker,
                        icon: const Icon(Icons.add_location_alt),
                        label: Text(
                          _latitude != null ? 'Change Location on Map' : 'Select Location on Map',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Image Picker and Previews Card
              _buildImagePickerCard(),

              const SizedBox(height: 28),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  key: const Key('save_property_button'),
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                _savingStatus.isNotEmpty ? _savingStatus : 'Saving...',
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          isEditing ? 'Save Changes' : 'Create Property Listing',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
