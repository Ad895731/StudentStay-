import 'package:flutter/material.dart';
import '../models/inquiry.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class OwnerInquiriesScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthService authService;

  const OwnerInquiriesScreen({
    super.key,
    required this.apiService,
    required this.authService,
  });

  @override
  State<OwnerInquiriesScreen> createState() => _OwnerInquiriesScreenState();
}

class _OwnerInquiriesScreenState extends State<OwnerInquiriesScreen> {
  List<InquiryItem> _inquiries = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInquiries();
  }

  Future<void> _loadInquiries() async {
    final token = widget.authService.token;
    if (token == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.apiService.fetchMyReceivedInquiries(token: token);
      if (mounted) {
        setState(() {
          _inquiries = list;
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

  Future<void> _updateStatus(InquiryItem inq, String newStatus) async {
    final token = widget.authService.token;
    if (token == null) return;

    try {
      final updated = await widget.apiService.updateInquiryStatus(
        inquiryId: inq.id,
        status: newStatus,
        token: token,
      );
      if (mounted) {
        setState(() {
          final index = _inquiries.indexWhere((i) => i.id == inq.id);
          if (index != -1) {
            _inquiries[index] = updated;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'confirmed'
                  ? 'Visit confirmed! Student phone number is now visible.'
                  : 'Inquiry marked as $newStatus.',
            ),
            backgroundColor: newStatus == 'confirmed' ? Colors.green : Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Inquiries & Visits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInquiries,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadInquiries, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    if (_inquiries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No visit requests yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'When students request a visit for your stays, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInquiries,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _inquiries.length,
        itemBuilder: (context, index) {
          final inq = _inquiries[index];
          final isPending = inq.status == 'pending';
          final isConfirmed = inq.status == 'confirmed';
          final visitStr = '${inq.visitDate.day}/${inq.visitDate.month}/${inq.visitDate.year}';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          inq.property.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConfirmed
                              ? Colors.green.shade50
                              : isPending
                                  ? Colors.orange.shade50
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isConfirmed
                                ? Colors.green
                                : isPending
                                    ? Colors.orange
                                    : Colors.grey,
                          ),
                        ),
                        child: Text(
                          inq.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isConfirmed
                                ? Colors.green.shade800
                                : isPending
                                    ? Colors.orange.shade800
                                    : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(inq.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      const Icon(Icons.event, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text('Visit: $visitStr', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Phone number row with Privacy Badge
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text(
                        'Phone: ${inq.contactPhone}',
                        style: TextStyle(
                          fontWeight: isConfirmed ? FontWeight.bold : FontWeight.normal,
                          color: isConfirmed ? Colors.teal.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Masked for Privacy',
                            style: TextStyle(fontSize: 9, color: Colors.black54),
                          ),
                        ),
                    ],
                  ),

                  if (inq.message != null && inq.message!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '"${inq.message}"',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                      ),
                    ),
                  ],

                  if (isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _updateStatus(inq, 'rejected'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Decline'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _updateStatus(inq, 'confirmed'),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Confirm Visit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

