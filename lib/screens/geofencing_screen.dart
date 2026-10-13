import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../services/sos_service.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

class GeofencingScreen extends StatefulWidget {
  const GeofencingScreen({super.key});

  @override
  State<GeofencingScreen> createState() => _GeofencingScreenState();
}

class _GeofencingScreenState extends State<GeofencingScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _customRadiusCtrl = TextEditingController(text: '5');
  
  LatLng _fixedCenter = const LatLng(16.5062, 80.6480);
  LatLng _liveLocation = const LatLng(16.5062, 80.6480); 
  double _radiusInMeters = 5000.0;
  bool _isGuardActive = false;
  bool _isSosTriggered = false;

  final List<double> _presetKmValues = [5.0, 10.0, 20.0, 25.0, 50.0, 100.0];
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _startLiveLocationStream();
  }

  @override
  void dispose() {
    _customRadiusCtrl.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  bool _hasInitialCenterSet = false;

  Future<void> _startLiveLocationStream() async {
    try {
      Position? lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        final loc = LatLng(lastPos.latitude, lastPos.longitude);
        setState(() {
          _fixedCenter = loc;
          _liveLocation = loc;
          _hasInitialCenterSet = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitMapToRadius(_radiusInMeters, target: loc);
        });
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen((Position pos) {
        if (mounted) {
          final newLoc = LatLng(pos.latitude, pos.longitude);
          setState(() {
            _liveLocation = newLoc;
            // Always lock shield center to live location when guard is not active
            if (!_isGuardActive || !_hasInitialCenterSet) {
              _fixedCenter = newLoc;
              _hasInitialCenterSet = true;
            }
          });

          // Ignore location fixes with poor accuracy (> 100m) to avoid false SOS triggers
          if (pos.accuracy > 100) return;

          // Automated SOS trigger when Guard is ACTIVE & Perimeter Breached
          if (_isGuardActive && !_isSosTriggered) {
            final double dist = Geolocator.distanceBetween(
              _fixedCenter.latitude,
              _fixedCenter.longitude,
              newLoc.latitude,
              newLoc.longitude,
            );
            if (dist > _radiusInMeters) {
              _isSosTriggered = true;
              SosService.triggerSosCountdown(
                phoneNumbers: ['9381117370'],
                message: 'EMERGENCY: Geofence Safe Zone Breached! Location: https://maps.google.com/?q=${newLoc.latitude},${newLoc.longitude}',
                triggerSource: 'Geo-fencing',
              );
              SosService.playSiren();
            }
          }
        }
      });
    } catch (_) {}
  }

  void _onSelectPreset(double km) {
    setState(() {
      _radiusInMeters = km * 1000.0;
      _fixedCenter = _liveLocation; // Center is ALWAYS live GPS location on selection
      _customRadiusCtrl.text = km.toStringAsFixed(km % 1 == 0 ? 0 : 1);
    });
    _fitMapToRadius(_radiusInMeters, target: _liveLocation);
  }

  void _onApplyCustomRadius() {
    FocusScope.of(context).unfocus();
    final parsed = double.tryParse(_customRadiusCtrl.text);
    if (parsed != null && parsed > 0) {
      setState(() {
        _radiusInMeters = parsed * 1000.0;
        _fixedCenter = _liveLocation; // Center is ALWAYS live GPS location on selection
      });
      _fitMapToRadius(_radiusInMeters, target: _liveLocation);
    }
  }

  void _fitMapToRadius(double meters, {LatLng? target}) {
    final center = target ?? _fixedCenter;
    final latDiff = meters / 111320.0;
    final lngDiff = meters / (111320.0 * math.cos(center.latitude * math.pi / 180.0));

    final bounds = LatLngBounds(
      LatLng(center.latitude - latDiff, center.longitude - lngDiff),
      LatLng(center.latitude + latDiff, center.longitude + lngDiff),
    );

    try {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(36.0)),
      );
    } catch (e) {
      debugPrint('MapController fitCamera deferred: $e');
    }
  }

  void _resetMapToNorth() {
    try {
      _mapController.rotate(0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.mapOrientedNorth ?? 'Map oriented North 🧭'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final double distanceInMeters = Geolocator.distanceBetween(
      _fixedCenter.latitude,
      _fixedCenter.longitude,
      _liveLocation.latitude,
      _liveLocation.longitude,
    );

    final bool isOutside = _isGuardActive && (distanceInMeters > _radiusInMeters);
    final double currentKm = _radiusInMeters / 1000.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.geoFencingSafety ?? 'Geo Fencing Safety',
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
      body: SafeArea(
        child: Column(
          children: [
            // 1. Status Banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOutside 
                    ? Colors.red.shade700 
                    : (_isGuardActive ? Colors.green.shade700 : Colors.white),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isOutside 
                        ? Icons.warning_amber_rounded 
                        : (_isGuardActive ? Icons.verified_user_rounded : Icons.info_outline_rounded),
                    color: (_isGuardActive || isOutside) ? Colors.white : AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOutside
                          ? 'ALERT: Out of Safe Zone! (${((distanceInMeters - _radiusInMeters) / 1000).toStringAsFixed(1)} km out)'
                          : (_isGuardActive 
                              ? 'SAFE: Inside Geofence Zone' 
                              : 'Select Radius below & Enable Guard'),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: (_isGuardActive || isOutside) ? Colors.white : AppTheme.onBackground,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. OpenStreetMap Viewport (Expanded)
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _fixedCenter,
                      initialZoom: 13.2,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                      // Disabled accidental map tap repositioning so casual roaming never shifts the shield
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.streetpartner',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _fixedCenter,
                            color: isOutside 
                                ? Colors.red.withValues(alpha: 0.25)
                                : AppTheme.primary.withValues(alpha: 0.2),
                            borderColor: isOutside ? Colors.red : AppTheme.primary,
                            borderStrokeWidth: isOutside ? 3 : 2,
                            radius: _radiusInMeters,
                            useRadiusInMeter: true,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          // Guarded Center Pin 🛡️
                          Marker(
                            point: _fixedCenter,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isOutside ? Colors.red : AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                          // Moving Person Marker 👤
                          Marker(
                            point: _liveLocation,
                            width: 48,
                            height: 48,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isOutside
                                        ? Colors.red.withValues(alpha: 0.3)
                                        : Colors.blue.withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isOutside ? Colors.red : Colors.blue.shade600,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
                                  ),
                                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Floating Action Control Column
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Column(
                      children: [
                        // North Pointer Compass Button
                        FloatingActionButton.small(
                          heroTag: 'btn_north_pointer',
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade700,
                          onPressed: _resetMapToNorth,
                          child: const Icon(Icons.navigation_rounded),
                        ),
                        const SizedBox(height: 8),
                        // Shield Focus Button (Fits Full Circle in Viewport)
                        FloatingActionButton.small(
                          heroTag: 'btn_guard_focus',
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          onPressed: () => _fitMapToRadius(_radiusInMeters, target: _fixedCenter),
                          child: const Icon(Icons.shield_outlined),
                        ),
                        const SizedBox(height: 8),
                        // Person Focus Button (Google Maps Close-up Zoom)
                        FloatingActionButton.small(
                          heroTag: 'btn_person_focus',
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade700,
                          onPressed: () {
                            try {
                              _mapController.move(_liveLocation, 17.0);
                            } catch (_) {}
                          },
                          child: const Icon(Icons.my_location_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Anchored Bottom Controls
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Radius Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)?.selectGuardRadius ?? 'Select Guard Radius:',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${currentKm % 1 == 0 ? currentKm.toInt() : currentKm.toStringAsFixed(1)} KM',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Preset Chips (5, 10, 20, 25, 50, 100 KM)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _presetKmValues.map((km) {
                      final bool isSelected = (currentKm == km);
                      return ChoiceChip(
                        label: Text('${km.toInt()} KM'),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? Colors.white : AppTheme.onBackground,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (_) => _onSelectPreset(km),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Custom Radius Field + Apply
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customRadiusCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Custom KM (e.g. 15)',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: _onApplyCustomRadius,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(AppLocalizations.of(context)?.apply ?? 'APPLY', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Guard Toggle Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: _isGuardActive
                        ? FilledButton.icon(
                            onPressed: () {
                              SosService.stopMonitoring();
                              SosService.stopSosCountdown();
                              setState(() {
                                _isGuardActive = false;
                                _isSosTriggered = false;
                              });
                            },
                            icon: const Icon(Icons.stop_rounded),
                            label: Text(AppLocalizations.of(context)?.disableGuard ?? 'DISABLE GUARD'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.grey.shade900,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _fixedCenter = _liveLocation; // Lock center to current live GPS!
                                _isGuardActive = true;
                                _isSosTriggered = false;
                              });
                              SosService.startGeofenceMonitoring(_fixedCenter.latitude, _fixedCenter.longitude, _radiusInMeters);
                              _fitMapToRadius(_radiusInMeters, target: _fixedCenter);
                            },
                            icon: const Icon(Icons.shield_rounded),
                            label: Text(AppLocalizations.of(context)?.enableGeofenceGuard ?? 'ENABLE GEOFENCE GUARD'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
