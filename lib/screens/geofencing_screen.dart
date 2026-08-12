import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../services/sos_service.dart';

class GeofencingScreen extends StatefulWidget {
  const GeofencingScreen({super.key});

  @override
  State<GeofencingScreen> createState() => _GeofencingScreenState();
}

class _GeofencingScreenState extends State<GeofencingScreen> {
  final MapController _mapController = MapController();
  
  LatLng _fixedCenter = const LatLng(37.7749, -122.4194); 
  LatLng _liveLocation = const LatLng(37.7749, -122.4194); 
  double _radiusInMeters = 500.0;
  bool _isLoadingLocation = true;
  bool _isGuardActive = false;
  
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    } 

    Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() {
        _fixedCenter = LatLng(pos.latitude, pos.longitude);
        _liveLocation = LatLng(pos.latitude, pos.longitude);
        _isLoadingLocation = false;
      });
      _mapController.move(_fixedCenter, 15.0);
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((Position livePos) {
      if (mounted) {
        setState(() {
          _liveLocation = LatLng(livePos.latitude, livePos.longitude);
        });
      }
    });
  }

  void _onEnableGuard() {
    SosService.startGeofenceMonitoring(_fixedCenter.latitude, _fixedCenter.longitude, _radiusInMeters);
    setState(() {
      _isGuardActive = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Geo Fencing Active! Guarding this area.'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _onDisableGuard() {
    SosService.stopMonitoring();
    setState(() {
      _isGuardActive = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Geo Fencing Disabled.'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Geo Fencing',
          style: GoogleFonts.inter(
            color: AppTheme.onBackground,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.onBackground),
      ),
      extendBodyBehindAppBar: true,
      body: _isLoadingLocation 
          ? const Center(child: CircularProgressIndicator()) 
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _fixedCenter,
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.scrollWheelZoom | InteractiveFlag.doubleTapZoom,
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
                          color: AppTheme.primary.withOpacity(0.2),
                          borderColor: AppTheme.primary,
                          borderStrokeWidth: 2,
                          radius: _radiusInMeters,
                          useRadiusInMeter: true,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _liveLocation,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Center reticle (Only show if not guarding)
                if (!_isGuardActive)
                  const Center(
                    child: Icon(
                      Icons.my_location_rounded,
                      color: AppTheme.primary,
                      size: 30,
                    ),
                  ),
                
                // Bottom panel
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isGuardActive) ...[
                          Text(
                            'Radius: ${_radiusInMeters.toStringAsFixed(0)} meters',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onBackground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: _radiusInMeters,
                            min: 100,
                            max: 5000,
                            activeColor: AppTheme.primary,
                            onChanged: (val) {
                              setState(() {
                                _radiusInMeters = val;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: _isGuardActive
                              ? FilledButton.icon(
                                  onPressed: _onDisableGuard,
                                  icon: const Icon(Icons.stop_rounded),
                                  label: const Text('DISABLE GUARD'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.grey.shade800,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : FilledButton.icon(
                                  onPressed: _onEnableGuard,
                                  icon: const Icon(Icons.shield_rounded),
                                  label: const Text('ENABLE GUARD'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
