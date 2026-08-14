import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Area Safety Index Screen — Figma node 1:569
/// Large circular progress indicator showing safety %, horizontal slider, Submit + Back buttons
class AreaSafetyIndexScreen extends StatefulWidget {
  const AreaSafetyIndexScreen({super.key});

  @override
  State<AreaSafetyIndexScreen> createState() => _AreaSafetyIndexScreenState();
}

class _AreaSafetyIndexScreenState extends State<AreaSafetyIndexScreen>
    with SingleTickerProviderStateMixin {
  double _safetyScore = 0.82; // 82% placeholder (Figma node 1:607)
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: _safetyScore,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _scoreColor {
    if (_safetyScore >= 0.7) return AppTheme.primary;
    if (_safetyScore >= 0.4) return const Color(0xFFFFA000);
    return AppTheme.sosRed;
  }

  String get _scoreLabel {
    if (_safetyScore >= 0.75) return 'Secure';
    if (_safetyScore >= 0.5) return 'Moderate';
    if (_safetyScore >= 0.25) return 'Caution';
    return 'Hazardous';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // ── AppBar (Figma node 1:614) ──────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xCCF8F9FA),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Area Safety Index',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onBackground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // ── Title (Figma node 1:573) ───────────────────────────────────
            Text(
              'Area Safety Index',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current Location Safety Score',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppTheme.onSurfaceMid,
              ),
            ),
            const SizedBox(height: 40),

            // ── Circular Progress Indicator (Figma node 1:600) ────────────
            _buildCircularIndicator(),

            const SizedBox(height: 32),

            // ── Score label ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _scoreColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _scoreLabel,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _scoreColor,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Interactive Section (Figma node 1:579) ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildInteractiveSection(),
            ),

            const SizedBox(height: 24),

            // ── Action buttons ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildActions(context),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularIndicator() {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (context, child) {
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect (Figma node 1:604)
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      blurRadius: 24,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
              // Progress arc
              CustomPaint(
                size: const Size(220, 220),
                painter: _CircularProgressPainter(
                  progress: _progressAnim.value,
                  color: _scoreColor,
                  trackColor: AppTheme.divider,
                  strokeWidth: 16,
                ),
              ),
              // Percentage text (Figma node 1:607 — text-[#005bbf])
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(_safetyScore * 100).round()}%',
                    style: GoogleFonts.inter(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: _scoreColor,
                      letterSpacing: -2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractiveSection() {
    // Figma node 1:579 — rounded card with Report Condition slider
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row with Simulate button (Figma node 1:580)
          Row(
            children: [
              Text(
                'Report Condition',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onBackground,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  final random = math.Random();
                  final newScore = 0.2 + random.nextDouble() * 0.8;
                  setState(() {
                    _safetyScore = double.parse(newScore.toStringAsFixed(2));
                  });
                  _animController
                    ..reset()
                    ..forward();
                  _progressAnim = Tween<double>(begin: 0, end: _safetyScore)
                      .animate(
                        CurvedAnimation(
                          parent: _animController,
                          curve: Curves.easeOut,
                        ),
                      );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Simulate',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slider (Figma node 1:585 — hazardous ↔ secure)
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.sosRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _scoreColor,
                    inactiveTrackColor: AppTheme.divider,
                    thumbColor: _scoreColor,
                    overlayColor: _scoreColor.withValues(alpha: 0.1),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _safetyScore,
                    onChanged: (v) {
                      setState(() => _safetyScore = v);
                      _animController
                        ..reset()
                        ..forward();
                      _progressAnim = Tween<double>(begin: 0, end: _safetyScore)
                          .animate(
                            CurvedAnimation(
                              parent: _animController,
                              curve: Curves.easeOut,
                            ),
                          );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.verified_user_rounded,
                color: AppTheme.green,
                size: 20,
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hazardous',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMid,
                  ),
                ),
                Text(
                  'Secure',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        // Submit button (Figma node 1:609)
        FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Safety report submitted: ${(_safetyScore * 100).round()}% — $_scoreLabel (Demo)',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                backgroundColor: _scoreColor,
              ),
            );
          },
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Submit Safety Report'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Back button
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.onSurfaceMid,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            side: const BorderSide(color: AppTheme.divider),
          ),
          child: Text(
            'Back',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// Custom circular progress arc painter
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Full track
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Progress arc — starts from -90° (top)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at top
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress || old.color != color;
}
