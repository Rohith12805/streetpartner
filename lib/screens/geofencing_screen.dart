import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Geo-fencing Screen — Figma node 1:467
/// Shows "Create Geofence" header, map placeholder, radius input + slider, alert toggles, Turn On button
class GeofencingScreen extends StatefulWidget {
  const GeofencingScreen({super.key});

  @override
  State<GeofencingScreen> createState() => _GeofencingScreenState();
}

class _GeofencingScreenState extends State<GeofencingScreen> {
  final _radiusCtrl = TextEditingController(text: '500');
  String _unit = 'Meters';
  double _sliderValue = 0.5; // 0=100m … 1=5km, maps to 500m at 0.5
  bool _onExitAlert = true;
  bool _onEntryAlert = false;

  @override
  void dispose() {
    _radiusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // ── AppBar (Figma node 1:560) ──────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xCCF8F9FA),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Geo Fencing',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.onBackground,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header text (Figma node 1:472) ────────────────────────
                  Text(
                    'Create Geofence',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set a radius to receive alerts when leaving or entering an area.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppTheme.onSurfaceMid,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Map placeholder (Figma node 1:478) ────────────────────
                  _buildMapPlaceholder(),
                  const SizedBox(height: 24),

                  // ── Controls card (Figma node 1:497) ──────────────────────
                  _buildControlsCard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Bottom action button (Figma node 1:554) ───────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.9),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 8,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Geofencing enabled for ${_radiusCtrl.text} $_unit! (Demo)',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  backgroundColor: AppTheme.primary,
                ),
              ),
              icon: const Icon(Icons.radar_rounded, size: 20),
              label: const Text('Turn On Geofencing'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
                elevation: 4,
                shadowColor: AppTheme.primary.withValues(alpha: 0.3),
                textStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    // Figma node 1:478 — map area with geofence circle overlay
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Map background grid
          CustomPaint(
            size: const Size(double.infinity, 220),
            painter: _MapGridPainter(),
          ),
          // Geofence radius circle (Figma node 1:487)
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.15),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
          ),
          // Center pin (Figma node 1:488)
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x29000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: SizedBox(
                width: 5,
                height: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Location button (Figma node 1:492 — bottom right)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.background,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    // Figma node 1:497 — white card with shadow, gap-24
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            'Geofence Radius',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppTheme.onSurfaceMid,
            ),
          ),
          const SizedBox(height: 12),

          // Radius input + Unit dropdown (Figma node 1:501)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _radiusCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '500',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.onBackground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.outline),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _unit,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.onSurfaceMid,
                      size: 18,
                    ),
                    items: ['Meters', 'Kilometers']
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(
                              u,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppTheme.onBackground,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Slider (Figma node 1:518)
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.divider,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _sliderValue,
              onChanged: (v) {
                setState(() {
                  _sliderValue = v;
                  if (_unit == 'Meters') {
                    _radiusCtrl.text = (100 + v * 4900).round().toString();
                  } else {
                    _radiusCtrl.text = (0.1 + v * 4.9).toStringAsFixed(1);
                  }
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '100m',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.onSurfaceMid,
                  ),
                ),
                Text(
                  '5km',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.onSurfaceMid,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Alert triggers section (Figma node 1:527)
          Text(
            'ALERT TRIGGERS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppTheme.onSurfaceMid,
            ),
          ),
          const SizedBox(height: 12),

          // On Exit toggle (Figma node 1:529)
          _alertToggleRow(
            icon: Icons.logout_rounded,
            iconBg: AppTheme.primaryContainer,
            iconColor: AppTheme.primary,
            title: 'On Exit',
            subtitle: 'Notify when leaving',
            value: _onExitAlert,
            onChanged: (v) => setState(() => _onExitAlert = v),
          ),
          const SizedBox(height: 8),

          // On Entry toggle (Figma node 1:541)
          _alertToggleRow(
            icon: Icons.login_rounded,
            iconBg: AppTheme.cardBg,
            iconColor: AppTheme.onSurfaceMid,
            title: 'On Entry',
            subtitle: 'Notify when returning',
            value: _onEntryAlert,
            onChanged: (v) => setState(() => _onEntryAlert = v),
          ),
        ],
      ),
    );
  }

  Widget _alertToggleRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.onBackground,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.onSurfaceMid,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8EAF0)
      ..strokeWidth = 0.5;

    // Draw grid lines to simulate a map
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw some stylized "roads"
    final roadPaint = Paint()
      ..color = const Color(0xFFD4D8E0)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.2, 0),
      Offset(size.width * 0.4, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.6),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.6, 0),
      Offset(size.width * 0.8, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
