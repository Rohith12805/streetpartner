import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Large circular SOS button with animated pulse rings — matches Figma node 1:154
class SosButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isLoading;

  const SosButton({
    super.key,
    this.onPressed,
    this.isActive = false,
    this.isLoading = false,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.isActive ? 1 : 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 1.0, end: widget.isActive ? 1.35 : 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(SosButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _controller.duration = Duration(milliseconds: widget.isActive ? 800 : 2000);
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isActive ? const Color(0xFFDC2626) : AppTheme.sosRed;

    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onPressed,
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 192,
                  height: 192,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor.withValues(alpha: widget.isActive ? 0.25 : 0.1),
                  ),
                ),
              ),
            ),
            // Inner ring
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeColor.withValues(alpha: widget.isActive ? 0.4 : 0.2),
              ),
            ),
            // Main button
            Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeColor,
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.4),
                    blurRadius: widget.isActive ? 30 : 20,
                    spreadRadius: widget.isActive ? 8 : 4,
                  ),
                ],
              ),
              child: widget.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isActive ? Icons.emergency_rounded : Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isActive ? 'ACTIVE' : 'SOS',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: widget.isActive ? 1.5 : 2.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

