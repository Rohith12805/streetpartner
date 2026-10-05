import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/area_safety_model.dart';
import '../services/area_safety_service.dart';
import 'package:streetpartner/l10n/app_localizations.dart';
import 'package:timeago/timeago.dart' as timeago;

class SafetyReviewsSheet extends StatelessWidget {
  final String cellId;
  final String locationName;

  const SafetyReviewsSheet({
    super.key,
    required this.cellId,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 24),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context)?.areaReviews ?? 'Area Reviews',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onBackground,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (locationName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                locationName,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.onSurfaceMid,
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          
          Expanded(
            child: StreamBuilder<List<AreaSafetyReview>>(
              stream: AreaSafetyService().streamReviews(cellId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final reviews = snapshot.data ?? [];
                
                if (reviews.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.rate_review_outlined, size: 64, color: AppTheme.divider),
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context)?.noReviewsYet ?? 'No reviews yet',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppTheme.onSurfaceMid,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: reviews.length,
                  separatorBuilder: (context, index) => const Divider(height: 32),
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return _buildReviewItem(review);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(AreaSafetyReview review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppTheme.onSurfaceMid),
                const SizedBox(width: 6),
                Text(
                  review.userId.substring(0, 5) + '...', // Masked user ID
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.onBackground,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.star_rounded, color: Colors.orange.shade400, size: 18),
                const SizedBox(width: 4),
                Text(
                  review.rating.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onBackground,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (review.issues.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: review.issues.map((issue) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.sosRedContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  issue,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.sosRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        if (review.experienceText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            review.experienceText,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceMid,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          review.timestamp != null ? timeago.format(review.timestamp!) : 'Just now',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
