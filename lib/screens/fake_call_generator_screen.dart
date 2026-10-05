import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/fake_call.dart';
import '../services/fake_call_service.dart';
import '../theme/app_theme.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

class FakeCallGeneratorScreen extends StatefulWidget {
  const FakeCallGeneratorScreen({super.key});

  @override
  State<FakeCallGeneratorScreen> createState() =>
      _FakeCallGeneratorScreenState();
}

class _FakeCallGeneratorScreenState extends State<FakeCallGeneratorScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Mom');
  final TextEditingController _phoneController =
      TextEditingController(text: '9876543210');

  String _selectedVoiceLanguage = 'en';

  String? _selectedQuickOption; // '10s', '30s', '1m', '5m', 'custom'
  DateTime? _customDate;
  TimeOfDay? _customTime;

  List<FakeCall> _upcomingCalls = [];
  bool _isLoading = true;

  StreamSubscription<FakeCall>? _incomingCallSub;

  final List<_QuickTimeOption> _quickOptions = [
    const _QuickTimeOption(
      id: '10s',
      label: '10 Seconds',
      duration: Duration(seconds: 10),
      icon: Icons.flash_on_rounded,
    ),
    const _QuickTimeOption(
      id: '30s',
      label: '30 Seconds',
      duration: Duration(seconds: 30),
      icon: Icons.timer_outlined,
    ),
    const _QuickTimeOption(
      id: '1m',
      label: '1 Minute',
      duration: Duration(minutes: 1),
      icon: Icons.looks_one_outlined,
    ),
    const _QuickTimeOption(
      id: '5m',
      label: '5 Minutes',
      duration: Duration(minutes: 5),
      icon: Icons.timer_outlined,
    ),
    const _QuickTimeOption(
      id: 'custom',
      label: 'Custom Date & Time',
      duration: null,
      icon: Icons.tune_rounded,
      fullWidth: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadScheduledCalls();
    _subscribeToIncomingCalls();
  }

  void _subscribeToIncomingCalls() {
    _incomingCallSub =
        FakeCallService.instance.onIncomingCall.listen((fakeCall) {
      if (!mounted) return;
      _loadScheduledCalls();
    });
  }

  Future<void> _loadScheduledCalls() async {
    final calls = await FakeCallService.instance.getCalls();
    if (mounted) {
      setState(() {
        _upcomingCalls = calls;
        _isLoading = false;
      });
    }
  }

  DateTime? _calculateScheduledDateTime() {
    if (_selectedQuickOption == null) return null;

    if (_selectedQuickOption == 'custom') {
      if (_customDate == null || _customTime == null) return null;
      return DateTime(
        _customDate!.year,
        _customDate!.month,
        _customDate!.day,
        _customTime!.hour,
        _customTime!.minute,
      );
    } else {
      final opt = _quickOptions.firstWhere((o) => o.id == _selectedQuickOption);
      if (opt.duration == null) return null;
      return DateTime.now().add(opt.duration!);
    }
  }

  void _onScheduleCallPressed() async {
    final callerName = _nameController.text.trim();
    final phoneNumber = _phoneController.text.trim();

    // 1. Validate Caller Name
    if (callerName.isEmpty) {
      _showErrorSnackBar('Please enter a caller name.');
      return;
    }

    // 2. Validate Selection & Schedule Date/Time
    if (_selectedQuickOption == null) {
      _showErrorSnackBar('Please select a delay time or custom date/time.');
      return;
    }

    final scheduledDateTime = _calculateScheduledDateTime();
    if (scheduledDateTime == null) {
      if (_selectedQuickOption == 'custom') {
        _showErrorSnackBar('Please select both a date and time.');
      } else {
        _showErrorSnackBar('Invalid schedule selection.');
      }
      return;
    }

    // 3. Prevent scheduling in the past
    if (scheduledDateTime.isBefore(DateTime.now())) {
      _showErrorSnackBar('Scheduled time cannot be in the past.');
      return;
    }

    // 4. Check & request notification permission
    await FakeCallService.instance.requestPermissions();

    // 5. Create & Save Fake Call
    final newCall = FakeCall(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      callerName: callerName,
      phoneNumber: phoneNumber.isEmpty ? null : phoneNumber,
      scheduledDateTime: scheduledDateTime,
      status: FakeCallStatus.scheduled,
      voiceLanguage: _selectedVoiceLanguage,
    );

    await FakeCallService.instance.saveCall(newCall);

    // 6. Refresh List & Show Success Message
    await _loadScheduledCalls();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Fake call scheduled for ${newCall.formattedDisplayString}',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _onDeleteCall(FakeCall call) async {
    await FakeCallService.instance.deleteCall(call.id);
    await _loadScheduledCalls();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cancelled fake call from "${call.callerName}"',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: AppTheme.onSurfaceMid,
      ),
    );
  }

  void _onEditCall(FakeCall call) {
    final editNameController = TextEditingController(text: call.callerName);
    final editPhoneController =
        TextEditingController(text: call.phoneNumber ?? '');

    DateTime selectedDate = call.scheduledDateTime;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(call.scheduledDateTime);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(AppLocalizations.of(context)?.editScheduledFakeCall ?? 'Edit Scheduled Fake Call',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: editNameController,
                      decoration: AppTheme.inputDecoration(
                        label: 'Caller Name',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: AppTheme.inputDecoration(
                        label: 'Phone Number (Optional)',
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_rounded,
                            color: AppTheme.primary),
                        title: Text(
                          'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Text(AppLocalizations.of(context)?.change ?? 'Change'),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time_rounded,
                            color: AppTheme.primary),
                        title: Text(
                          'Time: ${selectedTime.format(ctx)}',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedTime = picked;
                              });
                            }
                          },
                          child: Text(AppLocalizations.of(context)?.change ?? 'Change'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(AppLocalizations.of(context)?.cancel ?? 'CANCEL'),
                ),
                FilledButton(
                  onPressed: () async {
                    final newName = editNameController.text.trim();
                    if (newName.isEmpty) {
                      _showErrorSnackBar('Caller name cannot be empty.');
                      return;
                    }

                    final updatedDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    if (updatedDateTime.isBefore(DateTime.now())) {
                      _showErrorSnackBar('Scheduled time cannot be in the past.');
                      return;
                    }

                    final updatedCall = call.copyWith(
                      callerName: newName,
                      phoneNumber: editPhoneController.text.trim().isEmpty
                          ? null
                          : editPhoneController.text.trim(),
                      scheduledDateTime: updatedDateTime,
                      status: FakeCallStatus.scheduled,
                    );

                    await FakeCallService.instance.updateCall(updatedCall);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      _loadScheduledCalls();
                    }
                  },
                  child: Text(AppLocalizations.of(context)?.save ?? 'SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.sosRed,
      ),
    );
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
                Icons.phone_in_talk_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)?.fakeCallGenerator ?? 'Fake Call Generator',
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
                  const SizedBox(height: 8),

                  // Header card
                  Text(AppLocalizations.of(context)?.fakeCallSchedule ?? 'Fake Call Schedule',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(AppLocalizations.of(context)?.scheduleASimulatedCallToSafely ?? 'Schedule a simulated call to safely exit uncomfortable situations.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.onSurfaceMid,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Caller Information Input Section ────────────────────────
                  Text(AppLocalizations.of(context)?.callerInformation ?? 'Caller Information',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: AppTheme.inputDecoration(
                      label: 'Caller Name *',
                      hint: 'e.g. Mom, Boss, Friend',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: AppTheme.inputDecoration(
                      label: 'Phone Number (Optional)',
                      hint: 'e.g. 9876543210',
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedVoiceLanguage,
                    isExpanded: true,
                    decoration: AppTheme.inputDecoration(
                      label: 'Voice Language',
                      hint: 'Select incoming call voice language',
                      prefixIcon: const Icon(Icons.record_voice_over_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'hi', child: Text('हिंदी (Hindi)')),
                      DropdownMenuItem(value: 'te', child: Text('తెలుగు (Telugu)')),
                      DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)')),
                      DropdownMenuItem(value: 'ml', child: Text('മലയാളം (Malayalam)')),
                      DropdownMenuItem(value: 'kn', child: Text('ಕನ್ನಡ (Kannada)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedVoiceLanguage = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Delay Time / Schedule Section ─────────────────────────
                  Text(AppLocalizations.of(context)?.selectDelaySchedule ?? 'Select Delay / Schedule',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildQuickOptionsGrid(context),

                  // Custom date & time pickers if 'custom' is selected
                  if (_selectedQuickOption == 'custom') ...[
                    const SizedBox(height: 16),
                    _buildCustomDateTimeSelectors(context),
                  ],

                  const SizedBox(height: 28),

                  // ── Upcoming Fake Calls Section ───────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)?.upcomingFakeCalls ?? 'Upcoming Fake Calls',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onBackground,
                        ),
                      ),
                      if (_upcomingCalls.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_upcomingCalls.length}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildUpcomingCallsList(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Schedule Call Button ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: FilledButton.icon(
              onPressed: _onScheduleCallPressed,
              icon: const Icon(Icons.phone_callback_rounded, size: 20),
              label: Text(AppLocalizations.of(context)?.scheduleFakeCall ?? 'Schedule Fake Call'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
                textStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOptionsGrid(BuildContext context) {
    final rowOptions = _quickOptions.where((o) => !o.fullWidth).toList();
    final fullWidthOption = _quickOptions.firstWhere((o) => o.fullWidth);

    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: rowOptions.map((opt) => _quickOptionCard(opt)).toList(),
        ),
        const SizedBox(height: 12),
        _quickOptionCard(fullWidthOption, fullWidth: true),
      ],
    );
  }

  Widget _quickOptionCard(_QuickTimeOption opt, {bool fullWidth = false}) {
    final isSelected = _selectedQuickOption == opt.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedQuickOption = opt.id;
        });
        if (opt.id == 'custom') {
          _pickCustomDate(context);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.primary, width: 2)
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
              size: 22,
              color: isSelected ? AppTheme.primary : AppTheme.onSurfaceMid,
            ),
            const SizedBox(height: 6),
            Text(
              opt.label,
              style: GoogleFonts.inter(
                fontSize: 13,
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

  Widget _buildCustomDateTimeSelectors(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _pickCustomDate(context),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  _customDate != null
                      ? 'Date: ${_customDate!.day}/${_customDate!.month}/${_customDate!.year}'
                      : 'Tap to select Date',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _customDate != null
                        ? AppTheme.primary
                        : AppTheme.onSurfaceMid,
                    fontWeight: _customDate != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.onSurfaceLight),
              ],
            ),
          ),
          const Divider(height: 24),
          InkWell(
            onTap: () => _pickCustomTime(context),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  _customTime != null
                      ? 'Time: ${_customTime!.format(context)}'
                      : 'Tap to select Time',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _customTime != null
                        ? AppTheme.primary
                        : AppTheme.onSurfaceMid,
                    fontWeight: _customTime != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.onSurfaceLight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingCallsList(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_upcomingCalls.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            const Icon(Icons.phone_missed_rounded,
                size: 36, color: AppTheme.placeholder),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)?.noUpcomingFakeCallsScheduled ?? 'No upcoming fake calls scheduled',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.onSurfaceLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _upcomingCalls.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final call = _upcomingCalls[index];
        final isScheduled = call.status == FakeCallStatus.scheduled;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isScheduled
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : AppTheme.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryContainer,
                        child: Text(
                          call.callerName.isNotEmpty
                              ? call.callerName[0].toUpperCase()
                              : 'C',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            call.callerName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onBackground,
                            ),
                          ),
                          if (call.phoneNumber != null &&
                              call.phoneNumber!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              call.phoneNumber!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.onSurfaceMid,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isScheduled
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isScheduled ? 'Scheduled' : call.status.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isScheduled
                            ? const Color(0xFF15803D)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 16, color: AppTheme.onSurfaceLight),
                  const SizedBox(width: 6),
                  Text(
                    call.formattedDisplayString,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurfaceMid,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isScheduled) ...[
                    OutlinedButton.icon(
                      onPressed: () => _onEditCall(call),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(AppLocalizations.of(context)?.edit ?? 'Edit'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(80, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton.icon(
                    onPressed: () => _onDeleteCall(call),
                    icon: const Icon(Icons.cancel_outlined,
                        size: 16, color: AppTheme.sosRed),
                    label: Text(AppLocalizations.of(context)?.cancel1 ?? 'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.sosRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickCustomDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _customDate = picked);
      if (_customTime == null && context.mounted) {
        _pickCustomTime(context);
      }
    }
  }

  Future<void> _pickCustomTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _customTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _customTime = picked);
    }
  }
}

class _QuickTimeOption {
  final String id;
  final String label;
  final Duration? duration;
  final IconData icon;
  final bool fullWidth;

  const _QuickTimeOption({
    required this.id,
    required this.label,
    required this.duration,
    required this.icon,
    this.fullWidth = false,
  });
}
