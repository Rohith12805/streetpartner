import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Fake Call Generator Screen — Figma node 1:467 (reassigned from Profile in MCP)
/// Time option cards, Custom time picker, Schedule button
class FakeCallGeneratorScreen extends StatefulWidget {
  const FakeCallGeneratorScreen({super.key});

  @override
  State<FakeCallGeneratorScreen> createState() =>
      _FakeCallGeneratorScreenState();
}

class _FakeCallGeneratorScreenState extends State<FakeCallGeneratorScreen> {
  String? _selectedOption; // '30s', '1m', '2m', '5m', 'custom'
  TimeOfDay? _customTime;
  bool _callScheduled = false;

  final List<_TimeOption> _options = [
    _TimeOption(id: '30s', label: '30 Seconds', icon: Icons.timer_outlined),
    _TimeOption(id: '1m', label: '1 Minute', icon: Icons.looks_one_outlined),
    _TimeOption(id: '2m', label: '2 Minutes', icon: Icons.looks_two_outlined),
    _TimeOption(id: '5m', label: '5 Minutes', icon: Icons.timer_outlined),
    _TimeOption(
      id: 'custom',
      label: 'Custom',
      icon: Icons.tune_rounded,
      fullWidth: true,
    ),
  ];

  String get _scheduleLabel {
    if (_selectedOption == null) return 'Select a time first';
    if (_selectedOption == 'custom') {
      if (_customTime == null) return 'Pick a custom time';
      return 'Schedule Call in ${_customTime!.format(context)}';
    }
    final opt = _options.firstWhere((o) => o.id == _selectedOption);
    return 'Schedule Call in ${opt.label}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // ── AppBar (Figma node 1:315) ──────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xCCF8F9FA),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Fake Call Generator',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.onBackground,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── Header (Figma node 1:256) ─────────────────────────────
                  Text(
                    'Fake Call',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Schedule an incoming call to discreetly exit a situation.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppTheme.onSurfaceMid,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Delay time section (Figma node 1:262) ─────────────────
                  Text(
                    'Delay time',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Time option grid (Figma node 1:265) ───────────────────
                  _buildTimeOptionsGrid(context),

                  // Custom time picker (shown when Custom is selected)
                  if (_selectedOption == 'custom') ...[
                    const SizedBox(height: 16),
                    _buildCustomTimePicker(context),
                  ],

                  // ── Call Scheduled toast (shown after scheduling) ──────────
                  if (_callScheduled) ...[
                    const SizedBox(height: 24),
                    _buildScheduledToast(context),
                  ],
                ],
              ),
            ),
          ),

          // ── Schedule button (Figma node 1:298) ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: FilledButton.icon(
              onPressed: _selectedOption == null
                  ? null
                  : () {
                      if (_selectedOption == 'custom' && _customTime == null) {
                        _pickCustomTime(context);
                        return;
                      }
                      setState(() => _callScheduled = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _scheduleLabel,
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    },
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: const Text('Schedule Call'),
              style: FilledButton.styleFrom(
                backgroundColor: _selectedOption != null
                    ? AppTheme.primary
                    : AppTheme.primary.withValues(alpha: 0.5),
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
                textStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeOptionsGrid(BuildContext context) {
    // 2-column grid with last item spanning full width (Figma node 1:265)
    final rowOptions = _options.where((o) => !o.fullWidth).toList();
    final fullWidthOption = _options.firstWhere((o) => o.fullWidth);

    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: rowOptions.map((opt) => _timeOptionCard(opt)).toList(),
        ),
        const SizedBox(height: 12),
        // Full-width Custom button
        _timeOptionCard(fullWidthOption, fullWidth: true),
      ],
    );
  }

  Widget _timeOptionCard(_TimeOption opt, {bool fullWidth = false}) {
    final isSelected = _selectedOption == opt.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOption = opt.id;
          _callScheduled = false;
        });
        if (opt.id == 'custom') _pickCustomTime(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          // Figma: selected = blue tinted, unselected = #edeeef
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.primary, width: 1.5)
              : Border.all(
                  color: AppTheme.outline.withValues(alpha: 0.15),
                  width: 1,
                ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              opt.icon,
              size: 24,
              color: isSelected ? AppTheme.primary : AppTheme.onSurfaceMid,
            ),
            const SizedBox(height: 8),
            Text(
              opt.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primary : AppTheme.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTimePicker(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickCustomTime(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text(
              _customTime != null
                  ? 'Custom: ${_customTime!.format(context)}'
                  : 'Tap to pick a time',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: _customTime != null
                    ? AppTheme.primary
                    : AppTheme.onSurfaceMid,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.onSurfaceLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledToast(BuildContext context) {
    // Figma node 1:303 — dark toast showing call scheduled
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E3132),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.phone_in_talk_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Call scheduled',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFFF0F1F2),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _scheduleLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xCCF0F1F2),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _callScheduled = false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.sosRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _customTime = picked);
    }
  }
}

class _TimeOption {
  final String id;
  final String label;
  final IconData icon;
  final bool fullWidth;

  const _TimeOption({
    required this.id,
    required this.label,
    required this.icon,
    this.fullWidth = false,
  });
}
