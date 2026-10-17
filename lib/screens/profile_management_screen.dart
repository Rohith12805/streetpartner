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

/// Redesigned Profile Management Screen — Modern, compact, responsive,
/// fully localized, and preserves all Firebase & safety integration.
class ProfileManagementScreen extends StatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  State<ProfileManagementScreen> createState() => _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  Future<void> _updateField(String field, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {field: value},
      );
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc?.profileUpdatedSuccessfully ?? 'Profile updated successfully!'),
            backgroundColor: const Color(0xFF137333),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _updateEmergencyContacts(List<dynamic> updatedContacts) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'emergencyContacts': updatedContacts,
      });

      // Synchronize immediately with local SharedPreferences for offline SOS resilience
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          'cached_emergency_contacts',
          updatedContacts.map((e) => e.toString().trim()).toList(),
        );
      } catch (_) {}

      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc?.profileUpdatedSuccessfully ?? 'Profile updated successfully!'),
            backgroundColor: const Color(0xFF137333),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(loc?.notAuthenticated ?? 'Not authenticated')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xCCF8F9FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loc?.profile ?? 'Profile',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onBackground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(loc?.sessionExpiredPleaseLogInAgain ?? 'Session expired. Please log in again.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(loc?.profileNotFound ?? 'Profile not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final userName = data['fullName'] ?? user.displayName ?? 'SHEild User';
          final email = data['email'] ?? user.email ?? 'No email registered';
          final phone = data['phoneNumber'] ?? user.phoneNumber ?? 'Not set';
          final bloodGroup = data['bloodGroup'] ?? 'Unknown';
          final medicalNotes = (data['medicalNotes'] as String?) ?? 'None';
          final List<dynamic> contacts = data['emergencyContacts'] ?? [];
          final photoUrl = user.photoURL ?? (data['photoUrl'] as String?);
          final bool isVerified = user.emailVerified;

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Compact Profile Summary ───────────────────────────
                  _buildCompactProfileSummary(userName, email, photoUrl, isVerified),
                  const SizedBox(height: 18),

                  // ── 2. Personal Information Card ─────────────────────────
                  _buildPersonalInfoCard(userName, email, phone, bloodGroup, medicalNotes),
                  const SizedBox(height: 18),

                  // ── 3. My Safety Reviews Navigation Card ──────────────────
                  _buildReviewsNavigationCard(context),
                  const SizedBox(height: 18),

                  // ── 4. Emergency Contacts Section ────────────────────────
                  _buildEmergencyContactsSection(contacts),
                  const SizedBox(height: 28),

                  // ── 5. Log Out Action ────────────────────────────────────
                  _buildLogoutButton(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactProfileSummary(
    String userName,
    String email,
    String? photoUrl,
    bool isVerified,
  ) {
    final loc = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryLight.withValues(alpha: 0.12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person_rounded,
                        color: AppTheme.primary,
                        size: 32,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: AppTheme.primary,
                      size: 32,
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // User details & confirmed verification status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onBackground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.onSurfaceMid,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? const Color(0xFFE6F4EA)
                        : const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVerified ? Icons.verified_rounded : Icons.shield_outlined,
                        size: 13,
                        color: isVerified ? const Color(0xFF137333) : AppTheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVerified
                            ? (loc?.verifiedUser ?? 'Verified User')
                            : 'SHEild Member',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isVerified ? const Color(0xFF137333) : AppTheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(
    String userName,
    String email,
    String phone,
    String bloodGroup,
    String medicalNotes,
  ) {
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            loc?.personalInfo ?? 'Personal Info',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.onBackground,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.divider.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // User Name
              _buildInfoRow(
                icon: Icons.person_outline_rounded,
                label: loc?.userName ?? 'User Name',
                value: userName,
                onEdit: () => _editDialog(
                  title: loc?.editName ?? 'Edit Name',
                  initialValue: userName,
                  onSave: (val) => _updateField('fullName', val),
                ),
              ),
              const Divider(height: 1, indent: 52),

              // Email Address (authenticated Google/Firebase account)
              _buildInfoRow(
                icon: Icons.email_outlined,
                label: loc?.emailAddress ?? 'Email Address',
                value: email,
                isEditable: false,
              ),
              const Divider(height: 1, indent: 52),

              // Phone Number
              _buildInfoRow(
                icon: Icons.phone_outlined,
                label: loc?.phoneNumber ?? 'Phone Number',
                value: phone,
                onEdit: () => _editDialog(
                  title: loc?.phoneNumber ?? 'Phone Number',
                  initialValue: phone == 'Not set' ? '' : phone,
                  keyboardType: TextInputType.phone,
                  onSave: (val) => _updateField('phoneNumber', val),
                ),
              ),
              const Divider(height: 1, indent: 52),

              // Blood Group
              _buildInfoRow(
                icon: Icons.water_drop_outlined,
                iconColor: AppTheme.sosRed,
                label: loc?.bloodGroup ?? 'Blood Group',
                value: bloodGroup,
                onEdit: () => _selectBloodGroupDialog(bloodGroup),
              ),
              const Divider(height: 1, indent: 52),

              // Medical Notes (Optional)
              _buildInfoRow(
                icon: Icons.medical_information_outlined,
                label: 'Medical Notes',
                value: medicalNotes == 'None' || medicalNotes.isEmpty ? 'None added' : medicalNotes,
                onEdit: () => _editDialog(
                  title: 'Medical Notes',
                  initialValue: medicalNotes == 'None' ? '' : medicalNotes,
                  maxLines: 2,
                  onSave: (val) => _updateField('medicalNotes', val.isEmpty ? 'None' : val),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    VoidCallback? onEdit,
    bool isEditable = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primary).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor ?? AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMid,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onBackground,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isEditable && onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.outline),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildReviewsNavigationCard(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyReviewsScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.rate_review_outlined, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc?.mySafetyReviews ?? 'My Safety Reviews',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc?.viewAndDeleteYourPreviousAreaR ?? 'View and delete your previous area ratings',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceMid),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.outline, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsSection(List<dynamic> contacts) {
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc?.emergencyContacts ?? 'Emergency Contacts',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onBackground,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${contacts.length}/5 (Min 1)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Contacts list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: contacts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final phone = contacts[index].toString();
            return _buildContactCard(index, phone, contacts);
          },
        ),

        const SizedBox(height: 10),

        // Add Emergency Contact Button (limit: 5)
        if (contacts.length < 5)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 1.2),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: Text(
              loc?.addEmergencyContact ?? 'Add Emergency Contact',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: () => _addContactDialog(contacts),
          ),
      ],
    );
  }

  Widget _buildContactCard(int index, String phone, List<dynamic> contacts) {
    final loc = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.15),
            child: Text(
              '${index + 1}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${loc?.emergencyContact ?? 'Emergency Contact'} ${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onBackground,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  phone,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.onSurfaceMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Edit
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.outline),
            onPressed: () => _editContactDialog(index, phone, contacts),
            visualDensity: VisualDensity.compact,
          ),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.sosRed),
            onPressed: () {
              if (contacts.length <= 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc?.minimum1EmergencyContactIsRequ ?? 'Minimum 1 emergency contact is required.'),
                    backgroundColor: AppTheme.sosRed,
                  ),
                );
                return;
              }
              _confirmDeleteContactDialog(index, phone, contacts);
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _addContactDialog(List<dynamic> contacts) {
    final loc = AppLocalizations.of(context);
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          loc?.addEmergencyContact ?? 'Add Emergency Contact',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: loc?.phoneNumber ?? 'Phone Number',
            hintText: 'e.g. 9876543210',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc?.cancel1 ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              final newPhone = ctrl.text.trim();
              if (newPhone.isNotEmpty) {
                final updated = List.from(contacts)..add(newPhone);
                _updateEmergencyContacts(updated);
              }
              Navigator.pop(ctx);
            },
            child: Text(loc?.add ?? 'Add'),
          ),
        ],
      ),
    );
  }

  void _editContactDialog(int index, String currentPhone, List<dynamic> contacts) {
    final loc = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          loc?.editEmergencyContact ?? 'Edit Emergency Contact',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: loc?.phoneNumber ?? 'Phone Number',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc?.cancel1 ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              final newPhone = ctrl.text.trim();
              if (newPhone.isNotEmpty) {
                final updated = List.from(contacts);
                updated[index] = newPhone;
                _updateEmergencyContacts(updated);
              }
              Navigator.pop(ctx);
            },
            child: Text(loc?.save1 ?? 'Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteContactDialog(int index, String phone, List<dynamic> contacts) {
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          loc?.deleteContact ?? 'Delete Contact',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          '${loc?.areYouSureDeleteContact ?? 'Are you sure you want to remove this emergency contact?'}\n\n$phone',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurfaceMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc?.cancel1 ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.sosRed),
            onPressed: () {
              Navigator.pop(ctx);
              final updated = List.from(contacts)..removeAt(index);
              _updateEmergencyContacts(updated);
            },
            child: Text(loc?.delete ?? 'Delete'),
          ),
        ],
      ),
    );
  }

  void _selectBloodGroupDialog(String currentGroup) {
    final groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'];
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          loc?.selectBloodGroup ?? 'Select Blood Group',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: groups.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final g = groups[i];
              final isSelected = g == currentGroup;
              return ListTile(
                title: Text(
                  g,
                  style: GoogleFonts.inter(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primary : AppTheme.onBackground,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _updateField('bloodGroup', g);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc?.cancel1 ?? 'Cancel'),
          ),
        ],
      ),
    );
  }

  void _editDialog({
    required String title,
    required String initialValue,
    required ValueChanged<String> onSave,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final loc = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          autofocus: true,
          decoration: InputDecoration(
            labelText: title,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc?.cancel1 ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              Navigator.pop(ctx);
              onSave(ctrl.text.trim());
            },
            child: Text(loc?.save1 ?? 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return OutlinedButton.icon(
      onPressed: () => _confirmLogout(context),
      icon: const Icon(Icons.logout_rounded, size: 18, color: AppTheme.sosRed),
      label: Text(
        loc?.logOut ?? 'Log Out',
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.sosRed,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppTheme.sosRed, width: 1.2),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          loc?.confirmLogout ?? 'Confirm Log Out',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          loc?.areYouSureYouWantToLogOut ?? 'Are you sure you want to log out?',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurfaceMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc?.cancel1 ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.sosRed),
            onPressed: () async {
              Navigator.pop(ctx);
              // Stop foreground service
              await SosService.stopForegroundService();
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('background_protection', false);
              } catch (_) {}

              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
              }

              await FirebaseAuth.instance.signOut();
              final googleSignIn = GoogleSignIn();
              if (await googleSignIn.isSignedIn()) {
                await googleSignIn.signOut();
              }
            },
            child: Text(loc?.logOut ?? 'Log Out'),
          ),
        ],
      ),
    );
  }
}
