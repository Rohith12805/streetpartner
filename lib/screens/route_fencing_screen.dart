import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/sos_service.dart';

class RouteFencingScreen extends StatefulWidget {
  const RouteFencingScreen({super.key});

  @override
  State<RouteFencingScreen> createState() => _RouteFencingScreenState();
}

class _RouteFencingScreenState extends State<RouteFencingScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  Timer? _routeDebounce;
  List<dynamic> _searchResults = [];

  LatLng _currentLocation = const LatLng(37.7749, -122.4194);
  LatLng _destination = const LatLng(37.7749, -122.4194);
  List<LatLng> _routePolyline = [];
  bool _isLoading = true;
  bool _isRouteActive = false;
  
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _routeDebounce?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _destination = _currentLocation;
        _isLoading = false;
      });
      _mapController.move(_currentLocation, 15.0);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final url = 'https://photon.komoot.io/api/?q=$query&limit=5';
        final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'StreetPartnerApp/1.0'});
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _searchResults = data['features'] as List<dynamic>;
          });
        }
      } catch (e) {
        debugPrint('Photon search failed: $e');
      }
    });
  }

  void _selectSearchResult(dynamic feature) {
    FocusScope.of(context).unfocus();
    final coords = feature['geometry']['coordinates'] as List; // Photon returns [lon, lat]
    final lat = (coords[1] as num).toDouble();
    final lon = (coords[0] as num).toDouble();
    
    final props = feature['properties'];
    final name = props['name'] ?? 'Selected Location';
    
    setState(() {
      _searchCtrl.text = name;
      _searchResults = [];
      _destination = LatLng(lat, lon);
    });
    
    _mapController.move(_destination, 15.0);
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    setState(() => _isLoading = true);
    
    try {
      final url = 'http://router.project-osrm.org/route/v1/driving/${_currentLocation.longitude},${_currentLocation.latitude};${_destination.longitude},${_destination.latitude}?geometries=geojson';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        
        setState(() {
          _routePolyline = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fetch route.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchReverseGeocode() async {
    try {
      final url = 'https://photon.komoot.io/reverse?lon=${_destination.longitude}&lat=${_destination.latitude}';
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'StreetPartnerApp/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List<dynamic>;
        if (features.isNotEmpty) {
          final props = features[0]['properties'];
          final name = props['name'] ?? props['street'] ?? props['city'] ?? 'Selected Location';
          if (mounted) {
            setState(() {
              _searchCtrl.text = name;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
    }
  }

  void _onMapPositionChanged(MapCamera position, bool hasGesture) {
    if (!_isRouteActive && hasGesture && position.center != null) {
      setState(() {
        _destination = position.center!;
      });
      
      _routeDebounce?.cancel();
      _routeDebounce = Timer(const Duration(milliseconds: 800), () {
        _fetchReverseGeocode();
        _fetchRoute();
      });
    }
  }

  Future<void> _startRouteGuard() async {
    if (_routePolyline.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a destination and calculate a route first.')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('route_dest_lat', _destination.latitude);
    await prefs.setDouble('route_dest_lng', _destination.longitude);

    List<Map<String, double>> mappedPolyline = _routePolyline.map((ll) => {
      'lat': ll.latitude,
      'lng': ll.longitude,
    }).toList();

    await SosService.startRouteMonitoring(mappedPolyline);

    setState(() {
      _isRouteActive = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Route Guard Active! Diverting 100m from this path will trigger SOS.'),
      backgroundColor: Colors.green,
    ));

    // Track live location to auto-stop when arrived
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position pos) {
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
      
      const distance = Distance();
      final distToDest = distance.as(LengthUnit.Meter, _currentLocation, _destination);
      if (distToDest < 50 && _isRouteActive) {
        _stopRouteGuard(autoStop: true);
      }
    });
  }

  void _stopRouteGuard({bool autoStop = false}) {
    SosService.stopMonitoring();
    _positionStream?.cancel();
    
    if (mounted) {
      setState(() {
        _isRouteActive = false;
        _routePolyline.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(autoStop ? 'You arrived safely! Route Guard disabled.' : 'Route Guard stopped.'),
        backgroundColor: autoStop ? Colors.green : Colors.grey.shade800,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Route Fencing',
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
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
              onPositionChanged: _onMapPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.streetpartner',
              ),
              if (_routePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePolyline,
                      color: Colors.blueAccent,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
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

          // Center reticle for selecting destination
          if (!_isRouteActive)
            const Center(
              child: Icon(Icons.location_on, color: Colors.red, size: 40),
            ),

          // Search Bar & Autocomplete
          if (!_isRouteActive)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search destination...',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final feature = _searchResults[i];
                          final props = feature['properties'];
                          final name = props['name'] ?? 'Unknown';
                          final state = props['state'] ?? '';
                          final country = props['country'] ?? '';
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(name),
                            subtitle: Text([state, country].where((s) => s.isNotEmpty).join(', ')),
                            onTap: () => _selectSearchResult(feature),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

          // Bottom Action Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: _isRouteActive
                  ? SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _stopRouteGuard,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('STOP FENCING'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.grey.shade800,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: _startRouteGuard,
                            icon: const Icon(Icons.shield_rounded),
                            label: const Text('START ROUTE GUARD'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
