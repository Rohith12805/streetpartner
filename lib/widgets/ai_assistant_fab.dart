import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

/// Modernized Floating AI Assistant button with gradient styling, polished AI iconography,
/// and an occasional temporary semi-transparent "AI Assistant" pill label.
class AiAssistantFab extends StatefulWidget {
  final VoidCallback onPressed;

  const AiAssistantFab({
    super.key,
    required this.onPressed,
  });

  @override
  State<AiAssistantFab> createState() => _AiAssistantFabState();
}

class _AiAssistantFabState extends State<AiAssistantFab>
    with WidgetsBindingObserver {
  bool _showLabel = false;
  Timer? _initialTimer;
  Timer? _hideTimer;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLabelLifecycle();
  }

  void _startLabelLifecycle() {
    // Show briefly when screen becomes active (after 500ms for smooth appearance)
    _initialTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showLabel = true);
        _scheduleHide();
      }
    });

    // Schedule periodic appearance every 35 seconds
    _periodicTimer = Timer.periodic(const Duration(seconds: 35), (timer) {
      if (mounted) {
        setState(() => _showLabel = true);
        _scheduleHide();
      }
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _showLabel = false);
      }
    });
  }

  void _cancelTimers() {
    _initialTimer?.cancel();
    _hideTimer?.cancel();
    _periodicTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _cancelTimers();
      if (mounted) setState(() => _showLabel = false);
    } else if (state == AppLifecycleState.resumed) {
      _startLabelLifecycle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Occasional floating pill label
        AnimatedOpacity(
          opacity: _showLabel ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: !_showLabel,
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryLight.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)?.aiAssistant ?? 'AI Assistant',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Polished Circular Button
        GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1A73E8),
                  Color(0xFF005BBF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  Positioned(
                    top: 13,
                    right: 12,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF64B5F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
