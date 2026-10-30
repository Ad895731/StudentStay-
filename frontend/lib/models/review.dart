class ReviewItem {
  final int id;
  final int propertyId;
  final int studentId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String studentName;

  ReviewItem({
    required this.id,
    required this.propertyId,
    required this.studentId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.studentName,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    final studentMap = json['student'] as Map<String, dynamic>? ?? {};
    return ReviewItem(
      id: json['id'] as int,
      propertyId: json['property_id'] as int,
      studentId: json['student_id'] as int,
      rating: json['rating'] as int? ?? 5,
      comment: json['comment'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      studentName: studentMap['name'] as String? ?? 'Verified Student',
    );
  }
}

class RatingSummary {
  final double averageRating;
  final int totalReviews;

  RatingSummary({
    required this.averageRating,
    required this.totalReviews,
  });

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    return RatingSummary(
      averageRating: (json['average_rating'] is num)
          ? (json['average_rating'] as num).toDouble()
          : 0.0,
      totalReviews: json['total_reviews'] as int? ?? 0,
    );
  }
}
