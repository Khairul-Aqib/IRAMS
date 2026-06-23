import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String reviewerName;
  final double rating;
  final String comment;
  final DateTime date;

  const Review({
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.date,
  });

  /// Parses a review from a Job document that contains UserRating,
  /// UserFeedback, and UserName fields written by the User App.
  factory Review.fromJobDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['DateCompleted'] ?? d['DateRequested'];
    return Review(
      reviewerName: (d['UserName'] ?? 'Anonymous').toString(),
      rating: (d['UserRating'] as num?)?.toDouble() ?? 0.0,
      comment: (d['UserFeedback'] ?? '').toString(),
      date: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}
