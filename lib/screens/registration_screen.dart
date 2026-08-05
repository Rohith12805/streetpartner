import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Registration Screen — Figma node 1:43
/// Fields: First Name, Last Name, Phone Number, Blood Group (dropdown), Emergency Contacts (dynamic list)
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedBloodGroup;

  // Dynamic emergency contacts list (Figma node 1:97)
  final List<TextEditingController> _emergencyContacts = [
    TextEditingController(),
  ];

  final List<String> _bloodGroups = [
    'A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−',
  ];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    for (final c in _emergencyContacts) {
      c.dispose();
    }
    super.dispose();
  }

  void _addEmergencyContact() {
    if (_emergencyContacts.length < 5) {
      setState(() => _emergencyContacts.add(TextEditingController()));
    }
  }

  void _removeEmergencyContact(int index) {
    if (_emergencyContacts.length > 1) {
      setState(() {
        _emergencyContacts[index].dispose();
        _emergencyContacts.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header (Figma node 1:46) ──────────────────────────────────
              _buildHeader(),
              const SizedBox(height: 24),

              // ── Form fields (Figma node 1:55) ─────────────────────────────
              _buildFormSection(context),

              const SizedBox(height: 32),

              // ── Actions (Figma node 1:110) ─────────────────────────────────
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button icon circle (Figma node 1:48 — blue circle)
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryLight,
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(height: 12),
        Text(
          'Create your profile',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set up your safety profile so we can assist you better in an emergency.',
          style: GoogleFonts.inter(fontSize: 16, color: AppTheme.onSurfaceMid),
        ),
      ],
    );
  }

  Widget _buildFormSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── First Name + Last Name side by side (Figma node 1:56)
        Row(
          children: [
            Expanded(
              child: _labeledField(
                label: 'First Name',
                controller: _firstNameCtrl,
                hint: 'Jane',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _labeledField(
                label: 'Last Name',
                controller: _lastNameCtrl,
                hint: 'Doe',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Phone Number with prefix (Figma node 1:73)
        Text('Phone Number',
            style: GoogleFonts.inter(
                fontSize: 16, color: AppTheme.onSurfaceMid)),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('+91',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.onBackground)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down,
                        color: AppTheme.onSurfaceMid, size: 18),
                  ],
                ),
              ),
              Container(
                  width: 1,
                  height: 28,
                  color: AppTheme.placeholder.withOpacity(0.6)),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: '(555) 000-0000',
                    hintStyle: GoogleFonts.inter(
                        color: AppTheme.placeholder, fontSize: 16),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  style: GoogleFonts.inter(
                      fontSize: 16, color: AppTheme.onBackground),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Blood Group dropdown (Figma node 1:87)
        Text('Blood Group',
            style: GoogleFonts.inter(
                fontSize: 16, color: AppTheme.onSurfaceMid)),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedBloodGroup,
              hint: Text('Select Blood Group',
                  style: GoogleFonts.inter(
                      fontSize: 16, color: AppTheme.onBackground)),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.onSurfaceMid),
              items: _bloodGroups.map((g) {
                return DropdownMenuItem(
                  value: g,
                  child: Text(g,
                      style: GoogleFonts.inter(
                          fontSize: 16, color: AppTheme.onBackground)),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedBloodGroup = v),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Emergency Contacts (Figma node 1:97) ──────────────────────────
        Text('Emergency Contact',
            style: GoogleFonts.inter(
                fontSize: 16, color: AppTheme.onSurfaceMid)),
        const SizedBox(height: 8),

        ..._emergencyContacts.asMap().entries.map((entry) {
          final i = entry.key;
          final ctrl = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: i < _emergencyContacts.length - 1 ? 12 : 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.outline),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Contact Phone Number',
                        hintStyle: GoogleFonts.inter(
                            color: AppTheme.placeholder, fontSize: 16),
                        border: InputBorder.none,
                      ),
                      style: GoogleFonts.inter(
                          fontSize: 16, color: AppTheme.onBackground),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Add button (last item) or Remove button
                if (i == _emergencyContacts.length - 1)
                  GestureDetector(
                    onTap: _addEmergencyContact,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _removeEmergencyContact(i),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        // Figma node 1:106 — #da3433 red button
                        color: AppTheme.sosRedLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        // Create Account button (Figma node 1:111 — #005bbf)
        FilledButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context, '/otp', (r) => false),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
            textStyle:
                GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          child: const Text('Create Account'),
        ),
        const SizedBox(height: 12),
        // Already have account link (Figma node 1:113)
        SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ',
                  style: GoogleFonts.inter(
                      fontSize: 16, color: AppTheme.onSurfaceMid)),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                child: Text('Log in',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _labeledField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 16, color: AppTheme.onSurfaceMid)),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                  color: AppTheme.placeholder, fontSize: 16),
              border: InputBorder.none,
            ),
            style: GoogleFonts.inter(
                fontSize: 16, color: AppTheme.onBackground),
          ),
        ),
      ],
    );
  }
}
