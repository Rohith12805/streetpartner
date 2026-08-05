import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/sos_button.dart';
import '../widgets/feature_card.dart';

/// Home Dashboard — Figma node 1:149
/// AppBar with logo + profile avatar, large SOS button centered, 2x2 feature grid
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // ── Custom AppBar (Figma node 1:223) ───────────────────────────────────
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── SOS Button Section (Figma node 1:153) ───────────────────────
            _buildSosSection(context),

            // ── Quick Features Grid (Figma node 1:167) ──────────────────────
            _buildFeatureGrid(context),

            const SizedBox(height: 24),

            // ── Guardian Network Status bar (Figma node 1:210) ─────────────
            _buildStatusBar(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xCCF8F9FA),
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          // Logo icon (Figma node 1:226)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Home Dashboard',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.onBackground),
          ),
        ],
      ),
      actions: [
        // Profile avatar button (Figma node 1:229)
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryLight,
            ),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSosSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // SOS Button with pulse animation
          SosButton(
            onPressed: () {
              // Static placeholder — shows a snackbar in lieu of real SOS
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🚨 SOS Triggered! (Demo)',
                      style: GoogleFonts.inter(color: Colors.white)),
                  backgroundColor: AppTheme.sosRed,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Description text (Figma node 1:164)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Press and hold for 3 seconds to alert\ntrusted contacts and local authorities.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppTheme.onSurfaceMid, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    // 2x2 grid data (Figma nodes 1:171, 1:181, 1:191, 1:200)
    final features = [
      _FeatureData(
        icon: Icons.radar_rounded,
        iconBg: const Color(0xFF2A73E1),
        iconColor: Colors.white,
        title: 'Geo-Fencing',
        description: 'Create virtual safety\nperimeters.',
        route: '/geofencing',
      ),
      _FeatureData(
        icon: Icons.phone_in_talk_rounded,
        iconBg: const Color(0xFF1A73E8),
        iconColor: Colors.white,
        title: 'Fake Call',
        description: 'Schedule a simulated\nincoming call.',
        route: '/fake-call',
      ),
      _FeatureData(
        icon: Icons.bar_chart_rounded,
        iconBg: AppTheme.divider,
        iconColor: AppTheme.onSurfaceMid,
        title: 'Safety Index',
        description: 'Check local area\nsafety score.',
        route: '/safety-index',
      ),
      _FeatureData(
        icon: Icons.emergency_rounded,
        iconBg: AppTheme.sosRedContainer,
        iconColor: AppTheme.sosRed,
        title: 'Emergency',
        description: 'Quick access to\npolice and fire.',
        route: '/emergency-services',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'Quick Features',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onBackground),
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: features
                .map((f) => FeatureCard(
                      icon: f.icon,
                      iconBgColor: f.iconBg,
                      iconColor: f.iconColor,
                      title: f.title,
                      description: f.description,
                      onTap: () => Navigator.pushNamed(context, f.route),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    // Figma node 1:210 — Guardian Network status card
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar (Figma node 1:212)
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryLight,
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Green dot (Figma node 1:215)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Guardian Network Active',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onBackground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '3 trusted contacts are sharing location.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppTheme.onSurfaceMid),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.onSurfaceLight),
          ],
        ),
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String description;
  final String route;

  const _FeatureData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.route,
  });
}
