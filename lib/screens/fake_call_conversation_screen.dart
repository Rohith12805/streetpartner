import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart' as session;
import '../models/fake_call.dart';
import '../services/fake_call_service.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

class FakeCallConversationScreen extends StatefulWidget {
  final FakeCall fakeCall;

  const FakeCallConversationScreen({
    super.key,
    required this.fakeCall,
  });

  @override
  State<FakeCallConversationScreen> createState() =>
      _FakeCallConversationScreenState();
}

class _FakeCallConversationScreenState
    extends State<FakeCallConversationScreen> {
  late Timer _timer;
  int _elapsedSeconds = 0;

  bool _isMuted = false;
  bool _isSpeakerOn = false;

  AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startCallTimer();
    _initCallAudio();
  }

  Future<void> _initCallAudio() async {
    await _setAudioRouting(speakerOn: false);
    _playVoiceClip();
  }

  Future<void> _setAudioRouting({required bool speakerOn}) async {
    final s = await session.AudioSession.instance;
    await s.configure(session.AudioSessionConfiguration(
      avAudioSessionCategory: session.AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: speakerOn 
          ? session.AVAudioSessionCategoryOptions.defaultToSpeaker 
          : session.AVAudioSessionCategoryOptions.none,
      avAudioSessionMode: session.AVAudioSessionMode.voiceChat,
      avAudioSessionRouteSharingPolicy: session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: session.AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: session.AndroidAudioAttributes(
        contentType: speakerOn ? session.AndroidAudioContentType.music : session.AndroidAudioContentType.speech,
        flags: session.AndroidAudioFlags.none,
        usage: speakerOn ? session.AndroidAudioUsage.media : session.AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: session.AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    final ctx = AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: speakerOn,
        stayAwake: true,
        contentType: speakerOn ? AndroidContentType.music : AndroidContentType.speech,
        usageType: speakerOn ? AndroidUsageType.media : AndroidUsageType.voiceCommunication,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: speakerOn ? const {AVAudioSessionOptions.defaultToSpeaker} : const {},
      ),
    );
    await AudioPlayer.global.setAudioContext(ctx);
    await _audioPlayer.setAudioContext(ctx);
  }

  Future<void> _playVoiceClip() async {
    final lang = widget.fakeCall.voiceLanguage;
    final path = 'audio/fake_call_$lang.mp3';
    // Play on loop
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource(path));
  }

  void _startCallTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  String get _formattedDuration {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _endCall() async {
    _timer.cancel();
    _audioPlayer.stop();
    FakeCallService.instance.markCallEnded();
    await FakeCallService.instance.updateCallStatus(
      widget.fakeCall.id,
      FakeCallStatus.completed,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer.cancel();
    _audioPlayer.dispose();
    
    // Reset global AudioSession back to music/media defaults
    session.AudioSession.instance.then((s) {
      s.configure(const session.AudioSessionConfiguration.music());
    });

    // Reset global AudioContext back to standard media player defaults
    AudioPlayer.global.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {},
      ),
    ));
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
        _endCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),

              // Active Call Status Header
              Text(
                _elapsedSeconds == 0 ? 'Connecting...' : _formattedDuration,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF38BDF8),
                  letterSpacing: 1.0,
                ),
              ),

              const Spacer(),

              // Avatar
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.inter(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Caller Name
              Text(
                callerName,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Phone Number if present
              if (phoneNumber != null && phoneNumber.trim().isNotEmpty) ...[
                Text(
                  phoneNumber,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Text(AppLocalizations.of(context)?.simulatedOngoingCall ?? 'Simulated Ongoing Call',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),

              const Spacer(),

              // In-call Control Buttons (Mute, Keypad, Speaker)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _callControlButton(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _isMuted ? 'Muted' : 'Mute',
                      isActive: _isMuted,
                      onTap: () => setState(() => _isMuted = !_isMuted),
                    ),
                    _callControlButton(
                      icon: Icons.dialpad_rounded,
                      label: 'Keypad',
                      isActive: false,
                      onTap: () {},
                    ),
                    _callControlButton(
                      icon: _isSpeakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      label: 'Speaker',
                      isActive: _isSpeakerOn,
                      onTap: () async {
                        final pos = await _audioPlayer.getCurrentPosition();
                        await _audioPlayer.stop();
                        await _audioPlayer.dispose(); // Destroy the old player completely
                        
                        setState(() {
                          _isSpeakerOn = !_isSpeakerOn;
                          _audioPlayer = AudioPlayer(); // Create a brand new fresh player
                        });
                        
                        await _setAudioRouting(speakerOn: _isSpeakerOn);
                        
                        // Restart playback on the new player instance
                        await _playVoiceClip();
                        if (pos != null) {
                          await _audioPlayer.seek(pos);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // End Call Button
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: GestureDetector(
                  onTap: _endCall,
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
                      size: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _callControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF1E293B),
              border: Border.all(
                color: const Color(0xFF334155),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
