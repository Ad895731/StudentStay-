import 'package:flutter/material.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import 'property_detail_screen.dart';

class AdminVerificationScreen extends StatefulWidget {
  final String token;
  final ApiService? apiService;
  const AdminVerificationScreen({
    super.key,
    required this.token,
    this.apiService,
  });
  @override
  State<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  late final ApiService _apiService;
  List<Property> _pendingProperties = [];
  bool _isLoading = true;
  String? _error;
  final Set<int> _verifyingIds = {};

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _apiService.fetchPendingProperties(
        token: widget.token,
      );
      if (mounted) {
        setState(() {
          _pendingProperties = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleVerify(int propertyId) async {
    setState(() => _verifyingIds.add(propertyId));

    try {
      await _apiService.verifyProperty(
        token: widget.token,
        propertyId: propertyId,
      );
      if (mounted) {
        setState(() {
          _pendingProperties.removeWhere((p) => p.id == propertyId);

          _verifyingIds.remove(propertyId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property verified successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verifyingIds.remove(propertyId));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to verify property: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Verification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPending,
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
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadPending, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_pendingProperties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, size: 64, color: Colors.green.shade400),
            const SizedBox(height: 16),
            const Text(
              'All Caught Up!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No pending properties waiting for review.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingProperties.length,
        itemBuilder: (context, index) {
          final prop = _pendingProperties[index];
          final isVerifying = _verifyingIds.contains(prop.id);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          prop.propertyType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'ID: #${prop.id}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prop.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${prop.address}, ${prop.city}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (prop.description != null &&
                      prop.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      prop.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const Divider(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 1. View Details Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('View Details'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PropertyDetailScreen(
                                property: prop,
                                apiService: _apiService,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      // 2. Approve & Verify Button (already present)
                      ElevatedButton.icon(
                        icon: isVerifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                              ),
                        label: Text(
                          isVerifying ? 'Verifying...' : 'Approve & Verify',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                        ),
                        onPressed: isVerifying
                            ? null
                            : () => _handleVerify(prop.id),
                      ),
                    ],
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
