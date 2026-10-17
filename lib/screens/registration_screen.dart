import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/sheild_brand_text.dart';

/// Modern 3-Step Profile Onboarding Flow:
/// Step 1: Personal Details (First Name, Last Name, Phone, Verified Email)
/// Step 2: Medical Information (Blood Group, Optional Medical Notes)
/// Step 3: Emergency Contacts (1-5 Contacts, Add/Remove, Validation)
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSaving = false;

  // ── Step 1: Personal Details ──
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _firstNameError;
  String? _lastNameError;
  String? _phoneError;

  // ── Step 2: Medical Information ──
  String? _selectedBloodGroup;
  final _medicalNotesCtrl = TextEditingController();
  String? _bloodGroupError;

  final List<String> _bloodGroups = const [
    'A+',
    'A−',
    'B+',
    'B−',
    'AB+',
    'AB−',
    'O+',
    'O−',
  ];

  // ── Step 3: Emergency Contacts ──
  final List<TextEditingController> _emergencyContacts = [
    TextEditingController(),
  ];
  String? _contactsError;

  @override
  void initState() {
    super.initState();
    // Pre-populate first name and last name from Google Account if available
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
      final parts = currentUser.displayName!.trim().split(' ');
      if (parts.isNotEmpty) {
        _firstNameCtrl.text = parts.first;
        if (parts.length > 1) {
          _lastNameCtrl.text = parts.sublist(1).join(' ');
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _medicalNotesCtrl.dispose();
    for (final c in _emergencyContacts) {
      c.dispose();
    }
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  // ── Validation for Step 1 ──
  bool _validateStep1() {
    bool isValid = true;
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    setState(() {
      if (first.isEmpty) {
        _firstNameError = 'Please enter your first name';
        isValid = false;
      } else if (first.length < 2) {
        _firstNameError = 'Name must be at least 2 characters';
        isValid = false;
      } else {
        _firstNameError = null;
      }

      if (last.isEmpty) {
        _lastNameError = 'Please enter your last name';
        isValid = false;
      } else {
        _lastNameError = null;
      }

      if (phone.isEmpty) {
        _phoneError = 'Please enter your 10-digit mobile number';
        isValid = false;
      } else if (phone.length != 10) {
        _phoneError = 'Phone number must be exactly 10 digits';
        isValid = false;
      } else {
        _phoneError = null;
      }
    });

    return isValid;
  }

  // ── Validation for Step 2 ──
  bool _validateStep2() {
    if (_selectedBloodGroup == null) {
      setState(() {
        _bloodGroupError = 'Please select your blood group';
      });
      return false;
    }
    setState(() => _bloodGroupError = null);
    return true;
  }

  // ── Emergency Contacts List Helpers ──
  void _addEmergencyContact() {
    if (_emergencyContacts.length < 5) {
      setState(() {
        _emergencyContacts.add(TextEditingController());
        _contactsError = null;
      });
    }
  }

  void _removeEmergencyContact(int index) {
    if (_emergencyContacts.length > 1) {
      setState(() {
        _emergencyContacts[index].dispose();
        _emergencyContacts.removeAt(index);
        _contactsError = null;
      });
    }
  }

  // ── Validation for Step 3 ──
  List<String>? _validateStep3() {
    final validContacts = <String>[];
    for (int i = 0; i < _emergencyContacts.length; i++) {
      final text = _emergencyContacts[i].text.trim();
      if (text.isNotEmpty) {
        if (text.length != 10) {
          setState(() {
            _contactsError = 'Contact #${i + 1} must be a valid 10-digit phone number.';
          });
          return null;
        }
        validContacts.add(text);
      }
    }

    if (validContacts.isEmpty) {
      setState(() {
        _contactsError = 'Please provide at least one emergency contact.';
      });
      return null;
    }

    // Check for duplicate contact numbers
    final uniqueContacts = validContacts.toSet();
    if (uniqueContacts.length != validContacts.length) {
      setState(() {
        _contactsError = 'Duplicate emergency contact numbers are not allowed.';
      });
      return null;
    }

    setState(() => _contactsError = null);
    return validContacts;
  }

  // ── Complete Profile & Save to Firebase ──
  Future<void> _completeProfile() async {
    final validContacts = _validateStep3();
    if (validContacts == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('No authenticated user found. Please sign in again.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final fullName = '$firstName ${lastName.isNotEmpty ? lastName : ''}'.trim();
      final medicalNotes = _medicalNotesCtrl.text.trim();
      final photoUrl = user.photoURL ?? '';

      // 1. Write profile to Cloud Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'fullName': fullName,
        'email': user.email ?? '',
        'phoneNumber': '+91$phone',
        'bloodGroup': _selectedBloodGroup,
        'medicalNotes': medicalNotes,
        'emergencyContacts': validContacts,
        'photoUrl': photoUrl,
        'isProfileComplete': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Cache contacts and completion status in SharedPreferences for SOS & offline access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cached_emergency_contacts', validContacts);
      await prefs.setBool('is_profile_complete_${user.uid}', true);

      // 3. Navigate to existing dashboard
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar('Failed to save profile: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? AppTheme.sosRed : Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 0) {
          _goToStep(_currentStep - 1);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              // ── Step Progress Indicator ──
              _buildProgressHeader(),

              // ── 3-Step PageView ──
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1PersonalDetails(),
                    _buildStep2MedicalInfo(),
                    _buildStep3EmergencyContacts(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (_currentStep > 0) {
            _goToStep(_currentStep - 1);
          } else {
            Navigator.maybePop(context);
          }
        },
      ),
      title: const SheildBrandText(fontSize: 20),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              'Step ${_currentStep + 1} of 3',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(3, (index) {
          final isCompleted = _currentStep > index;
          final isCurrent = _currentStep == index;
          return Expanded(
            child: Container(
              height: 5,
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == 2 ? 0 : 4,
              ),
              decoration: BoxDecoration(
                color: isCompleted || isCurrent
                    ? AppTheme.primary
                    : const Color(0xFFD8E2FF).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 1: PERSONAL DETAILS
  // ===========================================================================
  Widget _buildStep1PersonalDetails() {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'No email linked';

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Let's get to know you",
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.onBackground,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your basic details to personalize your safety profile.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceMid,
            ),
          ),
          const SizedBox(height: 20),

          // Google Verified Account Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: AppTheme.green,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signed in via Google',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onSurfaceLight,
                        ),
                      ),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onBackground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Verified',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // First Name Field
          _buildFormField(
            label: 'First Name *',
            hint: 'e.g. Jane',
            controller: _firstNameCtrl,
            errorText: _firstNameError,
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),

          // Last Name Field
          _buildFormField(
            label: 'Last Name *',
            hint: 'e.g. Doe',
            controller: _lastNameCtrl,
            errorText: _lastNameError,
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),

          // Phone Number Field (+91)
          Text(
            'Phone Number *',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _phoneError != null ? AppTheme.sosRed : const Color(0xFFDADCE0),
                width: _phoneError != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Text(
                        '🇮🇳 +91',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onBackground,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.onSurfaceMid,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: '10-digit mobile number',
                      hintStyle: GoogleFonts.inter(
                        color: AppTheme.placeholder,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onBackground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_phoneError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                _phoneError!,
                style: GoogleFonts.inter(
                  color: AppTheme.sosRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const SizedBox(height: 36),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () {
                if (_validateStep1()) {
                  _goToStep(1);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 2,
                shadowColor: AppTheme.primary.withValues(alpha: 0.35),
              ),
              child: Text(
                'Continue →',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SCREEN 2: MEDICAL INFORMATION
  // ===========================================================================
  Widget _buildStep2MedicalInfo() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your health information',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.onBackground,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'These details may help your trusted contacts assist you in an emergency.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceMid,
            ),
          ),
          const SizedBox(height: 20),

          // Privacy Reassurance Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5FE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryContainer.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Provide only information you are comfortable sharing. Medical notes are optional and strictly shared only during active SOS situations.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppTheme.onSurfaceMid,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Blood Group Dropdown
          Text(
            'Blood Group *',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _bloodGroupError != null ? AppTheme.sosRed : const Color(0xFFDADCE0),
                width: _bloodGroupError != null ? 1.5 : 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedBloodGroup,
                hint: Text(
                  'Select Blood Group',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.placeholder,
                  ),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.onSurfaceMid,
                ),
                items: _bloodGroups.map((g) {
                  return DropdownMenuItem(
                    value: g,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bloodtype_outlined,
                          color: AppTheme.sosRed,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          g,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onBackground,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedBloodGroup = v;
                    _bloodGroupError = null;
                  });
                },
              ),
            ),
          ),
          if (_bloodGroupError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                _bloodGroupError!,
                style: GoogleFonts.inter(
                  color: AppTheme.sosRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Optional Medical Notes
          Text(
            'Medical Notes (Optional)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDADCE0)),
            ),
            child: TextField(
              controller: _medicalNotesCtrl,
              maxLines: 4,
              maxLength: 250,
              decoration: InputDecoration(
                hintText: 'e.g. Allergies to penicillin, asthma, diabetes, daily medications, or medical devices...',
                hintStyle: GoogleFonts.inter(
                  color: AppTheme.placeholder,
                  fontSize: 14,
                  height: 1.4,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.onBackground,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Back & Continue Buttons
          Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => _goToStep(0),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.onBackground,
                      side: const BorderSide(color: Color(0xFFDADCE0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      if (_validateStep2()) {
                        _goToStep(2);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 2,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.35),
                    ),
                    child: Text(
                      'Continue →',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SCREEN 3: EMERGENCY CONTACTS
  // ===========================================================================
  Widget _buildStep3EmergencyContacts() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your trusted contacts',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.onBackground,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose people you trust who can support you in an emergency.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.onSurfaceMid,
            ),
          ),
          const SizedBox(height: 20),

          // Info Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5FE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryContainer.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.phone_in_talk_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add between 1 and 5 trusted contacts. When SOS triggers, they receive emergency SMS alerts with your real-time location.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppTheme.onSurfaceMid,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Contacts List
          ..._emergencyContacts.asMap().entries.map((entry) {
            final index = entry.key;
            final ctrl = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Emergency Contact #${index + 1} *',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onBackground,
                        ),
                      ),
                      if (_emergencyContacts.length > 1)
                        GestureDetector(
                          onTap: () => _removeEmergencyContact(index),
                          child: Text(
                            'Remove',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.sosRed,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDADCE0)),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '🇮🇳 +91',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onBackground,
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          color: const Color(0xFFE2E8F0),
                        ),
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: InputDecoration(
                              hintText: '10-digit mobile number',
                              hintStyle: GoogleFonts.inter(
                                color: AppTheme.placeholder,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.onBackground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          // Add Another Contact Button (up to 5 contacts)
          if (_emergencyContacts.length < 5)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: OutlinedButton.icon(
                onPressed: _addEmergencyContact,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: Text(
                  'Add Another Contact (${_emergencyContacts.length}/5)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ),

          if (_contactsError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                _contactsError!,
                style: GoogleFonts.inter(
                  color: AppTheme.sosRed,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          const SizedBox(height: 32),

          // Back & Complete Profile Buttons
          Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _goToStep(1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.onBackground,
                      side: const BorderSide(color: Color(0xFFDADCE0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _completeProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 2,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.35),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Complete Profile',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helper Form Field Widget ──
  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? errorText,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null ? AppTheme.sosRed : const Color(0xFFDADCE0),
              width: errorText != null ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (prefixIcon != null)
                Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    prefixIcon,
                    color: AppTheme.onSurfaceLight,
                    size: 20,
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.inter(
                      color: AppTheme.placeholder,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: prefixIcon == null ? 16 : 4,
                    ),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onBackground,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText,
              style: GoogleFonts.inter(
                color: AppTheme.sosRed,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
