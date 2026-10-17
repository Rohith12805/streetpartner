import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/sheild_brand_text.dart';
import '../services/sos_service.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

/// Modern, clean, and professional Google Sign-In Screen for SHEild
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Stop any running background service when the user reaches the login screen
    SosService.stopForegroundService();
    _clearProtectionPreference();
  }

  Future<void> _clearProtectionPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_protection', false);
    } catch (_) {}
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // Force account picker by clearing any existing session first
      await GoogleSignIn().signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        scopes: ['email'],
      ).signIn();

      if (googleUser == null) {
        _showSnackBar('Sign-in canceled.', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Authentication failed', isError: true);
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? AppTheme.sosRed : Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const SheildBrandText(fontSize: 20),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Terms of Service & Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onBackground,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'SHEild is committed to empowering personal security while preserving user privacy:\n\n'
                '• Real-time location data is only accessed when you trigger SOS alerts, activate background protection, or use navigation features.\n'
                '• Emergency contacts designated by you receive instantaneous SMS notices and live tracking links during an active emergency.\n'
                '• Medical notes and personal details are strictly encrypted in Cloud Firestore and only visible to you and your trusted circle.\n'
                '• You retain full ownership of your data and can update or remove information at any time from Profile Management.',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: AppTheme.onSurfaceMid,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'I Understand',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background top gradient decoration
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.12),
                    AppTheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      // ── Official Branding Header ──
                      _buildHeaderLogo(),
                      const SizedBox(height: 32),

                      // ── Main Authentication Card ──
                      _buildAuthCard(),
                      const SizedBox(height: 24),

                      // ── Safety Highlights (3 Compact Columns) ──
                      _buildSafetyHighlights(),
                      const SizedBox(height: 28),

                      // ── Legal Footer ──
                      _buildLegalFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderLogo() {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18005BBF),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SheildBrandText(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context)?.proactiveProtectionSosEmergenc ??
              'Proactive Protection & SOS Emergency Network',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceMid,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)?.welcome ?? 'Welcome',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.onBackground,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)?.signInToAccessYourSecurityDash ??
                'Sign in to access your security dashboard.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceMid,
            ),
          ),
          const SizedBox(height: 16),

          // Inclusive Message Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5FE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryContainer.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.diversity_3_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety is for everyone.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Supporting women and men with tools for everyday safety.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.onSurfaceMid,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Prominent Google Sign-In Button ──
          _isLoading
              ? const SizedBox(
                  height: 54,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2.8,
                    ),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.onBackground,
                      side: const BorderSide(
                        color: Color(0xFFDADCE0),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                      elevation: 1,
                      shadowColor: const Color(0x10000000),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GoogleGLogo(size: 22),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)?.continueWithGoogle ??
                              'Continue with Google',
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3C4043),
                            letterSpacing: 0.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSafetyHighlights() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECEFF1), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Feature 1
            Expanded(
              child: _buildHighlightColumn(
                icon: Icons.verified_user_rounded,
                title: 'Stay Safe',
                description: 'Quick SOS & emergency support',
              ),
            ),
            const VerticalDivider(
              color: Color(0xFFE2E8F0),
              thickness: 1,
              width: 16,
              indent: 4,
              endIndent: 4,
            ),
            // Feature 2
            Expanded(
              child: _buildHighlightColumn(
                icon: Icons.groups_rounded,
                title: 'Stay Connected',
                description: 'Trusted contacts always with you',
              ),
            ),
            const VerticalDivider(
              color: Color(0xFFE2E8F0),
              thickness: 1,
              width: 16,
              indent: 4,
              endIndent: 4,
            ),
            // Feature 3
            Expanded(
              child: _buildHighlightColumn(
                icon: Icons.location_on_rounded,
                title: 'Stay Informed',
                description: 'Location sharing & real-time help',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightColumn({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE), // subtle light blue
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppTheme.primary, // clearly visible primary blue
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.onBackground,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppTheme.onSurfaceMid,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildLegalFooter() {
    return GestureDetector(
      onTap: _showTermsDialog,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.onSurfaceLight,
            ),
            children: [
              const TextSpan(text: 'By signing in, you agree to '),
              SheildBrandText.span(
                baseStyle: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                suffix: ' Terms & Privacy Policy.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pixel-perfect standard Google "G" logo
class GoogleGLogo extends StatelessWidget {
  final double size;
  const GoogleGLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleGLogoPainter(),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double r = w / 2;

    // Paints for 4 Google brand colors
    final Paint redPaint = Paint()..color = const Color(0xFFEA4335);
    final Paint yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final Paint greenPaint = Paint()..color = const Color(0xFF34A853);
    final Paint bluePaint = Paint()..color = const Color(0xFF4285F4);

    final Rect outerRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final Rect innerRect =
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.55);

    // Blue horizontal bar and right arc
    final Path bluePath = Path()
      ..moveTo(cx + r * 0.05, cy - r * 0.22)
      ..lineTo(cx + r, cy - r * 0.22)
      ..arcTo(outerRect, -0.22, 1.45, false)
      ..lineTo(cx, cy)
      ..arcTo(innerRect, 1.23, -1.45, false)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green bottom arc
    final Path greenPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(outerRect, 1.23, 1.4, false)
      ..lineTo(cx, cy)
      ..arcTo(innerRect, 2.63, -1.4, false)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow left arc
    final Path yellowPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(outerRect, 2.63, 1.25, false)
      ..lineTo(cx, cy)
      ..arcTo(innerRect, 3.88, -1.25, false)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red top arc
    final Path redPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(outerRect, 3.88, 1.65, false)
      ..lineTo(cx, cy)
      ..arcTo(innerRect, 5.53, -1.65, false)
      ..close();
    canvas.drawPath(redPath, redPaint);

    // White circle punchout in center
    final Paint whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.45, whitePaint);

    // Blue horizontal tongue bar
    final Path tonguePath = Path()
      ..addRect(
        Rect.fromLTRB(cx - r * 0.05, cy - r * 0.22, cx + r * 0.95, cy + r * 0.22),
      );
    canvas.drawPath(tonguePath, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
