import 'package:flutter/material.dart';
import '../models/property.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'property_detail_screen.dart';

class ExploreStaysScreen extends StatefulWidget {
  final ApiService? apiService;
  final AuthService? authService;

  const ExploreStaysScreen({
    super.key,
    this.apiService,
    this.authService,
  });

  @override
  State<ExploreStaysScreen> createState() => _ExploreStaysScreenState();
}

class _ExploreStaysScreenState extends State<ExploreStaysScreen> {
  late final ApiService _apiService;
  final TextEditingController _searchController = TextEditingController();

  final List<Property> _properties = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _page = 1;
  static const int _pageSize = 10;
  int _total = 0;
  bool _hasMore = false;

  // Filters
  String? _selectedCity;
  String? _selectedType;
  String? _selectedSharing;
  double? _minRent;
  double? _maxRent;
  String _sortBy = 'newest';

  final List<String> _propertyTypes = ['all', 'pg', 'hostel', 'flat', 'room'];
  final List<String> _sharingTypes = ['all', 'single', 'double', 'triple'];
  final List<Map<String, String>> _sortOptions = [
    {'value': 'newest', 'label': 'Newest First'},
    {'value': 'rent_low_to_high', 'label': 'Rent: Low to High'},
    {'value': 'rent_high_to_low', 'label': 'Rent: High to Low'},
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadProperties(refresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final query = _searchController.text.trim();
      final result = await _apiService.fetchPropertiesPaged(
        query: query.isNotEmpty ? query : null,
        city: _selectedCity != null && _selectedCity!.isNotEmpty ? _selectedCity : null,
        propertyType: (_selectedType != null && _selectedType != 'all') ? _selectedType : null,
        sharingType: (_selectedSharing != null && _selectedSharing != 'all') ? _selectedSharing : null,
        minRent: _minRent,
        maxRent: _maxRent,
        sortBy: _sortBy,
        page: refresh ? 1 : _page + 1,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _properties.clear();
            _properties.addAll(result.items);
            _page = 1;
          } else {
            _properties.addAll(result.items);
            _page += 1;
          }
          _total = result.total;
          _hasMore = result.hasMore;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _openFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? tempCity = _selectedCity;
        String tempType = _selectedType ?? 'all';
        String tempSharing = _selectedSharing ?? 'all';
        String tempSort = _sortBy;
        final minController = TextEditingController(
          text: _minRent != null ? _minRent!.toStringAsFixed(0) : '',
        );
        final maxController = TextEditingController(
          text: _maxRent != null ? _maxRent!.toStringAsFixed(0) : '',
        );

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter & Sort Accommodations',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(),

                    // City Filter
                    TextFormField(
                      initialValue: tempCity,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        hintText: 'e.g. Pune, Mumbai',
                        prefixIcon: Icon(Icons.location_city),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) => tempCity = val.trim().isNotEmpty ? val.trim() : null,
                    ),
                    const SizedBox(height: 14),

                    // Property Type
                    const Text('Property Type', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _propertyTypes.map((t) {
                        final isSelected = tempType == t;
                        return ChoiceChip(
                          label: Text(t.toUpperCase()),
                          selected: isSelected,
                          onSelected: (sel) {
                            if (sel) setSheetState(() => tempType = t);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Sharing Type
                    const Text('Room Sharing', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _sharingTypes.map((s) {
                        final isSelected = tempSharing == s;
                        return ChoiceChip(
                          label: Text(s.toUpperCase()),
                          selected: isSelected,
                          onSelected: (sel) {
                            if (sel) setSheetState(() => tempSharing = s);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Rent Range
                    const Text('Monthly Rent Range (₹)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Min Rent',
                              prefixText: '₹',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max Rent',
                              prefixText: '₹',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Sort By
                    const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: tempSort,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _sortOptions
                          .map((opt) => DropdownMenuItem(
                                value: opt['value'],
                                child: Text(opt['label']!),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setSheetState(() => tempSort = val);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCity = null;
                                _selectedType = 'all';
                                _selectedSharing = 'all';
                                _minRent = null;
                                _maxRent = null;
                                _sortBy = 'newest';
                              });
                              Navigator.of(ctx).pop();
                              _loadProperties(refresh: true);
                            },
                            child: const Text('Reset All'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            key: const Key('apply_filters_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedCity = tempCity;
                                _selectedType = tempType;
                                _selectedSharing = tempSharing;
                                _sortBy = tempSort;
                                _minRent = double.tryParse(minController.text.trim());
                                _maxRent = double.tryParse(maxController.text.trim());
                              });
                              Navigator.of(ctx).pop();
                              _loadProperties(refresh: true);
                            },
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Card(
      key: Key('property_card_${property.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Thumbnail
            SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (property.primaryImageUrl != null)
                    Image.network(
                      property.primaryImageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: Colors.blue.shade50,
                      child: Center(
                        child: Icon(Icons.home_work_outlined, size: 54, color: Colors.blue.shade300),
                      ),
                    ),

                  // Property Type Badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        property.propertyType.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Verified Badge
                  if (property.isVerified)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details Content
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (property.startingRent != null)
                        Text(
                          '₹${property.startingRent!.toStringAsFixed(0)}/mo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${property.address}, ${property.city}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (property.distanceKm != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${property.distanceKm!.toStringAsFixed(1)} km away',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Student Stay'),
        actions: [
          IconButton(
            key: const Key('filter_button'),
            icon: const Icon(Icons.tune),
            tooltip: 'Filter & Sort',
            onPressed: _openFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _loadProperties(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('explore_search_bar'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadProperties(refresh: true),
              decoration: InputDecoration(
                hintText: 'Search by title, city, area...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadProperties(refresh: true);
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Total Count or Active Filter Chip
          if (_total > 0 || _selectedCity != null || _selectedType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '$_total verified accommodations found',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (_selectedType != null && _selectedType != 'all')
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Chip(
                        label: Text(_selectedType!.toUpperCase(), style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),

          // Main List View
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadProperties(refresh: true),
              child: _isLoading
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
                                  onPressed: () => _loadProperties(refresh: true),
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
                                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No accommodations found',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Try adjusting your search query or filters.',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _selectedCity = null;
                                        _selectedType = 'all';
                                        _selectedSharing = 'all';
                                        _minRent = null;
                                        _maxRent = null;
                                        _sortBy = 'newest';
                                      });
                                      _loadProperties(refresh: true);
                                    },
                                    child: const Text('Reset Search & Filters'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _properties.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index < _properties.length) {
                                  return _buildPropertyCard(_properties[index]);
                                } else {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? const CircularProgressIndicator()
                                          : ElevatedButton.icon(
                                              key: const Key('load_more_button'),
                                              onPressed: () => _loadProperties(refresh: false),
                                              icon: const Icon(Icons.expand_more),
                                              label: const Text('Load More Stays'),
                                            ),
                                    ),
                                  );
                                }
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
