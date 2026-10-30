import 'package:flutter/material.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'property_detail_screen.dart';

class SavedStaysScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthService authService;

  const SavedStaysScreen({
    super.key,
    required this.apiService,
    required this.authService,
  });

  @override
  State<SavedStaysScreen> createState() => _SavedStaysScreenState();
}

class _SavedStaysScreenState extends State<SavedStaysScreen> {
  List<Property> _favorites = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final token = widget.authService.token;
    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please log in to view your saved stays.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.apiService.fetchMyFavorites(token: token);
      if (mounted) {
        setState(() {
          _favorites = list;
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

  Future<void> _removeFavorite(Property property) async {
    final token = widget.authService.token;
    if (token == null) return;

    try {
      await widget.apiService.toggleFavorite(
        propertyId: property.id,
        token: token,
      );
      if (mounted) {
        setState(() {
          _favorites.removeWhere((p) => p.id == property.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${property.title} removed from saved stays'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Stays'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFavorites,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_favorites.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFavorites,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No saved stays yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart icon on any stay to bookmark it here!',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final prop = _favorites[index];
          final minRent = prop.startingRent;
          final imageUrl = prop.images.isNotEmpty ? prop.images.first.imageUrl : null;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
               Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => PropertyDetailScreen(
      property: prop,
      apiService: widget.apiService,
      ownerToken: widget.authService.token,
    ),
  ),
).then((_) => _loadFavorites());
              },
              child: Row(
                children: [
                  // Thumbnail
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.blue.shade50,
                            child: Icon(Icons.home, size: 40, color: Colors.blue.shade300),
                          ),
                  ),
                  // Details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prop.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${prop.propertyType.toUpperCase()} • ${prop.city}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            minRent != null ? 'Starting ₹${minRent.toInt()}/mo' : 'Contact for rent',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Remove heart icon
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    tooltip: 'Remove from Saved',
                    onPressed: () => _removeFavorite(prop),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}