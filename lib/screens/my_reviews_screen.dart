import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/area_safety_model.dart';
import '../services/area_safety_service.dart';
import 'package:streetpartner/l10n/app_localizations.dart';
import 'package:timeago/timeago.dart' as timeago;

class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)?.myReviews ?? 'My Reviews')),
        body: Center(child: Text(AppLocalizations.of(context)?.notAuthenticated ?? 'Not authenticated')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xCCF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppLocalizations.of(context)?.mySafetyReviews ?? 'My Safety Reviews',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.onBackground,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('reviews')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('failed-precondition')) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)?.databaseIndexRequired ?? 'Database Index Required',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(AppLocalizations.of(context)?.toViewAllYourReviewsAcrossDiff ?? 'To view all your reviews across different areas, a Firestore index needs to be created. Check your console logs for the direct creation link.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: AppTheme.onSurfaceMid),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rate_review_outlined, size: 64, color: AppTheme.divider),
                  const SizedBox(height: 16),
                  Text(
                    'You haven\'t written any reviews yet.',
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
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 32),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final review = AreaSafetyReview.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              
              // Get cell ID from the parent reference: area_safety_cells/cellId/reviews/reviewId
              final cellId = doc.reference.parent.parent?.id ?? 'Unknown Area';

              return _buildReviewItem(context, review, cellId);
            },
          );
        },
      ),
    );
  }

  Widget _buildReviewItem(BuildContext context, AreaSafetyReview review, String cellId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(
                  cellId.replaceFirst('cell_', '').replaceAll('_', ', '),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              review.timestamp != null
                  ? timeago.format(review.timestamp!)
                  : 'Just now',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            TextButton.icon(
              onPressed: () => _deleteReview(context, cellId, review.id),
              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.sosRed),
              label: Text(AppLocalizations.of(context)?.delete ?? 'Delete',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.sosRed),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _deleteReview(BuildContext context, String cellId, String reviewId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.deleteReview ?? 'Delete Review?'),
        content: Text(AppLocalizations.of(context)?.areYouSureYouWantToDeleteThisS ?? 'Are you sure you want to delete this safety review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)?.cancel1 ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AreaSafetyService().deleteReview(cellId, reviewId).then((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)?.reviewDeletedSuccessfully ?? 'Review deleted successfully.')),
                  );
                }
              }).catchError((e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: ${e}')),
                  );
                }
              });
            },
            child: Text(AppLocalizations.of(context)?.delete ?? 'Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
