import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/property.dart';
import '../models/review.dart';
import '../services/api_service.dart';
import '../services/directions_service.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Property property;
  final String? userToken;
  final String? ownerToken;
  final ApiService? apiService;

  String? get authToken => userToken ?? ownerToken;

  const PropertyDetailScreen({
    super.key,
    required this.property,
    this.userToken,
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

  // Reviews & Eligibility state
  RatingSummary _ratingSummary = RatingSummary(averageRating: 0.0, totalReviews: 0);
  List<ReviewItem> _reviews = [];
  bool _isLoadingReviews = false;
  bool _canReview = false;
  String _canReviewReason = '';

  String? get authToken => widget.authToken;

  @override
  void initState() {
    super.initState();
    _property = widget.property;
    _apiService = widget.apiService ?? ApiService();
    if (_property.rooms.isEmpty && _property.amenities.isEmpty) {
      _fetchFullDetails();
    }
    _checkFavoriteStatus();
    _loadReviewsAndRatings();
  }

  Future<void> _loadReviewsAndRatings() async {
    setState(() => _isLoadingReviews = true);
    try {
      final summary = await _apiService.fetchRatingSummary(_property.id);
      final list = await _apiService.fetchPropertyReviews(_property.id);
      bool canRev = false;
      String reason = '';
      if (authToken != null) {
        try {
          final res = await _apiService.checkCanReview(
            propertyId: _property.id,
            token: authToken!,
          );
          canRev = res['can_review'] == true;
          reason = res['reason']?.toString() ?? '';
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _ratingSummary = summary;
          _reviews = list;
          _canReview = canRev;
          _canReviewReason = reason;
          _isLoadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final token = authToken;
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
    final token = authToken;
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

  void _openScheduleVisitDialog() {
    final token = authToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to schedule a visit or send an inquiry.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String sharingPref = 'any';
    final phoneController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Schedule a Stay Visit',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose when you want to visit and explore this property in person.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // Privacy Notice
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Privacy Guaranteed: Your phone number is masked until the owner confirms your visit schedule.',
                            style: TextStyle(fontSize: 11, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preferred Visit Date Picker
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available, color: Colors.blue),
                    title: const Text('Visit Date', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: const Text('Change Date'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sharing Preference
                  DropdownButtonFormField<String>(
                    initialValue: sharingPref,
                    decoration: const InputDecoration(
                      labelText: 'Sharing Preference',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'any', child: Text('Any Sharing Available')),
                      DropdownMenuItem(value: 'single', child: Text('Single Room')),
                      DropdownMenuItem(value: 'double', child: Text('Double Sharing')),
                      DropdownMenuItem(value: 'triple', child: Text('Triple Sharing')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => sharingPref = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Contact Phone Input
                  TextFormField(
                    key: const Key('inquiry_phone_input'),
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number *',
                      hintText: 'e.g. +91 9876543210',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 8) ? 'Enter a valid phone number' : null,
                  ),
                  const SizedBox(height: 14),

                  // Optional Message
                  TextFormField(
                    key: const Key('inquiry_message_input'),
                    controller: messageController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Message for Owner (Optional)',
                      hintText: 'e.g. Coming with my parents around 11 AM...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit CTA
                  ElevatedButton(
                    key: const Key('submit_inquiry_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => isSubmitting = true);

                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(ctx);

                            try {
                              await _apiService.createInquiry(
                                inquiryData: {
                                  'property_id': _property.id,
                                  'visit_date': selectedDate.toIso8601String(),
                                  'sharing_preference': sharingPref,
                                  'contact_phone': phoneController.text.trim(),
                                  if (messageController.text.trim().isNotEmpty)
                                    'message': messageController.text.trim(),
                                },
                                token: token,
                              );
                              if (mounted) {
                                nav.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Visit request sent to the owner successfully!'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Send Visit Request',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openWriteReviewDialog() {
    final token = authToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in as a student to write a review.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!_canReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _canReviewReason.isNotEmpty
                ? _canReviewReason
                : 'Anti-Fake Review Protection: Only verified students who have booked or completed a visit to this stay can post a review.',
          ),
          backgroundColor: Colors.orange.shade900,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    int selectedRating = 5;
    final commentController = TextEditingController();
    final reviewFormKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setReviewState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: reviewFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Rate & Review this Stay',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your honest review helps other college students find the best stays.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // Star Rating Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        iconSize: 36,
                        icon: Icon(
                          starValue <= selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () => setReviewState(() => selectedRating = starValue),
                      );
                    }),
                  ),
                  Center(
                    child: Text(
                      '$selectedRating of 5 Stars',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Review Comment Input
                  TextFormField(
                    key: const Key('review_comment_input'),
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Your Experience & Review *',
                      hintText: 'e.g. Clean rooms, supportive owner, Wi-Fi speed is good...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 3) ? 'Review must be at least 3 characters' : null,
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    key: const Key('submit_review_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (!reviewFormKey.currentState!.validate()) return;
                            setReviewState(() => isSubmitting = true);
                            final nav = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(context);

                            try {
                              await _apiService.submitReview(
                                propertyId: _property.id,
                                rating: selectedRating,
                                comment: commentController.text.trim(),
                                token: token,
                              );
                              if (mounted) {
                                nav.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Thank you! Your review has been published.'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                                _loadReviewsAndRatings();
                              }
                            } catch (e) {
                              setReviewState(() => isSubmitting = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Post Review',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 24),
                const SizedBox(width: 6),
                Text(
                  _ratingSummary.averageRating > 0
                      ? '${_ratingSummary.averageRating} (${_ratingSummary.totalReviews} reviews)'
                      : 'No reviews yet',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton.icon(
              key: const Key('write_review_button'),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Write Review'),
              onPressed: _openWriteReviewDialog,
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (!_canReview && authToken != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 18, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verified Residents Only: Only students with a confirmed visit or booking can leave a review.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        if (_isLoadingReviews)
          const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()))
        else if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'Be the first student to review this stay!',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )
        else
          Column(
            children: _reviews.map((rev) {
              final dateStr = '${rev.createdAt.day}/${rev.createdAt.month}/${rev.createdAt.year}';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            rev.studentName.isNotEmpty ? rev.studentName[0].toUpperCase() : 'S',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rev.studentName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(
                            rev.rating,
                            (_) => const Icon(Icons.star, color: Colors.amber, size: 14),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rev.comment,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.3),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
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

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Student Reviews & Ratings Section
                  _buildReviewsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: ElevatedButton.icon(
            key: const Key('schedule_visit_button'),
            icon: const Icon(Icons.calendar_today, size: 20),
            label: const Text(
              'Schedule a Visit / Inquire',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _openScheduleVisitDialog,
          ),
        ),
      ),
    );
  }
}
