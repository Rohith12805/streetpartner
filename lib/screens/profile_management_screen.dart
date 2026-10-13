import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/sos_service.dart';
import 'my_reviews_screen.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

/// Profile Management Screen — Figma node 1:253
/// AppBar with back arrow, editable profile fields, emergency contacts, Update + Logout buttons
class ProfileManagementScreen extends StatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  State<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  Future<void> _updateField(String field, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {field: value},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.profileUpdatedSuccessfully ?? 'Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(body: Center(child: Text(AppLocalizations.of(context)?.notAuthenticated ?? 'Not authenticated')));
    }

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
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(AppLocalizations.of(context)?.profileManagement ?? 'Profile Management',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onBackground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryLight,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(AppLocalizations.of(context)?.sessionExpiredPleaseLogInAgain ?? 'Session expired. Please log in again.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(AppLocalizations.of(context)?.profileNotFound ?? 'Profile not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final userName =
              data['fullName'] ?? user.displayName ?? 'Unknown User';
          final email = data['email'] ?? user.email ?? 'No email';
          final phone = data['phoneNumber'] ?? 'No phone';
          final bloodGroup = data['bloodGroup'] ?? 'Unknown';
          final List<dynamic> contacts = data['emergencyContacts'] ?? [];
          final photoUrl = data['photoUrl'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
            child: Column(
              children: [
                // ── Profile Header (Figma node 1:327) ─────────────────────────
                _buildProfileHeader(userName, photoUrl),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // ── Personal Info section (Figma node 1:339) ──────────────────
                      _buildPersonalInfoSection(
                        userName,
                        phone,
                        email,
                        bloodGroup,
                      ),
                      const SizedBox(height: 24),

                      // ── Emergency Contacts section (Figma node 1:383) ─────────────

                      // My Reviews Button
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.rate_review_outlined, color: AppTheme.primary),
                        ),
                        title: Text(AppLocalizations.of(context)?.mySafetyReviews ?? 'My Safety Reviews',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onBackground,
                          ),
                        ),
                        subtitle: Text(AppLocalizations.of(context)?.viewAndDeleteYourPreviousAreaR ?? 'View and delete your previous area ratings',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceMid),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MyReviewsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildEmergencyContactsSection(contacts),
                      const SizedBox(height: 24),

                      // ── Actions (Figma node 1:427) ────────────────────────────────
                      _buildActions(context),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String userName, String? photoUrl) {
    return SizedBox(
      width: double.infinity,
      height: 220,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Clean profile avatar
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryLight.withValues(alpha: 0.15),
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.primary,
              size: 54,
            ),
          ),
          // Name and role text below avatar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ), // Minimal padding to maximize usable width
                  child: Text(
                    userName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context)?.verifiedUser ?? 'Verified User',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.onSurfaceLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(
    String userName,
    String phone,
    String email,
    String bloodGroup,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(AppLocalizations.of(context)?.personalInfo ?? 'Personal Info',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.onBackground,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _profileRow(
                'User Name',
                userName,
                onEdit: () => _editField(
                  context,
                  'User Name',
                  userName,
                  (v) => _updateField('fullName', v),
                ),
              ),
              const SizedBox(height: 8),
              _profileRow(
                'Email Address',
                email,
                onEdit: () => _editField(
                  context,
                  'Email Address',
                  email,
                  (v) => _updateField('email', v),
                ),
              ),
              const SizedBox(height: 8),
              _profileRow(
                'Phone Number',
                phone,
                onEdit: () => _editField(
                  context,
                  'Phone Number',
                  phone,
                  (v) => _updateField('phoneNumber', v),
                ),
              ),
              const SizedBox(height: 8),
              _bloodGroupRow(bloodGroup),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileRow(
    String label,
    String value, {
    required VoidCallback onEdit,
  }) {
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
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onBackground,
                  ),
                ),
              ],
            ),
          ),
          // Edit pencil button (Figma node 1:350 — #edeeef circle with pencil)
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardBg,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.edit_rounded,
                size: 16,
                color: AppTheme.onSurfaceMid,
              ),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloodGroupRow(String bloodGroup) {
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
                Text(AppLocalizations.of(context)?.bloodGroup ?? 'Blood Group',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFB6171E),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.water_drop_rounded,
                      size: 16,
                      color: AppTheme.sosRed,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      bloodGroup,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onBackground,
                      ),
                    ),
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
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.edit_rounded,
                size: 16,
                color: AppTheme.onSurfaceMid,
              ),
              onPressed: () => _editField(
                context,
                'Blood Group',
                bloodGroup,
                (v) => _updateField('bloodGroup', v),
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactsSection(List<dynamic> contacts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Row(
            children: [
              const Icon(
                Icons.contacts_rounded,
                size: 18,
                color: AppTheme.onBackground,
              ),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)?.emergencyContacts ?? 'Emergency Contacts',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onBackground,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${contacts.length} of 3 (Min 1)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...contacts.asMap().entries.map((entry) {
          final i = entry.key;
          final String phone = entry.value.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _contactCard(
              i,
              phone,
              contacts,
              onDelete: () {
                if (contacts.length > 1) {
                  final updated = List.from(contacts);
                  updated.removeAt(i);
                  _updateField('emergencyContacts', updated);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)?.minimum1EmergencyContactIsRequ ?? 'Minimum 1 emergency contact is required.'),
                    ),
                  );
                }
              },
            ),
          );
        }),
        // Add contact button (Figma node 1:422)
        if (contacts.length < 5)
          GestureDetector(
            onTap: () {
              final phoneCtrl = TextEditingController();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(AppLocalizations.of(context)?.addEmergencyContact ?? 'Add Emergency Contact'),
                  content: TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppLocalizations.of(context)?.cancel1 ?? 'Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (phoneCtrl.text.trim().isNotEmpty) {
                          final updated = List.from(contacts)
                            ..add(phoneCtrl.text.trim());
                          _updateField('emergencyContacts', updated);
                        }
                        Navigator.pop(ctx);
                      },
                      child: Text(AppLocalizations.of(context)?.add ?? 'Add'),
                    ),
                  ],
                ),
              );
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
                  const Icon(
                    Icons.person_add_rounded,
                    color: AppTheme.onSurfaceMid,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Emergency Contact (${contacts.length}/5)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.onSurfaceMid,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _contactCard(
    int index,
    String phone,
    List<dynamic> allContacts, {
    required VoidCallback onDelete,
  }) {
    final initial = 'C';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryLight,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Contact ${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onBackground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.onSurfaceLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              _editContactDialog(index, phone, allContacts);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cardBg,
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 16,
                color: AppTheme.onSurfaceMid,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.sosRedContainer,
              ),
              child: const Icon(
                Icons.delete_rounded,
                size: 16,
                color: AppTheme.sosRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editContactDialog(
    int index,
    String currentPhone,
    List<dynamic> allContacts,
  ) {
    final phoneCtrl = TextEditingController(text: currentPhone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.editEmergencyContact ?? 'Edit Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)?.cancel1 ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPhone = phoneCtrl.text.trim();
              if (newPhone.isNotEmpty) {
                final updatedContacts = List.from(allContacts);
                updatedContacts[index] = newPhone;
                _updateField('emergencyContacts', updatedContacts);
              }
              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context)?.save1 ?? 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        // Log Out button (Figma node 1:433 — #edeeef bg)
        FilledButton.icon(
          onPressed: () async {
            // Stop foreground service before logging out
            await SosService.stopForegroundService();
            
            // Clear protection preference
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('background_protection', false);
            } catch (_) {}

            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (r) => false,
              );
            }
            await FirebaseAuth.instance.signOut();
            final googleSignIn = GoogleSignIn();
            if (await googleSignIn.isSignedIn()) {
              await googleSignIn.signOut();
            }
          },
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: Text(AppLocalizations.of(context)?.logOut ?? 'Log Out'),
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

  Future<void> _editField(
    BuildContext context,
    String label,
    String current,
    ValueChanged<String> onSave,
  ) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit $label',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)?.cancel1 ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(AppLocalizations.of(context)?.save1 ?? 'Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) onSave(result);
  }
}
