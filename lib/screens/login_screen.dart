import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Login Screen — Figma node 1:2
/// Background: #F8F9FA, top gradient overlay, white card form
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Top gradient blue overlay (Figma node 1:3)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 256,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primary.withOpacity(0.12),
                    AppTheme.primary.withOpacity(0.0),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // ── Logo + App Name (Figma node 1:9) ──────────────────
                      _buildLogoSection(),

                      const SizedBox(height: 24),

                      // ── Form card (Figma node 1:20) ───────────────────────
                      _buildFormCard(context),

                      const SizedBox(height: 24),

                      // ── Sign Up link (Figma node 1:39) ───────────────────
                      _buildSignUpRow(context),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom legal text (Figma node 1:4) ───────────────────────────
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: _buildLegalText(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // App icon with rounded white background + subtle shadow
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary,
                  AppTheme.primaryLight,
                ],
              ),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'SafeGuard',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.onBackground,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your proactive safety companion.',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: AppTheme.onSurfaceMid,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phone Number label + input (Figma node 1:21)
          Text(
            'Phone Number',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.onSurfaceMid,
            ),
          ),
          const SizedBox(height: 12),

          // Input field with country code prefix
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Country code prefix section (Figma node 1:27)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded,
                          size: 18, color: AppTheme.onSurfaceMid),
                      const SizedBox(width: 4),
                      Text(
                        '+91',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppTheme.onSurfaceMid,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Vertical divider (Figma node 1:32)
                Container(
                  width: 1,
                  height: 32,
                  color: AppTheme.placeholder.withOpacity(0.5),
                ),
                // Phone input
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '(555) 000-0000',
                      hintStyle: GoogleFonts.inter(
                          color: AppTheme.placeholder, fontSize: 16),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    style: GoogleFonts.inter(
                        fontSize: 16, color: AppTheme.onBackground),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Continue button (Figma node 1:33) — navigates to OTP
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/otp'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Continue'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: const StadiumBorder(),
              elevation: 0,
              shadowColor: AppTheme.primary.withOpacity(0.3),
              textStyle:
                  GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New to SafeGuard? ',
          style: GoogleFonts.inter(
              fontSize: 16, color: AppTheme.onSurfaceMid),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/register'),
          child: Text(
            'Sign Up',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegalText() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurfaceLight),
        children: const [
          TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
          TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
        ],
      ),
    );
  }
}
