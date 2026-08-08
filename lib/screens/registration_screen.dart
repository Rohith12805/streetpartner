import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/user_state.dart';

/// Registration Screen — Figma node 1:43
/// Fields: Name, Phone Number, DOB, Blood Group, Email, Password, Emergency Contacts (Min 2, Max 3)
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  DateTime? _selectedDob;
  String? _selectedBloodGroup;

  late final List<Map<String, TextEditingController>> _contactCtrls;

  final List<String> _bloodGroups = [
    'A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−',
  ];

  @override
  void initState() {
    super.initState();
    _contactCtrls = [
      {
        'name': TextEditingController(text: 'Mom'),
        'relation': TextEditingController(text: 'Parent'),
        'phone': TextEditingController(text: '+15559231122'),
      },
      {
        'name': TextEditingController(text: 'Alex'),
        'relation': TextEditingController(text: 'Friend'),
        'phone': TextEditingController(text: '+15558340991'),
      },
    ];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    for (final c in _contactCtrls) {
      c['name']?.dispose();
      c['relation']?.dispose();
      c['phone']?.dispose();
    }
    super.dispose();
  }


  void _addEmergencyContact() {
    if (_contactCtrls.length < 3) {
      setState(() {
        _contactCtrls.add({
          'name': TextEditingController(),
          'relation': TextEditingController(),
          'phone': TextEditingController(),
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 emergency contacts allowed.')),
      );
    }
  }

  void _removeEmergencyContact(int index) {
    if (_contactCtrls.length > 2) {
      setState(() {
        _contactCtrls[index]['name']?.dispose();
        _contactCtrls[index]['relation']?.dispose();
        _contactCtrls[index]['phone']?.dispose();
        _contactCtrls.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum 2 emergency contacts are required for safety.')),
      );
    }
  }

  Future<void> _selectDob(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  void _onRegisterPressed() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your User Name.');
      return;
    }
    if (phone.isEmpty) {
      _showError('Please enter your Phone Number.');
      return;
    }
    if (_selectedDob == null) {
      _showError('Please select your Date of Birth.');
      return;
    }
    if (_selectedBloodGroup == null) {
      _showError('Please select your Blood Group.');
      return;
    }

    // Validate emergency contacts (Min 2 valid phone numbers)
    final validContacts = <EmergencyContact>[];
    for (final ctrlMap in _contactCtrls) {
      final cName = ctrlMap['name']?.text.trim() ?? '';
      final cRel = ctrlMap['relation']?.text.trim() ?? '';
      final cPhone = ctrlMap['phone']?.text.trim() ?? '';

      if (cPhone.isNotEmpty) {
        validContacts.add(EmergencyContact(
          name: cName.isEmpty ? 'Contact ${validContacts.length + 1}' : cName,
          relation: cRel.isEmpty ? 'Guardian' : cRel,
          phone: cPhone,
        ));
      }
    }

    if (validContacts.length < 2) {
      _showError('Please enter at least 2 valid Emergency Contact Phone Numbers.');
      return;
    }

    final pass = _passwordCtrl.text.trim();
    final dobStr = '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}';
    
    final err = UserState.instance.registerUser(
      fullName: name,
      email: email,
      password: pass.isEmpty ? 'password123' : pass,
      mobileNumber: phone.startsWith('+') ? phone : '+91$phone',
      dateOfBirth: dobStr,
      bloodGroup: _selectedBloodGroup!,
      emergencyContacts: validContacts,
    );

    if (err != null) {
      _showError(err);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account registered for $email! Please log in.'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }


  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.sosRed),
    );
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
              _buildHeader(),
              const SizedBox(height: 24),
              _buildFormSection(context),
              const SizedBox(height: 32),
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
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryLight,
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Create Your Safety Profile',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Fill in your basic details and add 2 to 3 emergency contacts for instant SOS alert delivery.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurfaceMid, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildFormSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Full Name / User Name
        _labeledField(
          label: 'User Name / Full Name',
          controller: _nameCtrl,
          hint: 'Alex Mercer',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 16),

        // ── Phone Number
        Text('Phone Number',
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceMid)),
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
                child: Text('+91',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onBackground)),
              ),
              Container(width: 1, height: 28, color: AppTheme.outline),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle: GoogleFonts.inter(color: AppTheme.placeholder, fontSize: 16),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  style: GoogleFonts.inter(fontSize: 16, color: AppTheme.onBackground),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Date of Birth & Blood Group side-by-side
        Row(
          children: [
            // Date of birth picker
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date of Birth',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceMid)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _selectDob(context),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outline),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDob == null
                                  ? 'YYYY-MM-DD'
                                  : '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _selectedDob == null ? AppTheme.placeholder : AppTheme.onBackground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Blood group dropdown
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Blood Group',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceMid)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBloodGroup,

                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.outline),
                      ),
                    ),
                    hint: Text('Select',
                        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.placeholder)),
                    items: _bloodGroups.map((g) {
                      return DropdownMenuItem(
                        value: g,
                        child: Text(g, style: GoogleFonts.inter(fontSize: 15, color: AppTheme.onBackground)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedBloodGroup = v),
                  ),
                ],
              ),
            ),

          ],
        ),
        const SizedBox(height: 16),

        // ── Email & Password
        _labeledField(
          label: 'Email Address',
          controller: _emailCtrl,
          hint: 'alex@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _labeledField(
          label: 'Password',
          controller: _passwordCtrl,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
        ),
        const SizedBox(height: 24),

        // ── Emergency Contacts Section Header (Min 2, Max 3)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Contacts',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.onBackground),
                  ),
                  Text(
                    'Min 2, Max 3 contacts required',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceMid),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_contactCtrls.length < 3)
              OutlinedButton.icon(
                onPressed: _addEmergencyContact,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        ..._contactCtrls.asMap().entries.map((entry) {
          final idx = entry.key;
          final map = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Emergency Contact #${idx + 1}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                    ),
                    if (_contactCtrls.length > 2)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.sosRed, size: 20),
                        onPressed: () => _removeEmergencyContact(idx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: map['name'],
                        decoration: InputDecoration(
                          hintText: 'Contact Name',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.placeholder),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: map['relation'],
                        decoration: InputDecoration(
                          hintText: 'Relation (Sister, Friend)',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.placeholder),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: map['phone'],
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Phone Number (+15550001111)',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.placeholder),
                    isDense: true,
                    prefixIcon: const Icon(Icons.phone_rounded, size: 16),
                    border: const OutlineInputBorder(),
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
        FilledButton(
          onPressed: _onRegisterPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
            textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: const Text('Complete Registration & Save'),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already registered? ',
                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurfaceMid)),
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
              child: Text('Log in',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        ),
      ],
    );
  }

  Widget _labeledField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceMid)),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              icon: Icon(icon, color: AppTheme.onSurfaceMid, size: 20),
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: AppTheme.placeholder, fontSize: 15),
              border: InputBorder.none,
            ),
            style: GoogleFonts.inter(fontSize: 15, color: AppTheme.onBackground),
          ),
        ),
      ],
    );
  }
}

