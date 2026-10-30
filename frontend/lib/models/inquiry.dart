import 'property.dart';

class InquiryItem {
  final int id;
  final int propertyId;
  final int studentId;
  final int ownerId;
  final DateTime visitDate;
  final String sharingPreference;
  final String contactPhone;
  final String? message;
  final String status; // 'pending', 'confirmed', 'rejected', 'completed'
  final DateTime createdAt;
  final Property property;
  final String studentName;
  final String studentEmail;

  InquiryItem({
    required this.id,
    required this.propertyId,
    required this.studentId,
    required this.ownerId,
    required this.visitDate,
    required this.sharingPreference,
    required this.contactPhone,
    this.message,
    required this.status,
    required this.createdAt,
    required this.property,
    required this.studentName,
    required this.studentEmail,
  });

  factory InquiryItem.fromJson(Map<String, dynamic> json) {
    final studentMap = json['student'] as Map<String, dynamic>? ?? {};
    final propertyMap = json['property'] as Map<String, dynamic>? ?? {};

    return InquiryItem(
      id: json['id'] as int,
      propertyId: json['property_id'] as int,
      studentId: json['student_id'] as int,
      ownerId: json['owner_id'] as int,
      visitDate: DateTime.parse(json['visit_date'] as String),
      sharingPreference: json['sharing_preference'] as String? ?? 'any',
      contactPhone: json['contact_phone'] as String? ?? '',
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      property: Property.fromJson(propertyMap),
      studentName: studentMap['name'] as String? ?? 'Student',
      studentEmail: studentMap['email'] as String? ?? '',
    );
  }
}
