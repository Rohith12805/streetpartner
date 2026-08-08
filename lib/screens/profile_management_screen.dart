import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/user_state.dart';

/// Profile Management Screen — Figma node 1:253
/// AppBar with back arrow, editable profile fields, emergency contacts, Update + Logout buttons
class ProfileManagementScreen extends StatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  State<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  late String _userName;
  late String _phone;
  late String _dob;
  late String _bloodGroup;
  late List<EmergencyContact> _contacts;

  @override
  void initState() {
    super.initState();
    final user = UserState.instance;
    _userName = user.name;
    _phone = user.phone;
    _dob = user.dateOfBirth;
    _bloodGroup = user.bloodGroup;
    _contacts = List.from(user.emergencyContacts);
  }

  void _saveProfileChanges() {
    UserState.instance.updateUserProfile(
      newName: _userName,
      newPhone: _phone,
      newEmail: UserState.instance.email,
      newDob: _dob,
      newBloodGroup: _bloodGroup,
      newContacts: _contacts,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // ── AppBar (Figma node 1:437) ──────────────────────────────────────────
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
                    colors: [AppTheme.primary, AppTheme.primaryLight]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Text('Profile Management',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onBackground)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppTheme.primaryLight),
            child:
                const Icon(Icons.person_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: [
            // ── Profile Header (Figma node 1:327) ─────────────────────────
            _buildProfileHeader(),
            const SizedBox(height: 24),

            // ── Personal Info section (Figma node 1:339) ──────────────────
            _buildPersonalInfoSection(),
            const SizedBox(height: 24),

            // ── Emergency Contacts section (Figma node 1:383) ─────────────
            _buildEmergencyContactsSection(),
            const SizedBox(height: 24),

            // ── Actions (Figma node 1:427) ────────────────────────────────
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Avatar with edit button
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.divider,
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 4,
                        offset: Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppTheme.onSurfaceLight, size: 48),
              ),
              // Edit photo button (Figma node 1:335 — blue circle)
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 16),
              ),
            ],
          ),
          // Name and role text below avatar
          Positioned(
            bottom: 0,
            child: Column(
              children: [
                Text(
                  _userName,
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verified User',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppTheme.onSurfaceLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text('Personal Info',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onBackground)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1))
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _profileRow('User Name', _userName,
                  onEdit: () => _editField(context, 'User Name', _userName,
                      (v) => setState(() {
                        _userName = v;
                        _saveProfileChanges();
                      }))),
              const SizedBox(height: 8),
              _profileRow('Phone Number', _phone,
                  onEdit: () => _editField(context, 'Phone Number', _phone,
                      (v) => setState(() {
                        _phone = v;
                        _saveProfileChanges();
                      }))),
              const SizedBox(height: 8),
              _profileRow('Date of Birth', _dob,
                  onEdit: () => _editField(context, 'Date of Birth', _dob,
                      (v) => setState(() {
                        _dob = v;
                        _saveProfileChanges();
                      }))),
              const SizedBox(height: 8),
              _bloodGroupRow(),
            ],
          ),
        ),
      ],
    );
  }


  Widget _profileRow(String label, String value, {required VoidCallback onEdit}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppTheme.onSurfaceLight)),
                const SizedBox(height: 4),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onBackground)),
              ],
            ),
          ),
          // Edit pencil button (Figma node 1:350 — #edeeef circle with pencil)
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppTheme.cardBg),
            child: IconButton(
              icon: const Icon(Icons.edit_rounded,
                  size: 16, color: AppTheme.onSurfaceMid),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloodGroupRow() {
    // Figma node 1:371 — pink tinted background rgba(255,179,172,0.2)
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.sosRedContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blood Group',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFFB6171E))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.water_drop_rounded,
                        size: 16, color: AppTheme.sosRed),
                    const SizedBox(width: 8),
                    Text(_bloodGroup,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onBackground)),
                  ],
                ),
              ],
            ),
          ),
          // White edit button (Figma node 1:380)
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white),
            child: IconButton(
              icon: const Icon(Icons.edit_rounded,
                  size: 16, color: AppTheme.onSurfaceMid),
              onPressed: () => _editField(context, 'Blood Group', _bloodGroup,
                  (v) => setState(() => _bloodGroup = v)),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.contacts_rounded,
                  size: 18, color: AppTheme.onBackground),
              const SizedBox(width: 8),
              Text('Emergency Contacts',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${_contacts.length} of 3 (Min 2)',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        ..._contacts.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _contactCard(c, onDelete: () {
              if (_contacts.length > 2) {
                setState(() {
                  _contacts.removeAt(i);
                  _saveProfileChanges();
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Minimum 2 emergency contacts are required.')),
                );
              }
            }),
          );
        }),
        // Add contact button (Figma node 1:422)
        if (_contacts.length < 3)
          GestureDetector(
            onTap: () {
              setState(() {
                _contacts.add(EmergencyContact(
                  name: 'New Contact',
                  relation: 'Friend',
                  phone: '+919876543210',
                ));
                _saveProfileChanges();
              });
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_rounded,
                      color: AppTheme.onSurfaceMid, size: 20),
                  const SizedBox(width: 8),
                  Text('Add Emergency Contact (${_contacts.length}/3)',
                      style: GoogleFonts.inter(
                          fontSize: 16, color: AppTheme.onSurfaceMid)),
                ],
              ),
            ),
          ),
      ],
    );
  }


  Widget _contactCard(EmergencyContact contact,
      {required VoidCallback onDelete}) {
    final initial = contact.name.isNotEmpty
        ? contact.name[0].toUpperCase()
        : 'C';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppTheme.primaryLight),
            alignment: Alignment.center,
            child: Text(initial,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onBackground)),
                const SizedBox(height: 2),
                Text(
                    '${contact.relation} • ${contact.phone}',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppTheme.onSurfaceLight),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              _editContactDialog(contact);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppTheme.cardBg),
              child: const Icon(Icons.edit_rounded,
                  size: 16, color: AppTheme.onSurfaceMid),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppTheme.sosRedContainer),
              child: const Icon(Icons.delete_rounded,
                  size: 16, color: AppTheme.sosRed),
            ),
          ),
        ],
      ),
    );
  }

  void _editContactDialog(EmergencyContact contact) {
    final nameCtrl = TextEditingController(text: contact.name);
    final relCtrl = TextEditingController(text: contact.relation);
    final phoneCtrl = TextEditingController(text: contact.phone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relation')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                contact.name = nameCtrl.text.trim();
                contact.relation = relCtrl.text.trim();
                contact.phone = phoneCtrl.text.trim();
                _saveProfileChanges();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: _saveProfileChanges,
          icon: const Icon(Icons.save_rounded, size: 20),
          label: const Text('Update Profile'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
          ),
        ),

        const SizedBox(height: 16),
        // Log Out button (Figma node 1:433 — #edeeef bg)
        FilledButton.icon(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context, '/login', (r) => false),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Log Out'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.cardBg,
            foregroundColor: AppTheme.onBackground,
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
  }

  Future<void> _editField(BuildContext context, String label, String current,
      ValueChanged<String> onSave) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $label',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) onSave(result);
  }
}
