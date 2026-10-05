import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../widgets/sheild_brand_text.dart';
import '../services/sos_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

/// Clean Authentication Screen with Google Sign-In only
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
    // Foolproof guarantee: Stop any running background service when the user reaches the login screen
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
        // The user canceled the sign-in
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
              height: 240,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.15),
                    AppTheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      _buildHeaderLogo(),
                      const SizedBox(height: 48),
                      _buildGoogleSignInButton(),
                      const SizedBox(height: 24),
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Color(0x15000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SheildBrandText(
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)?.proactiveProtectionSosEmergenc ?? 'Proactive Protection & SOS Emergency Network',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceMid),
        ),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(AppLocalizations.of(context)?.welcome ?? 'Welcome',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context)?.signInToAccessYourSecurityDash ?? 'Sign in to access your security dashboard',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.onSurfaceMid,
            ),
          ),
          const SizedBox(height: 32),

          _isLoading
              ? const CircularProgressIndicator()
              : FilledButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(
                    Icons.login,
                  ), // Or a Google Logo if available
                  label: Text(AppLocalizations.of(context)?.continueWithGoogle ?? 'Continue with Google',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size.fromHeight(52),
                    shape: StadiumBorder(
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    elevation: 0,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLegalFooter() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceLight),
        children: [
          const TextSpan(text: 'By signing in, you agree to '),
          SheildBrandText.span(
            baseStyle: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.onSurfaceLight,
              fontWeight: FontWeight.w600,
            ),
            suffix: ' Terms & Privacy Policy.',
          ),
        ],
      ),
    );
  }
}
