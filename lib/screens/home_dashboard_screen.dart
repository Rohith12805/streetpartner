import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/sos_button.dart';
import '../widgets/feature_card.dart';
import '../services/sos_service.dart';
import '../services/user_state.dart';

/// Home Dashboard — Figma node 1:149
/// AppBar with logo + profile avatar, large SOS button centered, 2x2 feature grid
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _isSosActive = false;
  bool _isSosLoading = false;
  String _lastStatusMessage = 'Guardian Network Active';

  bool _isModalOpen = false;

  @override
  void initState() {
    super.initState();
    // Auto-request Android OS permissions (CALL_PHONE, SEND_SMS, GPS Location)
    SosService.requestPermissions();

    // Register native 3-shake gesture listener
    SosService.initializeShakeHandler(() {
      if (!_isModalOpen && mounted) {
        _showSosCountdownDialog(isShakeTriggered: true);
      }
    });
  }

  void _onSosPressed() {
    _showSosCountdownDialog(isShakeTriggered: false);
  }

  void _showSosCountdownDialog({bool isShakeTriggered = false}) {
    if (_isModalOpen) return;
    _isModalOpen = true;
    int secondsLeft = 10;
    Timer? countdownTimer;

    // Start playing loud emergency alarm siren sound
    SosService.playAlarmSound();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (secondsLeft > 1) {
                setModalState(() {
                  secondsLeft--;
                });
              } else {
                t.cancel();
                _isModalOpen = false;
                SosService.stopAlarmSound();
                Navigator.of(dialogCtx).pop();
                _dispatchSosAlert();
              }
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.sosRed, width: 2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.volume_up_rounded, color: AppTheme.sosRed, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isShakeTriggered ? 'SHAKE DETECTED! SOS' : 'EMERGENCY SOS',
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
                    isShakeTriggered
                        ? '3-Shake gesture detected! Siren sounding.'
                        : 'Emergency alarm sounding.',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
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
                      '$secondsLeft',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'If shaken accidentally, tap STOP SOS within 10s to stop siren, calls, and SMS messages.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    _isModalOpen = false;
                    SosService.stopAlarmSound();
                    Navigator.of(dialogCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('SOS Alert & Alarm Siren cancelled.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
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
                    countdownTimer?.cancel();
                    _isModalOpen = false;
                    SosService.stopAlarmSound();
                    Navigator.of(dialogCtx).pop();
                    _dispatchSosAlert();
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
      SosService.stopAlarmSound();
    });
  }



  Future<void> _dispatchSosAlert() async {
    setState(() {
      _isSosLoading = true;
      _isSosActive = true;
    });

    final contacts = UserState.instance.getEmergencyPhoneNumbers();
    final targetNumbers = contacts.isNotEmpty ? contacts : ['112', '911'];
    final userName = UserState.instance.name;

    final result = await SosService.triggerSosAlert(
      phoneNumbers: targetNumbers,
      message: 'EMERGENCY SOS: $userName needs immediate assistance!',
      callEmergency: true,
    );

    setState(() {
      _isSosLoading = false;
      _lastStatusMessage = result.success
          ? 'SOS Sent to ${targetNumbers.length} contacts! (Lat: ${result.latitude.toStringAsFixed(4)}, Lng: ${result.longitude.toStringAsFixed(4)})'
          : 'SOS Dispatch Failed: ${result.errorMessage ?? "Error"}';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.success
                      ? '🚨 Emergency call initiated & SMS sent to ${targetNumbers.length} contacts!'
                      : '🚨 Failed to send alert: ${result.errorMessage}',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: result.success ? AppTheme.sosRed : Colors.orange.shade800,
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
            // ── User Profile Summary Card (Requirement D) ────────────────
            _buildUserProfileSummaryCard(context),

            const SizedBox(height: 16),

            // ── SOS Button Section ──────────────────────────────────────
            _buildSosSection(context),

            // ── Quick Features Grid ─────────────────────────────────────
            _buildFeatureGrid(context),

            const SizedBox(height: 24),

            // ── Guardian Network Status bar ─────────────────────────────
            _buildStatusBar(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileSummaryCard(BuildContext context) {
    final user = UserState.instance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryLight,
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onBackground),
                      ),
                      Text(
                        user.email,
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceMid),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppTheme.sosRed, size: 22),
                tooltip: 'Logout',
                onPressed: () {
                  UserState.instance.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                },
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoTile('Mobile', user.phone),
              _infoTile('DOB', user.dateOfBirth),
              _infoTile('Blood Group', user.bloodGroup),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Registered Emergency Contacts (${user.emergencyContacts.length})',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          Column(
            children: user.emergencyContacts.map((contact) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.contact_phone_rounded, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          contact.name,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      contact.phone,
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceMid),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceMid)),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? 'N/A' : value,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onBackground),
        ),
      ],
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
            child:
                const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Home Dashboard',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.onBackground),
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
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 20),
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
            isActive: _isSosActive,
            isLoading: _isSosLoading,
            onPressed: _onSosPressed,
          ),
          const SizedBox(height: 24),
          // Description text (Figma node 1:164)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _isSosActive
                  ? '🚨 SOS ALERT ACTIVE\nPress again to cancel or re-trigger emergency alert.'
                  : 'Tap to launch 3s countdown\nalerts trusted contacts & local authorities.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _isSosActive ? AppTheme.sosRed : AppTheme.onSurfaceMid,
                fontWeight: _isSosActive ? FontWeight.w600 : FontWeight.normal,
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
                  color: AppTheme.onBackground),
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: features
                .map((f) => FeatureCard(
                      icon: f.icon,
                      iconBgColor: f.iconBg,
                      iconColor: f.iconColor,
                      title: f.title,
                      description: f.description,
                      onTap: () => Navigator.pushNamed(context, f.route),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    // Figma node 1:210 — Guardian Network status card
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar (Figma node 1:212)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSosActive ? AppTheme.sosRedContainer : AppTheme.primaryLight,
              ),
              child: Icon(
                _isSosActive ? Icons.warning_rounded : Icons.person_rounded,
                color: _isSosActive ? AppTheme.sosRed : Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Status dot (Figma node 1:215)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isSosActive ? AppTheme.sosRed : AppTheme.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _isSosActive ? 'Emergency Active' : 'Guardian Network Active',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onBackground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastStatusMessage,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppTheme.onSurfaceMid),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.onSurfaceLight),
          ],
        ),
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
