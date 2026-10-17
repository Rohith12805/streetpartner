import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/sheild_brand_text.dart';

class OnboardingSlide {
  final String imagePath;
  final String title;

  const OnboardingSlide({
    required this.imagePath,
    required this.title,
  });
}

/// Refined Welcome / Get Started onboarding screen with prominent illustrations
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  // The 3 slides in the EXACT required sequence:
  // Slide 1: Your Safety, Our Support — protective SHEild symbol
  // Slide 2: Help When It Matters — SOS phone and connected contacts
  // Slide 3: Safety Is for Everyone — inclusive community and protective shield
  // Note: Headings and descriptions are embedded directly within these images.
  final List<OnboardingSlide> _slides = const [
    OnboardingSlide(
      imagePath: 'assets/images/onboarding_slide_1.jpg',
      title: 'Your Safety, Our Support',
    ),
    OnboardingSlide(
      imagePath: 'assets/images/onboarding_slide_2.jpg',
      title: 'Help When It Matters',
    ),
    OnboardingSlide(
      imagePath: 'assets/images/onboarding_slide_3.jpg',
      title: 'Safety Is for Everyone',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _finishOnboarding() {
    _timer?.cancel();
    Navigator.pushNamed(context, '/login').then((_) {
      if (mounted) {
        _startTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Subtle top gradient matching SHEild design system
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
            child: Column(
              children: [
                // ── Top Bar: SHEild Brand + Skip button ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SheildBrandText(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      TextButton(
                        onPressed: _finishOnboarding,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.onSurfaceLight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Middle: Prominent Carousel Image ──
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      _startTimer();
                    },
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              slide.imagePath,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              semanticLabel: slide.title,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Bottom: 3 Pagination Indicators ──
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isActive ? 24 : 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primary
                              : const Color(0xFFD8E2FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),

                // ── Fixed Get Started Button ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: FilledButton(
                      onPressed: _finishOnboarding,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 2,
                        shadowColor:
                            AppTheme.primary.withValues(alpha: 0.35),
                      ),
                      child: Text(
                        'Get Started →',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
