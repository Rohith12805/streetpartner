import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/fake_call.dart';
import '../services/fake_call_service.dart';
import 'fake_call_conversation_screen.dart';

class FakeIncomingCallScreen extends StatefulWidget {
  final FakeCall fakeCall;

  const FakeIncomingCallScreen({
    super.key,
    required this.fakeCall,
  });

  @override
  State<FakeIncomingCallScreen> createState() => _FakeIncomingCallScreenState();
}

class _FakeIncomingCallScreenState extends State<FakeIncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAnimation();
    _startRingtone();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startRingtone() async {
    await FakeCallService.instance.playBuiltInRingtone();
  }

  Future<void> _stopRingtone() async {
    await FakeCallService.instance.stopBuiltInRingtone();
    if (_isPlayingAudio) {
      try {
        await _audioPlayer.stop();
        _isPlayingAudio = false;
      } catch (e) {
        debugPrint('Error stopping audio: $e');
      }
    }
  }

  void _onAcceptCall() async {
    await _stopRingtone();
    if (!mounted) return;

    // Navigate to active conversation screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => FakeCallConversationScreen(fakeCall: widget.fakeCall),
      ),
    );
  }

  void _onDeclineCall() async {
    await _stopRingtone();
    FakeCallService.instance.markCallEnded();
    await FakeCallService.instance.updateCallStatus(
      widget.fakeCall.id,
      FakeCallStatus.cancelled,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopRingtone();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callerName = widget.fakeCall.callerName;
    final phoneNumber = widget.fakeCall.phoneNumber;
    final initial =
        callerName.isNotEmpty ? callerName[0].toUpperCase() : 'C';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onDeclineCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Dark caller screen bg
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),

              // "Incoming call" indicator header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.phone_callback_rounded,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Simulated Incoming Call',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Caller Avatar with pulsing animation
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Caller Name
              Text(
                callerName,
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Phone Number if available
              if (phoneNumber != null && phoneNumber.trim().isNotEmpty) ...[
                Text(
                  phoneNumber,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Incoming Call Status Text
              Text(
                'Incoming call...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF60A5FA),
                ),
              ),

              const Spacer(),

              // Action buttons (Decline / Accept)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Decline button (Red)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _onDeclineCall,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFEF4444),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x66EF4444),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.call_end_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Decline',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),

                    // Accept button (Green)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _onAcceptCall,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF22C55E),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x6622C55E),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.call_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Accept',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
