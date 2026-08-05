import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// OTP Verification Screen — Figma node 1:118
/// 4 separate single-character input boxes, Verify button → Home Dashboard
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final List<String> _otp = ['', '', '', ''];

  bool get _isComplete => _otp.every((d) => d.isNotEmpty);

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitEntered(int index, String value) {
    if (value.isEmpty) {
      setState(() => _otp[index] = '');
      if (index > 0) _focusNodes[index - 1].requestFocus();
    } else {
      setState(() => _otp[index] = value[value.length - 1]);
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // ── Header (Figma node 1:122) ─────────────────────────────────
              Column(
                children: [
                  // Phone icon in blue circle (Figma node 1:124 — bg #1a73e8)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryLight,
                    ),
                    child: const Icon(Icons.phone_android_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify Phone Number',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the 4-digit code sent to your phone',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.onSurfaceMid,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── OTP Input boxes (Figma node 1:133) ───────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final isFocused = _focusNodes[i].hasFocus;
                  final isFilled = _otp[i].isNotEmpty;
                  return Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 12 : 0),
                    child: _OtpBox(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      isFocused: isFocused,
                      isFilled: isFilled,
                      onChanged: (v) => _onDigitEntered(i, v),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 40),

              // ── Resend Code (Figma node 1:139) ───────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Resend Code ',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '(0:28)',
                    style: GoogleFonts.inter(
                        fontSize: 16, color: AppTheme.onSurfaceMid),
                  ),
                ],
              ),

              const Spacer(),

              // ── Verify Button (Figma node 1:145) ──────────────────────────
              AnimatedOpacity(
                opacity: _isComplete ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: FilledButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (r) => false),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _isComplete ? AppTheme.primary : AppTheme.cardBg,
                    foregroundColor:
                        _isComplete ? Colors.white : AppTheme.onSurfaceMid,
                    minimumSize: const Size.fromHeight(56),
                    shape: const StadiumBorder(),
                    textStyle: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Verify'),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final bool isFilled;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.isFilled,
    required this.onChanged,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.focusNode.hasFocus;
    return Container(
      width: 64,
      height: 72,
      decoration: BoxDecoration(
        // Figma: focused box has blue outline shadow, unfocused is #edeeef
        color: isFocused
            ? AppTheme.divider
            : const Color(0xFFEDEEEF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AppTheme.primary,
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppTheme.onBackground,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
