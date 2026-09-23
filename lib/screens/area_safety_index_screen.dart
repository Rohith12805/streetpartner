import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/area_safety_service.dart';
import '../models/area_safety_model.dart';
import '../widgets/safety_rating_sheet.dart';
import '../widgets/safety_reviews_sheet.dart';

class AreaSafetyIndexScreen extends StatefulWidget {
  const AreaSafetyIndexScreen({super.key});

  @override
  State<AreaSafetyIndexScreen> createState() => _AreaSafetyIndexScreenState();
}

class _AreaSafetyIndexScreenState extends State<AreaSafetyIndexScreen> {
  final MapController _mapController = MapController();
  final AreaSafetyService _safetyService = AreaSafetyService();
  final TextEditingController _searchController = TextEditingController();

  LatLng _currentMapCenter = const LatLng(0, 0);
  LatLng? _userLocation;
  String _activeCellId = '';
  
  StreamSubscription<AreaSafetyCell?>? _cellSubscription;
  AreaSafetyCell? _activeCellData;
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _cellSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
          
      final loc = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _userLocation = loc;
          _currentMapCenter = loc;
          _isLoading = false;
        });
        _updateActiveCell(loc);
      }
    } catch (e) {
      // Fallback to a default location (e.g., Delhi) if location fails
      if (mounted) {
        setState(() {
          _userLocation = const LatLng(28.6139, 77.2090);
          _currentMapCenter = const LatLng(28.6139, 77.2090);
          _isLoading = false;
        });
        _updateActiveCell(_currentMapCenter);
      }
    }
  }

  void _updateActiveCell(LatLng center) {
    final cellId = AreaSafetyService.getCellId(center.latitude, center.longitude);
    if (cellId != _activeCellId) {
      _activeCellId = cellId;
      _cellSubscription?.cancel();
      _cellSubscription = _safetyService.streamCell(cellId).listen((cellData) {
        if (mounted) {
          setState(() {
            _activeCellData = cellData;
          });
        }
      });
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);

    final location = await _safetyService.searchLocation(query);
    
    if (mounted) {
      setState(() => _isSearching = false);
      if (location != null) {
        _mapController.move(location, 14.0);
        setState(() {
          _currentMapCenter = location;
        });
        _updateActiveCell(location);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found.')),
        );
      }
    }
  }

  Color _getSafetyColor(double? averageRating) {
    if (averageRating == null || averageRating == 0) return Colors.grey.withValues(alpha: 0.3);
    if (averageRating >= 4.0) return AppTheme.green;
    if (averageRating >= 3.0) return Colors.lightGreen;
    if (averageRating >= 2.0) return const Color(0xFFFFA000);
    if (averageRating >= 1.0) return Colors.deepOrange;
    return AppTheme.sosRed;
  }

  String _getSafetyLabel(double? averageRating) {
    if (averageRating == null || averageRating == 0) return 'No Data';
    if (averageRating >= 4.0) return 'Very Safe';
    if (averageRating >= 3.0) return 'Moderately Safe';
    if (averageRating >= 2.0) return 'Use Caution';
    return 'Unsafe';
  }

  void _openRatingSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafetyRatingSheet(
        location: _currentMapCenter,
        locationName: 'Cell: $_activeCellId',
      ),
    );
    // State is automatically updated via stream if they submit
  }

  void _openReviewsSheet() {
    // Fetch one-time to pass to sheet
    
    
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SafetyReviewsSheet(
          cellId: _activeCellId,
          locationName: 'Cell: $_activeCellId',
        ),
      );
    }
  }

  List<Polygon> _buildCellPolygons() {
    if (_activeCellId.isEmpty) return [];

    // Calculate bounds of the current cell based on our rounding logic
    // A cell is roughly lat to lat+0.01 and lng to lng+0.01 (but since we round, it spans +/- 0.005)
    final center = AreaSafetyService.getCellCenter(_activeCellId);
    final lat = center.latitude;
    final lng = center.longitude;
    
    final points = [
      LatLng(lat - 0.005, lng - 0.005),
      LatLng(lat + 0.005, lng - 0.005),
      LatLng(lat + 0.005, lng + 0.005),
      LatLng(lat - 0.005, lng + 0.005),
    ];

    final color = _getSafetyColor(_activeCellData?.averageRating);

    return [
      Polygon(
        points: points,
        color: color.withValues(alpha: 0.3),
        borderColor: color,
        borderStrokeWidth: 2,
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Area Safety Index',
          style: GoogleFonts.inter(
            color: AppTheme.onBackground,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppTheme.onBackground),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation ?? const LatLng(0, 0),
                    initialZoom: 14.0,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() {
                          _currentMapCenter = position.center;
                        });
                        _updateActiveCell(position.center);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.streetpartner',
                    ),
                    PolygonLayer(
                      polygons: _buildCellPolygons(),
                    ),
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Center Pointer (Crosshair)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0), // Adjust for anchor point
                    child: Icon(
                      Icons.location_on,
                      size: 40,
                      color: AppTheme.primary,
                      shadows: [
                        Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                      ],
                    ),
                  ),
                ),

                // Search Bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _performSearch(),
                      decoration: InputDecoration(
                        hintText: 'Search city or area...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),

                // My Location Button
                Positioned(
                  right: 16,
                  bottom: 240,
                  child: FloatingActionButton(
                    heroTag: 'btn_my_location_safety',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade700,
                    onPressed: () {
                      if (_userLocation != null) {
                        _mapController.move(_userLocation!, 15.0);
                        setState(() {
                          _currentMapCenter = _userLocation!;
                        });
                        _updateActiveCell(_userLocation!);
                      }
                    },
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),

                // Bottom Panel
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomPanel(),
                ),
              ],
            ),
    );
  }

  Widget _buildBottomPanel() {
    final bool hasData = _activeCellData != null && _activeCellData!.totalRatings > 0;
    final color = _getSafetyColor(_activeCellData?.averageRating);
    final label = _getSafetyLabel(_activeCellData?.averageRating);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: color.withValues(alpha: 1.0),
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              if (hasData)
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${_activeCellData!.averageRating.toStringAsFixed(1)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      ' (${_activeCellData!.totalRatings})',
                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No community ratings yet for this area. Be the first to rate it and help others stay safe!',
                style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14),
              ),
            )
          else ...[
            Text(
              'Top Reported Issues:',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildTopIssues(),
          ],
          
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: hasData ? _openReviewsSheet : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Read Reviews',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _openRatingSheet,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Rate This Area',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopIssues() {
    if (_activeCellData == null || _activeCellData!.issueCounts.isEmpty) {
      return Text('No specific issues reported.', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13));
    }

    final total = _activeCellData!.totalRatings;
    var entries = _activeCellData!.issueCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value)); // Sort descending

    // Take top 3 issues
    final topIssues = entries.take(3).toList();

    return Column(
      children: topIssues.map((e) {
        final percent = ((e.value / total) * 100).round();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  e.key,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.value / total,
                    backgroundColor: Colors.grey.shade200,
                    color: AppTheme.primaryLight,
                    minHeight: 6,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
