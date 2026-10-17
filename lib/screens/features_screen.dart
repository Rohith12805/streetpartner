import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

/// Dedicated Safety Features destination displaying the four core safety tools
/// in an overflow-free, flexible responsive card layout.
class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final f1 = _FeatureItem(
      title: loc?.geoFencing ?? 'Geo Fencing',
      description: loc?.geoFencingShortDesc ?? 'Create a safe perimeter around a location.',
      icon: Icons.radar_rounded,
      route: '/geofencing',
      iconBgColor: const Color(0xFFE8F0FE),
      iconColor: AppTheme.primary,
    );

    final f2 = _FeatureItem(
      title: loc?.navigation ?? 'Navigation',
      description: loc?.navigationShortDesc ?? 'Access safe routes and directions.',
      icon: Icons.navigation_rounded,
      route: '/navigation',
      iconBgColor: const Color(0xFFE6F4EA),
      iconColor: const Color(0xFF137333),
    );

    final f3 = _FeatureItem(
      title: loc?.fakeCall ?? 'Fake Call',
      description: loc?.fakeCallShortDesc ?? 'Schedule a simulated incoming call.',
      icon: Icons.phone_in_talk_rounded,
      route: '/fake-call',
      iconBgColor: const Color(0xFFFEF7E0),
      iconColor: const Color(0xFFB06000),
    );

    final f4 = _FeatureItem(
      title: loc?.emergencyServices ?? 'Emergency',
      description: loc?.emergencyServicesShortDesc ?? 'Quick access to emergency services.',
      icon: Icons.emergency_rounded,
      route: '/emergency-services',
      iconBgColor: AppTheme.sosRedContainer,
      iconColor: AppTheme.sosRed,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              // Section Header
              Text(
                loc?.safetyFeatures ?? 'Safety Features',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onBackground,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                loc?.toolsToHelpYouStaySafe ?? 'Tools to help you stay safe, wherever you go.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.onSurfaceMid,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Responsive 2-Row Grid using IntrinsicHeight to eliminate RenderFlex overflow
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildFeatureCard(context, f1)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildFeatureCard(context, f2)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildFeatureCard(context, f3)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildFeatureCard(context, f4)),
                  ],
                ),
              ),

              const SizedBox(height: 100), // Generous padding above floating bottom nav & FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, _FeatureItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(context, item.route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.iconBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.iconColor,
                        size: 22,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.outline.withValues(alpha: 0.5),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onBackground,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.onSurfaceMid,
                    height: 1.3,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final Color iconBgColor;
  final Color iconColor;

  const _FeatureItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.iconBgColor,
    required this.iconColor,
  });
}
