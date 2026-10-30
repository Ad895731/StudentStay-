import 'package:flutter/material.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'owner_inquiries_screen.dart';
import 'property_detail_screen.dart';
import 'property_form_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final ApiService? apiService;
  final AuthService? authService;
  final VoidCallback? onNavigateToAuth;

  const OwnerDashboardScreen({
    super.key,
    this.apiService,
    this.authService,
    this.onNavigateToAuth,
  });

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  late final ApiService _apiService;
  List<Property> _properties = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadOwnerProperties();
  }

  Future<void> _loadOwnerProperties() async {
    final token = widget.authService?.token;
    if (token == null || widget.authService?.isOwner != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _apiService.fetchMyProperties(token: token);
      if (mounted) {
        setState(() {
          _properties = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteProperty(Property property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Property Listing'),
        content: Text('Are you sure you want to permanently delete "${property.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_property_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final token = widget.authService?.token ?? 'dummy_test_token';
    try {
      await _apiService.deleteProperty(
        propertyId: property.id,
        token: token,
      );

      if (mounted) {
        setState(() {
          _properties.removeWhere((p) => p.id == property.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property listing deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete property: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUnauthenticatedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_person_outlined, size: 72, color: Colors.blue.shade700),
            const SizedBox(height: 16),
            const Text(
              'Owner Sign-In Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'To list and manage student accommodations, please sign in or register with an Owner account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('owner_go_to_login_button'),
              onPressed: widget.onNavigateToAuth,
              icon: const Icon(Icons.login),
              label: const Text('Sign In or Register as Owner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentRestrictedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 72, color: Colors.teal.shade700),
            const SizedBox(height: 16),
            const Text(
              'Student Account Active',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You are currently signed in as a student. Property creation and management is reserved for accommodation owners.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Text(
              'Looking for a place to stay? Explore verified stays on the Explore tab or Map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blue.shade700, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyItem(Property property) {
    return Card(
      key: Key('owner_property_card_${property.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: property.primaryImageUrl != null
                      ? Image.network(
                          property.primaryImageUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 72,
                          height: 72,
                          color: Colors.blue.shade50,
                          child: Icon(Icons.home, color: Colors.blue.shade400, size: 36),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${property.address}, ${property.city}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Verification Status Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: property.isVerified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              property.isVerified ? 'VERIFIED' : 'PENDING REVIEW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: property.isVerified ? Colors.green.shade800 : Colors.orange.shade900,
                              ),
                            ),
                          ),
                          // Availability Status Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: property.isAvailable ? Colors.blue.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              property.isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: property.isAvailable ? Colors.blue.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PropertyDetailScreen(
                          property: property,
                          ownerToken: widget.authService?.token,
                          apiService: _apiService,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View'),
                ),
                TextButton.icon(
                  key: Key('edit_property_btn_${property.id}'),
                  onPressed: () async {
                    final updated = await Navigator.of(context).push<Property>(
                      MaterialPageRoute(
                        builder: (_) => PropertyFormScreen(
                          propertyToEdit: property,
                          ownerToken: widget.authService?.token ?? 'dummy_test_token',
                          apiService: _apiService,
                        ),
                      ),
                    );
                    if (updated != null) {
                      _loadOwnerProperties();
                    }
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
                IconButton(
                  key: Key('delete_property_btn_${property.id}'),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'Delete listing',
                  onPressed: () => _deleteProperty(property),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authService;
    if (auth != null && !auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Owner Dashboard')),
        body: _buildUnauthenticatedView(),
      );
    }

    if (auth != null && auth.isStudent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Owner Dashboard')),
        body: _buildStudentRestrictedView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Property Listings'),
        actions: [
          IconButton(
            key: const Key('owner_inquiries_button'),
            icon: const Icon(Icons.mark_email_unread_outlined),
            tooltip: 'Student Inquiries',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OwnerInquiriesScreen(
                    apiService: _apiService,
                    authService: widget.authService!,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Listings',
            onPressed: _loadOwnerProperties,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_property_fab'),
        onPressed: () async {
          final token = widget.authService?.token ?? 'dummy_test_token';
          final newProp = await Navigator.of(context).push<Property>(
            MaterialPageRoute(
              builder: (_) => PropertyFormScreen(
                ownerToken: token,
                apiService: _apiService,
              ),
            ),
          );
          if (newProp != null) {
            _loadOwnerProperties();
          }
        },
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Property'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 54, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadOwnerProperties,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _properties.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_home_work_outlined, size: 72, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No properties listed yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the button below to publish your first student accommodation listing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final token = widget.authService?.token ?? 'dummy_test_token';
                              final newProp = await Navigator.of(context).push<Property>(
                                MaterialPageRoute(
                                  builder: (_) => PropertyFormScreen(
                                    ownerToken: token,
                                    apiService: _apiService,
                                  ),
                                ),
                              );
                              if (newProp != null) {
                                _loadOwnerProperties();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('List New Property'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _properties.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Text(
                                  '${_properties.length} Active Listings',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Text(
                                  'Owner Portal',
                                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }
                        return _buildPropertyItem(_properties[index - 1]);
                      },
                    ),
    );
  }
}
