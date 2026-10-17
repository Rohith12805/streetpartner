import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

/// Dedicated Emergency Numbers directory screen providing instantaneous,
/// offline-capable access to verified emergency helplines in India.
/// Fully localized across all 6 supported languages while preserving UI and numbers.
class EmergencyNumbersScreen extends StatefulWidget {
  const EmergencyNumbersScreen({super.key});

  @override
  State<EmergencyNumbersScreen> createState() => _EmergencyNumbersScreenState();
}

class _EmergencyEntry {
  final String title;
  final String number;
  final String description;
  final IconData icon;
  final Color accentColor;
  final Color iconContainerColor;

  const _EmergencyEntry({
    required this.title,
    required this.number,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.iconContainerColor,
  });
}

class _EmergencyNumbersScreenState extends State<EmergencyNumbersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<_EmergencyEntry> _getDirectory(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return [
      _EmergencyEntry(
        title: loc?.allInOneEmergency ?? 'All-in-One Emergency',
        number: '112',
        description: loc?.allInOneDesc ?? 'National single emergency response for Police, Fire & Medical distress.',
        icon: Icons.emergency_rounded,
        accentColor: AppTheme.sosRed,
        iconContainerColor: const Color(0xFFFFDAD6),
      ),
      _EmergencyEntry(
        title: loc?.police ?? 'Police',
        number: '100',
        description: loc?.policeDesc ?? 'Immediate police intervention, crime reporting & law enforcement assistance.',
        icon: Icons.local_police_rounded,
        accentColor: AppTheme.primary,
        iconContainerColor: const Color(0xFFD8E2FF),
      ),
      _EmergencyEntry(
        title: loc?.ambulance ?? 'Ambulance',
        number: '108',
        description: loc?.ambulanceDesc ?? '24/7 free emergency medical services and patient transportation.',
        icon: Icons.medical_services_rounded,
        accentColor: const Color(0xFF137333),
        iconContainerColor: const Color(0xFFCEEAD6),
      ),
      _EmergencyEntry(
        title: loc?.fireServices ?? 'Fire Services',
        number: '101',
        description: loc?.fireServicesDesc ?? 'Immediate fire brigade dispatch and disaster rescue operations.',
        icon: Icons.local_fire_department_rounded,
        accentColor: const Color(0xFFC5221F),
        iconContainerColor: const Color(0xFFFCE8E6),
      ),
      _EmergencyEntry(
        title: loc?.womenHelpline ?? 'Women Helpline',
        number: '181',
        description: loc?.womenHelplineDesc ?? '24/7 emergency response, crisis intervention & support for women.',
        icon: Icons.support_agent_rounded,
        accentColor: const Color(0xFF9334E6),
        iconContainerColor: const Color(0xFFF3E8FD),
      ),
      _EmergencyEntry(
        title: loc?.childHelpline ?? 'Child Helpline',
        number: '1098',
        description: loc?.childHelplineDesc ?? 'National 24-hour toll-free emergency care & protection for children.',
        icon: Icons.child_care_rounded,
        accentColor: const Color(0xFFB06000),
        iconContainerColor: const Color(0xFFFEF7E0),
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phoneNumber, BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanNumber,
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc?.couldNotOpenDialer ?? 'Could not open phone dialer for'} $phoneNumber'),
            backgroundColor: AppTheme.sosRed,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc?.failedToInitiateCall ?? 'Failed to initiate call:'} $e'),
          backgroundColor: AppTheme.sosRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final directory = _getDirectory(context);

    final filteredList = directory.where((entry) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return entry.title.toLowerCase().contains(q) ||
          entry.number.contains(q) ||
          entry.description.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Heading
              Text(
                loc?.emergencyNumbers ?? 'Emergency Numbers',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onBackground,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                loc?.quickAccessToHelp ?? 'Quick access to help when you need it.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.onSurfaceMid,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // Search Filter Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: loc?.searchEmergencyService ?? 'Search service or number (e.g., Police, 112)...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.outline,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.outline,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppTheme.outline),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Vertically scrollable cards
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final entry = filteredList[index];
                  return _buildEmergencyCard(context, entry);
                },
              ),

              const SizedBox(height: 100), // Generous padding above floating bottom nav & FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(BuildContext context, _EmergencyEntry entry) {
    final loc = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
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
          onTap: () => _makeCall(entry.number, context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Service Icon in dedicated colored container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: entry.iconContainerColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    entry.icon,
                    color: entry.accentColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // Service Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onBackground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: entry.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.number,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: entry.accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.onSurfaceMid,
                          height: 1.35,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Call Action Button
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: entry.accentColor,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: () => _makeCall(entry.number, context),
                  child: Tooltip(
                    message: '${loc?.call ?? 'Call'} ${entry.number}',
                    child: const Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
