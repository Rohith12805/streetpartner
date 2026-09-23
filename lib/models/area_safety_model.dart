import 'package:cloud_firestore/cloud_firestore.dart';

class AreaSafetyCell {
  final String cellId;
  final double centerLat;
  final double centerLng;
  final int totalRatings;
  final double ratingSum;
  final double averageRating;
  final Map<String, int> issueCounts;
  final DateTime? lastUpdated;

  AreaSafetyCell({
    required this.cellId,
    required this.centerLat,
    required this.centerLng,
    required this.totalRatings,
    required this.ratingSum,
    required this.averageRating,
    required this.issueCounts,
    this.lastUpdated,
  });

  factory AreaSafetyCell.fromMap(Map<String, dynamic> map, String documentId) {
    return AreaSafetyCell(
      cellId: documentId,
      centerLat: (map['centerLat'] as num?)?.toDouble() ?? 0.0,
      centerLng: (map['centerLng'] as num?)?.toDouble() ?? 0.0,
      totalRatings: map['totalRatings'] as int? ?? 0,
      ratingSum: (map['ratingSum'] as num?)?.toDouble() ?? 0.0,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      issueCounts: Map<String, int>.from(map['issueCounts'] ?? {}),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'centerLat': centerLat,
      'centerLng': centerLng,
      'totalRatings': totalRatings,
      'ratingSum': ratingSum,
      'averageRating': averageRating,
      'issueCounts': issueCounts,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}

class AreaSafetyReview {
  final String id;
  final double rating;
  final List<String> issues;
  final String experienceText;
  final String userId;
  final DateTime? timestamp;

  AreaSafetyReview({
    required this.id,
    required this.rating,
    required this.issues,
    required this.experienceText,
    required this.userId,
    this.timestamp,
  });

  factory AreaSafetyReview.fromMap(Map<String, dynamic> map, String documentId) {
    return AreaSafetyReview(
      id: documentId,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      issues: List<String>.from(map['issues'] ?? []),
      experienceText: map['experienceText'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rating': rating,
      'issues': issues,
      'experienceText': experienceText,
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
