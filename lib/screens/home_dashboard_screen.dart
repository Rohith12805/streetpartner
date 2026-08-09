import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/sos_button.dart';
import '../widgets/feature_card.dart';
import '../services/sos_service.dart';

/// Home Dashboard — Figma node 1:149
/// AppBar with logo + profile avatar, large SOS button centered, 2x2 feature grid
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _isModalOpen = false;
  int _secondsLeft = 10;

  StreamSubscription<int>? _timerSubscription;
  StateSetter? _modalSetState;

  @override
  void initState() {
    super.initState();
    // Auto-request Android OS permissions (CALL_PHONE, SEND_SMS, GPS Location, Notifications)
    SosService.requestPermissions().then((_) {
      _initializeSosService();
    });

    // Listen to timer ticks from Native Foreground Service
    _timerSubscription = SosService.timerTickStream.listen((tick) {
      if (!mounted) return;

      if (tick > 0) {
        _secondsLeft = tick;
        if (!_isModalOpen) {
          _showSosCountdownDialog();
        } else {
          _modalSetState?.call(() {});
        }
      } else if (tick == 0) {
        // Countdown finished, alert is dispatching
        if (_isModalOpen) {
          _isModalOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        _onSosDispatched();
      } else if (tick == -1) {
        // Countdown cancelled
        if (_isModalOpen) {
          _isModalOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS Alert & Alarm Siren cancelled.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeSosService() async {
    List<String> targetNumbers = ['112', '911'];
    String userName = 'Unknown User';

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final contacts =
              (data['emergencyContacts'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (contacts.isNotEmpty) {
            targetNumbers = contacts;
          }
          userName = data['fullName'] ?? user.displayName ?? 'Unknown User';
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data for SOS: $e');
    }

    SosService.startSosService(
      phoneNumbers: targetNumbers,
      message: 'EMERGENCY SOS: $userName needs immediate assistance!',
    );
  }

  void _onSosPressed() {
    // Manually trigger the native foreground countdown
    SosService.triggerSosCountdown();
  }

  void _showSosCountdownDialog() {
    if (_isModalOpen) return;
    _isModalOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            _modalSetState = setModalState;

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.sosRed, width: 2),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.volume_up_rounded,
                    color: AppTheme.sosRed,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'EMERGENCY SOS',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Emergency alarm sounding.',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.sosRed,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_secondsLeft',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap STOP SOS within 10s to stop siren, calls, and SMS messages.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    SosService.stopSosCountdown();
                  },
                  child: Text(
                    'STOP SOS',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.sosRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    SosService.triggerSosAlert();
                    _onSosDispatched();
                  },
                  child: Text(
                    'SEND NOW',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _isModalOpen = false;
      _modalSetState = null;
    });
  }

  void _onSosDispatched() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🚨 Emergency dispatched via background service!',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.sosRed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // ── SOS Button Section ──────────────────────────────────────
            _buildSosSection(context),

            // ── Quick Features Grid ─────────────────────────────────────
            _buildFeatureGrid(context),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xCCF8F9FA),
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          // Logo icon (Figma node 1:226)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Home Dashboard',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.onBackground,
            ),
          ),
        ],
      ),
      actions: [
        // Profile avatar button (Figma node 1:229)
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryLight,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSosSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // SOS Button with pulse animation and active/loading state
          SosButton(
            isActive: false,
            isLoading: false,
            onPressed: _onSosPressed,
          ),
          const SizedBox(height: 24),
          // Description text (Figma node 1:164)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap to launch 3s countdown\nalerts trusted contacts & local authorities.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.onSurfaceMid,
                fontWeight: FontWeight.normal,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    // 2x2 grid data (Figma nodes 1:171, 1:181, 1:191, 1:200)
    final features = [
      _FeatureData(
        icon: Icons.radar_rounded,
        iconBg: const Color(0xFF2A73E1),
        iconColor: Colors.white,
        title: 'Geo-Fencing',
        description: 'Create virtual safety\nperimeters.',
        route: '/geofencing',
      ),
      _FeatureData(
        icon: Icons.phone_in_talk_rounded,
        iconBg: const Color(0xFF1A73E8),
        iconColor: Colors.white,
        title: 'Fake Call',
        description: 'Schedule a simulated\nincoming call.',
        route: '/fake-call',
      ),
      _FeatureData(
        icon: Icons.bar_chart_rounded,
        iconBg: AppTheme.divider,
        iconColor: AppTheme.onSurfaceMid,
        title: 'Safety Index',
        description: 'Check local area\nsafety score.',
        route: '/safety-index',
      ),
      _FeatureData(
        icon: Icons.emergency_rounded,
        iconBg: AppTheme.sosRedContainer,
        iconColor: AppTheme.sosRed,
        title: 'Emergency',
        description: 'Quick access to\npolice and fire.',
        route: '/emergency-services',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'Quick Features',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.onBackground,
              ),
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.80,
            children: features
                .map(
                  (f) => FeatureCard(
                    icon: f.icon,
                    iconBgColor: f.iconBg,
                    iconColor: f.iconColor,
                    title: f.title,
                    description: f.description,
                    onTap: () => Navigator.pushNamed(context, f.route),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String description;
  final String route;

  const _FeatureData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.route,
  });
}
