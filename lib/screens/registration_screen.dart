import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

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
  bool _isLoading = false;
  File? _profileImage;

  // Dynamic emergency contacts list (Figma node 1:97)
  final List<TextEditingController> _emergencyContacts = [
    TextEditingController(),
  ];

  final List<String> _bloodGroups = [
    'A+',
    'A−',
    'B+',
    'B−',
    'AB+',
    'AB−',
    'O+',
    'O−',
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  void _showImagePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(AppLocalizations.of(context)?.chooseFromGallery ?? 'Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(AppLocalizations.of(context)?.takeAPhoto ?? 'Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _createAccount() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        phone.isEmpty ||
        _selectedBloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.pleaseFillAllMandatoryFields ?? 'Please fill all mandatory fields.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final validContacts = _emergencyContacts
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (validContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.pleaseProvideAtLeastOneEmergen ?? 'Please provide at least one emergency contact.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("No authenticated user found.");
      }

      String photoUrl = user.photoURL ?? '';

      if (_profileImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child('${user.uid}.jpg');
        await ref.putFile(_profileImage!);
        photoUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'fullName': '$firstName${lastName.isNotEmpty ? ' $lastName' : ''}',
        'email': user.email ?? '',
        'phoneNumber': '+91$phone',
        'bloodGroup': _selectedBloodGroup,
        'emergencyContacts': validContacts,
        'photoUrl': photoUrl,
        'isProfileComplete': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            // Avatar picker
            GestureDetector(
              onTap: _showImagePickerBottomSheet,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.divider,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : null,
                    child: _profileImage == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: AppTheme.onSurfaceLight,
                            size: 40,
                          )
                        : null,
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(AppLocalizations.of(context)?.createYourProfile ?? 'Create your profile',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(AppLocalizations.of(context)?.setUpYourSafetyProfileSoWeCanA ?? 'Set up your safety profile so we can assist you better in an emergency.',
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
        Text(AppLocalizations.of(context)?.phoneNumber ?? 'Phone Number',
          style: GoogleFonts.inter(fontSize: 16, color: AppTheme.onSurfaceMid),
        ),
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
                    Text(AppLocalizations.of(context)?.text91 ?? '+91',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onBackground,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.onSurfaceMid,
                      size: 18,
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: AppTheme.placeholder.withValues(alpha: 0.6),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: '0000000000',
                    hintStyle: GoogleFonts.inter(
                      color: AppTheme.placeholder,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.onBackground,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Blood Group dropdown (Figma node 1:87)
        Text(AppLocalizations.of(context)?.bloodGroup ?? 'Blood Group',
          style: GoogleFonts.inter(fontSize: 16, color: AppTheme.onSurfaceMid),
        ),
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
              hint: Text(AppLocalizations.of(context)?.selectBloodGroup ?? 'Select Blood Group',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.onBackground,
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.onSurfaceMid,
              ),
              items: _bloodGroups.map((g) {
                return DropdownMenuItem(
                  value: g,
                  child: Text(
                    g,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.onBackground,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedBloodGroup = v),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Emergency Contacts (Figma node 1:97) ──────────────────────────
        Text(AppLocalizations.of(context)?.emergencyContact ?? 'Emergency Contact',
          style: GoogleFonts.inter(fontSize: 16, color: AppTheme.onSurfaceMid),
        ),
        const SizedBox(height: 8),

        ..._emergencyContacts.asMap().entries.map((entry) {
          final i = entry.key;
          final ctrl = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: i < _emergencyContacts.length - 1 ? 12 : 0,
            ),
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
                          color: AppTheme.placeholder,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppTheme.onBackground,
                      ),
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
          onPressed: _isLoading ? null : _createAccount,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(AppLocalizations.of(context)?.completeProfile ?? 'Complete Profile'),
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
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 16, color: AppTheme.onSurfaceMid),
        ),
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
                color: AppTheme.placeholder,
                fontSize: 16,
              ),
              border: InputBorder.none,
            ),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.onBackground,
            ),
          ),
        ),
      ],
    );
  }
}
