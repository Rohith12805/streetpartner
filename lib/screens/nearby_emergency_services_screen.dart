import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Nearby Emergency Services Screen — Figma node 1:623
/// 3 category selector cards, result list with service name/address/distance/contact
class NearbyEmergencyServicesScreen extends StatefulWidget {
  const NearbyEmergencyServicesScreen({super.key});

  @override
  State<NearbyEmergencyServicesScreen> createState() =>
      _NearbyEmergencyServicesScreenState();
}

class _NearbyEmergencyServicesScreenState
    extends State<NearbyEmergencyServicesScreen> {
  String _selectedCategory = 'Police'; // Default: Police selected (Figma node 1:627)

  // Placeholder data per category
  final Map<String, List<_ServiceItem>> _services = {
    'Police': [
      _ServiceItem(
        name: 'Central Police Station',
        address: '123 Safety Ave, City',
        distance: '0.8 km',
        phone: '+1 234 567 890',
        isNearest: true,
      ),
      _ServiceItem(
        name: 'Westside Precinct',
        address: '456 Guardian Blvd',
        distance: '2.1 km',
        phone: '+1 987 654 321',
      ),
      _ServiceItem(
        name: 'Highway Patrol HQ',
        address: '789 Interstate Pkwy',
        distance: '3.5 km',
        phone: '+1 555 123 456',
      ),
    ],
    'Hospital': [
      _ServiceItem(
        name: 'City General Hospital',
        address: '88 Health Blvd',
        distance: '1.2 km',
        phone: '+1 800 HOS PITAL',
        isNearest: true,
      ),
      _ServiceItem(
        name: 'St. Mary Medical Center',
        address: '204 Care Lane',
        distance: '2.7 km',
        phone: '+1 555 987 001',
      ),
      _ServiceItem(
        name: 'Community Clinic',
        address: '50 Wellness Rd',
        distance: '4.0 km',
        phone: '+1 555 321 700',
      ),
    ],
    'Fire Station': [
      _ServiceItem(
        name: 'Fire Station #1',
        address: '10 Blaze Ave',
        distance: '1.0 km',
        phone: '+1 800 FIRE 001',
        isNearest: true,
      ),
      _ServiceItem(
        name: 'Eastside Fire Dept.',
        address: '92 Rescue Rd',
        distance: '3.3 km',
        phone: '+1 555 442 800',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // ── AppBar (Figma node 1:732) ──────────────────────────────────────────
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
            Text('Nearby Emergency Services',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onBackground)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Category Selector (Figma node 1:626) ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildCategorySelector(),
          ),

          const SizedBox(height: 16),

          // ── Section title row (Figma node 1:649) ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Text(
                  'Nearby $_selectedCategory',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackground),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined,
                          size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text('Map View',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppTheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Service List (Figma node 1:656) ───────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _services[_selectedCategory]!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final item = _services[_selectedCategory]![i];
                return _buildServiceCard(context, item);
              },
            ),
          ),

          // ── Back button ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.onSurfaceMid,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
                side: const BorderSide(color: AppTheme.divider),
              ),
              child: Text('Back',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      _Category(
        id: 'Police',
        icon: Icons.local_police_rounded,
        selectedBg: AppTheme.primary,
        selectedIconColor: Colors.white,
      ),
      _Category(
        id: 'Hospital',
        icon: Icons.local_hospital_rounded,
        selectedBg: AppTheme.primary,
        selectedIconColor: Colors.white,
      ),
      _Category(
        id: 'Fire Station',
        icon: Icons.local_fire_department_rounded,
        selectedBg: AppTheme.primary,
        selectedIconColor: Colors.white,
      ),
    ];

    return Row(
      children: categories
          .map((cat) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: cat.id != 'Fire Station' ? 12 : 0,
                  ),
                  child: _categoryCard(cat),
                ),
              ))
          .toList(),
    );
  }

  Widget _categoryCard(_Category cat) {
    final isSelected = _selectedCategory == cat.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          // Figma: selected = #e7e8e9 with blue tint overlay
          color: isSelected
              ? const Color(0xFFE7E8E9)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000),
                blurRadius: 4,
                offset: Offset(0, 1))
          ],
        ),
        child: Stack(
          children: [
            // Blue tint overlay when selected (Figma node 1:634)
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Selected: #005bbf with glow (Figma node 1:629)
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.divider,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                            )
                          ]
                        : [],
                  ),
                  child: Icon(
                    cat.icon,
                    color: isSelected ? Colors.white : AppTheme.onSurfaceMid,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cat.id,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: AppTheme.onBackground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, _ServiceItem item) {
    // Figma node 1:657 — rounded-24px card with contact button row at bottom
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top row: icon + name/address + distance badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle (Figma node 1:660)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.1),
                ),
                child: Icon(
                  _categoryIcon(_selectedCategory),
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onBackground),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: AppTheme.onSurfaceMid),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.address,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.onSurfaceMid),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Distance badge (Figma node 1:670 — nearest=red, others=grey)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isNearest
                      ? AppTheme.sosRed.withOpacity(0.15)
                      : AppTheme.divider,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.near_me_rounded,
                      size: 10,
                      color: item.isNearest
                          ? AppTheme.sosRed
                          : AppTheme.onSurfaceMid,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.distance,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: item.isNearest
                            ? AppTheme.sosRed
                            : AppTheme.onSurfaceMid,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Divider (Figma node 1:674 — HorizontalBorder)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Divider(
                height: 1,
                color: Color(0x4DC1C6D6)),
          ),
          const SizedBox(height: 16),

          // Bottom row: call button + directions button
          Row(
            children: [
              // Phone button (Figma node 1:675 — #005bbf, full width)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Calling ${item.phone} (Demo)',
                            style: GoogleFonts.inter(color: Colors.white)),
                        backgroundColor: AppTheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    ),
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: Text(item.phone,
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Directions button (Figma node 1:679 — #e1e3e4 circle)
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.divider,
                ),
                child: const Icon(Icons.directions_rounded,
                    color: AppTheme.onSurfaceMid, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Hospital':
        return Icons.local_hospital_rounded;
      case 'Fire Station':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.local_police_rounded;
    }
  }
}

class _Category {
  final String id;
  final IconData icon;
  final Color selectedBg;
  final Color selectedIconColor;

  const _Category({
    required this.id,
    required this.icon,
    required this.selectedBg,
    required this.selectedIconColor,
  });
}

class _ServiceItem {
  final String name;
  final String address;
  final String distance;
  final String phone;
  final bool isNearest;

  const _ServiceItem({
    required this.name,
    required this.address,
    required this.distance,
    required this.phone,
    this.isNearest = false,
  });
}
