import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../services/user_state.dart';

/// Clean, responsive Authentication Screen with Tabbed View Switching
/// between Login Form and Registration Form.
class LoginScreen extends StatefulWidget {
  final bool initialIsRegister;
  const LoginScreen({super.key, this.initialIsRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _isRegisterTab;

  // Login Controllers
  final _loginEmailCtrl = TextEditingController(text: 'alex@example.com');
  final _loginPassCtrl = TextEditingController(text: 'password123');

  // Register Controllers
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regMobileCtrl = TextEditingController();

  DateTime? _selectedDob;
  String? _selectedBloodGroup;

  // Emergency contacts list (Enforces Min 2, Max 3)
  late final List<Map<String, TextEditingController>> _contactCtrls;

  final List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  @override
  void initState() {
    super.initState();
    _isRegisterTab = widget.initialIsRegister;
    _contactCtrls = [
      {
        'name': TextEditingController(text: 'Sarah Mercer'),
        'phone': TextEditingController(text: '+919876543211'),
      },
      {
        'name': TextEditingController(text: 'David Chen'),
        'phone': TextEditingController(text: '+919876543212'),
      },
    ];
  }

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regMobileCtrl.dispose();
    for (final c in _contactCtrls) {
      c['name']?.dispose();
      c['phone']?.dispose();
    }
    super.dispose();
  }

  void _addEmergencyContact() {
    if (_contactCtrls.length < 3) {
      setState(() {
        _contactCtrls.add({
          'name': TextEditingController(),
          'phone': TextEditingController(),
        });
      });
    }
  }

  void _removeEmergencyContact(int index) {
    if (_contactCtrls.length > 2) {
      setState(() {
        _contactCtrls[index]['name']?.dispose();
        _contactCtrls[index]['phone']?.dispose();
        _contactCtrls.removeAt(index);
      });
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

  void _handleLogin() {
    final email = _loginEmailCtrl.text.trim();
    final pass = _loginPassCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _showSnackBar('Please fill in both Email Address and Password.', isError: true);
      return;
    }

    final err = UserState.instance.loginUser(email: email, password: pass);
    if (err != null) {
      _showSnackBar(err, isError: true);
    } else {
      _showSnackBar('Login Successful! Welcome back.', isError: false);
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _handleRegistration() {
    final name = _regNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final pass = _regPassCtrl.text.trim();
    final mobile = _regMobileCtrl.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Please enter your Full Name.', isError: true);
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid Email Address.', isError: true);
      return;
    }
    if (pass.isEmpty || pass.length < 4) {
      _showSnackBar('Password must be at least 4 characters.', isError: true);
      return;
    }
    if (mobile.isEmpty) {
      _showSnackBar('Please enter your Mobile Number.', isError: true);
      return;
    }
    if (_selectedDob == null) {
      _showSnackBar('Please select your Date of Birth.', isError: true);
      return;
    }
    if (_selectedBloodGroup == null) {
      _showSnackBar('Please select your Blood Group.', isError: true);
      return;
    }

    // Validate emergency contacts (Min 2, Max 3)
    final validContacts = <EmergencyContact>[];
    for (final ctrlMap in _contactCtrls) {
      final cName = ctrlMap['name']?.text.trim() ?? '';
      final cPhone = ctrlMap['phone']?.text.trim() ?? '';
      if (cName.isNotEmpty && cPhone.isNotEmpty) {
        validContacts.add(EmergencyContact(name: cName, relation: 'Emergency', phone: cPhone));
      }
    }

    if (validContacts.length < 2) {
      _showSnackBar('Please fill in at least 2 Emergency Contacts (Name & Mobile Number).', isError: true);
      return;
    }

    final dobStr = '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}';
    final err = UserState.instance.registerUser(
      fullName: name,
      email: email,
      password: pass,
      mobileNumber: mobile,
      dateOfBirth: dobStr,
      bloodGroup: _selectedBloodGroup!,
      emergencyContacts: validContacts,
    );

    if (err != null) {
      _showSnackBar(err, isError: true);
    } else {
      _showSnackBar('Account registered for $email! Please click Sign In.', isError: false);
      setState(() {
        _loginEmailCtrl.text = email;
        _loginPassCtrl.text = pass;
        _isRegisterTab = false;
      });
    }
  }


  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? AppTheme.sosRed : Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background top gradient decoration
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.15),
                    AppTheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      _buildHeaderLogo(),
                      const SizedBox(height: 24),
                      _buildTabSwitcher(),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isRegisterTab ? _buildRegisterForm() : _buildLoginForm(),
                      ),
                      const SizedBox(height: 24),
                      _buildLegalFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
              ),
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'SafeGuard Security',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.onBackground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Proactive Protection & SOS Emergency Network',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceMid),
        ),
      ],
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isRegisterTab = false),
              child: Container(
                decoration: BoxDecoration(
                  color: !_isRegisterTab ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: !_isRegisterTab
                      ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 4)]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Sign In',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: !_isRegisterTab ? Colors.white : AppTheme.onSurfaceMid,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isRegisterTab = true),
              child: Container(
                decoration: BoxDecoration(
                  color: _isRegisterTab ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: _isRegisterTab
                      ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 4)]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Register',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _isRegisterTab ? Colors.white : AppTheme.onSurfaceMid,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      key: const ValueKey('login_form'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome Back',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onBackground)),
          Text('Sign in to access your security dashboard',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceMid)),
          const SizedBox(height: 20),

          // Email Field
          _inputField(
            label: 'Email Address',
            controller: _loginEmailCtrl,
            hint: 'alex@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // Password Field
          _inputField(
            label: 'Password',
            controller: _loginPassCtrl,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _handleLogin,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: Text('Sign In', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account? ", style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurfaceMid)),
              GestureDetector(
                onTap: () => setState(() => _isRegisterTab = true),
                child: Text('Register Now',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    final canAddMore = _contactCtrls.length < 3;
    final canRemove = _contactCtrls.length > 2;

    return Container(
      key: const ValueKey('register_form'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Account',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onBackground)),
          Text('Register basic details & emergency contacts',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceMid)),
          const SizedBox(height: 20),

          // Full Name
          _inputField(
            label: 'Full Name',
            controller: _regNameCtrl,
            hint: 'Alex Mercer',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),

          // Email Address
          _inputField(
            label: 'Email Address',
            controller: _regEmailCtrl,
            hint: 'alex@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          // Password
          _inputField(
            label: 'Password',
            controller: _regPassCtrl,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
          const SizedBox(height: 14),

          // Mobile Number
          _inputField(
            label: 'Mobile Number',
            controller: _regMobileCtrl,
            hint: '+919876543210',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),

          // Date of Birth & Blood Group Row
          Row(
            children: [
              // Date Picker Field
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date of Birth',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceMid)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _selectDob(context),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _selectedDob == null
                                    ? 'YYYY-MM-DD'
                                    : '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
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
              const SizedBox(width: 10),
              // Blood Group Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Blood Group',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceMid)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBloodGroup,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        fillColor: AppTheme.surfaceVariant,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      hint: Text('Select', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.placeholder)),
                      items: _bloodGroups.map((g) {
                        return DropdownMenuItem(
                          value: g,
                          child: Text(g, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onBackground)),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedBloodGroup = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emergency Contacts',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.onBackground)),
                    Text('Min 2, Max 3 contacts required',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceMid)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: canAddMore ? _addEmergencyContact : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: canAddMore ? AppTheme.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: canAddMore ? Colors.white : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Add Contact',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: canAddMore ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ..._contactCtrls.asMap().entries.map((entry) {
            final idx = entry.key;
            final map = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Contact #${idx + 1}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: canRemove ? AppTheme.sosRed : Colors.grey.shade400,
                          size: 20,
                        ),
                        onPressed: canRemove ? () => _removeEmergencyContact(idx) : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: map['name'],
                          decoration: InputDecoration(
                            hintText: 'Contact Name',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.placeholder),
                            isDense: true,
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: map['phone'],
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'Mobile Number',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.placeholder),
                            isDense: true,
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: _handleRegistration,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: Text('Complete Registration', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already registered? ', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurfaceMid)),
              GestureDetector(
                onTap: () => setState(() => _isRegisterTab = false),
                child: Text('Sign In',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inputField({
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
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceMid)),
        const SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              icon: Icon(icon, color: AppTheme.onSurfaceMid, size: 18),
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: AppTheme.placeholder, fontSize: 14),
              border: InputBorder.none,
            ),
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onBackground),
          ),
        ),
      ],
    );
  }

  Widget _buildLegalFooter() {
    return Text(
      'By signing in or registering, you agree to SafeGuard Terms & Privacy Policy.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceLight),
    );
  }
}
