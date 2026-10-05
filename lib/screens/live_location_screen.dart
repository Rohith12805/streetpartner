import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  final MapController _mapController = MapController();

  LatLng _currentLocation = const LatLng(17.385, 78.4867); // Default: Hyderabad
  String _addressLine = 'Fetching location...';
  String _subAddress = '';
  bool _isLoading = true;

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _addressLine = 'Location services disabled';
        });
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _addressLine = 'Location permission denied';
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _addressLine = 'Location permission permanently denied';
        });
      }
      return;
    }

    Position? pos = await Geolocator.getLastKnownPosition();
    try {
      pos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (_) {}

    if (pos != null && mounted) {
      setState(() {
        _currentLocation = LatLng(pos!.latitude, pos.longitude);
        _isLoading = false;
      });
      _mapController.move(_currentLocation, 16.0);
      _fetchAddress(pos.latitude, pos.longitude);
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _addressLine = 'Current Location';
      });
    }

    // Live updates
    try {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position livePos) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(livePos.latitude, livePos.longitude);
          });
          _mapController.move(_currentLocation, _mapController.camera.zoom);
        }
      });
    } catch (e) {
      debugPrint('Position stream error: $e');
    }
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    try {
      final url =
          'https://photon.komoot.io/reverse?lon=$lng&lat=$lat';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'StreetPartnerApp/1.0'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List<dynamic>;
        if (features.isNotEmpty) {
          final props = features[0]['properties'];
          final name = props['name'] ?? props['street'] ?? '';
          final city = props['city'] ?? props['county'] ?? '';
          final state = props['state'] ?? '';
          final country = props['country'] ?? '';

          if (mounted) {
            setState(() {
              _addressLine = name.isNotEmpty ? name : city;
              _subAddress = [city, state, country]
                  .where((s) => s.isNotEmpty && s != _addressLine)
                  .join(', ');
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.myLocation ?? 'My Location',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Full-screen map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: 16.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.streetpartner',
                    ),
                    // Soft glow circle around user
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _currentLocation,
                          color: AppTheme.primary.withOpacity(0.1),
                          borderColor: AppTheme.primary.withOpacity(0.3),
                          borderStrokeWidth: 1.5,
                          radius: 60,
                          useRadiusInMeter: true,
                        ),
                      ],
                    ),
                    // User marker
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation,
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Bottom address card
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live indicator
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context)?.live ?? 'LIVE',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Address
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: AppTheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _addressLine,
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.onBackground,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_subAddress.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _subAddress,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppTheme.onSurfaceMid,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Coordinates
                        Padding(
                          padding: const EdgeInsets.only(left: 48),
                          child: Text(
                            '${_currentLocation.latitude.toStringAsFixed(4)}° N, ${_currentLocation.longitude.toStringAsFixed(4)}° E',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.onSurfaceMid.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Recenter FAB
                Positioned(
                  bottom: 200,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter',
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController.move(_currentLocation, 16.0);
                    },
                    child: Icon(
                      Icons.my_location_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
