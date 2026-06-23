import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../models/review.dart';
import '../../../services/firestore_service.dart';
import '../../widgets/app_loader.dart';

class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: const Text(
          'My Reviews',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<Review>>(
        stream: FirestoreService.instance.watchContractorReviews(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoader();
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load reviews.\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            );
          }

          final reviews = snap.data ?? [];

          if (reviews.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_outline, size: 64, color: Colors.white24),
                    SizedBox(height: 16),
                    Text(
                      'No reviews yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Reviews from customers will appear here\nafter you complete jobs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _ReviewCard(review: reviews[index]),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.reviewerName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(review.date.toLocal()),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < review.rating ? Icons.star : Icons.star_border,
                color: kYellow,
                size: 16,
              );
            }),
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}
