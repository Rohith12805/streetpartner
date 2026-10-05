import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/area_safety_service.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

class SafetyRatingSheet extends StatefulWidget {
  final LatLng location;
  final String locationName;

  const SafetyRatingSheet({
    super.key,
    required this.location,
    required this.locationName,
  });

  @override
  State<SafetyRatingSheet> createState() => _SafetyRatingSheetState();
}

class _SafetyRatingSheetState extends State<SafetyRatingSheet> {
  final _areaSafetyService = AreaSafetyService();
  double _rating = 0;
  final Set<String> _selectedIssues = {};
  final _experienceController = TextEditingController();
  bool _isSubmitting = false;

  final Map<String, IconData> _issueOptions = {
    'Poor lighting': Icons.lightbulb_outline,
    'Theft / pickpocketing': Icons.money_off,
    'Harassment': Icons.front_hand,
    'Isolated area': Icons.nature,
    'Suspicious activity': Icons.visibility_off,
    'Unsafe traffic': Icons.traffic,
    'Alcohol disturbance': Icons.local_bar,
    'Stray animals': Icons.pets,
    'Poorly maintained': Icons.broken_image,
    'Lack of security': Icons.security,
  };

  @override
  void dispose() {
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.pleaseSelectAStarRating ?? 'Please select a star rating.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _areaSafetyService.submitReview(
        location: widget.location,
        rating: _rating,
        issues: _selectedIssues.toList(),
        experienceText: _experienceController.text.trim(),
      );

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)?.success ?? 'Success'),
            content: Text(AppLocalizations.of(context)?.safetyRatingSubmittedSuccessfu ?? 'Safety rating submitted successfully!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context)?.ok ?? 'OK'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: AppTheme.sosRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context)?.rateAreaSafety ?? 'Rate Area Safety',
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
            if (widget.locationName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.locationName,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.onSurfaceMid,
                ),
              ),
            ],
            const SizedBox(height: 24),
            
            // Star Rating
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return IconButton(
                    iconSize: 40,
                    color: index < _rating ? const Color(0xFFFFA000) : AppTheme.divider,
                    icon: Icon(index < _rating ? Icons.star_rounded : Icons.star_outline_rounded),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1.0;
                      });
                    },
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            Text(AppLocalizations.of(context)?.selectAnyIssuesPresentOptional ?? 'Select any issues present (Optional)',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _issueOptions.entries.map((entry) {
                final isSelected = _selectedIssues.contains(entry.key);
                return FilterChip(
                  label: Text(entry.key),
                  avatar: Icon(
                    entry.value,
                    size: 16,
                    color: isSelected ? AppTheme.primary : AppTheme.onSurfaceMid,
                  ),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedIssues.add(entry.key);
                      } else {
                        _selectedIssues.remove(entry.key);
                      }
                    });
                  },
                  backgroundColor: AppTheme.surfaceVariant,
                  selectedColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primary,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: isSelected ? AppTheme.primary : AppTheme.onBackground,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            Text(AppLocalizations.of(context)?.describeYourExperienceOptional ?? 'Describe your experience (Optional)',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _experienceController,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Share what you saw or experienced here...',
                hintStyle: GoogleFonts.inter(color: AppTheme.onSurfaceMid),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(AppLocalizations.of(context)?.submitReview ?? 'Submit Review',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
