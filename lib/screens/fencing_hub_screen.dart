import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class FencingHubScreen extends StatelessWidget {
  const FencingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Fencing',
          style: GoogleFonts.inter(
            color: AppTheme.onBackground,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.onBackground),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              'Select the type of safety perimeter you want to create.',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppTheme.onSurfaceMid,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            _buildFencingCard(
              context: context,
              title: 'Geo Fencing',
              description: 'Set a circular safe zone around a specific location. Triggers SOS if you leave the area.',
              icon: Icons.my_location_rounded,
              color: Colors.blue,
              route: '/geofencing',
            ),
            const SizedBox(height: 24),
            
            _buildFencingCard(
              context: context,
              title: 'Route Fencing',
              description: 'Set a safe travel corridor to a destination. Triggers SOS if you deviate from the path.',
              icon: Icons.route_rounded,
              color: Colors.green,
              route: '/route-fencing',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFencingCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.onSurfaceMid,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}
