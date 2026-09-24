import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/sos_button.dart';
import '../widgets/feature_card.dart';
import '../services/sos_service.dart';
import '../services/admin_database_service.dart';
import '../services/emergency_services_service.dart';

/// Home Dashboard — Figma node 1:149
/// AppBar with logo + profile avatar, large SOS button centered, 2x2 feature grid
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _isModalOpen = false;
  int _secondsLeft = 10;
  bool _isLiveLocationActive = false;
  bool _isBackgroundProtectionEnabled = false;

  String? _currentPlaceName;
  String? _currentCoordsText;
  Position? _currentPosition;
    bool _isLoadingLocation = true;
  StreamSubscription<Position>? _positionStreamSub;
  DateTime? _lastReverseGeocodeTime;
  
  List<String> _targetNumbers = ['112', '911'];
  String _userName = 'Unknown User';
  String _userBloodGroup = 'Unknown';
  String _userMobileNumber = 'Unknown';

  StreamSubscription<Map<dynamic, dynamic>>? _timerSubscription;
  StateSetter? _modalSetState;

  @override
  void initState() {
    super.initState();
    // Auto-request Android OS permissions (CALL_PHONE, SEND_SMS, GPS Location, Notifications)
    SosService.requestPermissions().then((_) {
      _initRealtimeLocation();
      _fetchEmergencyContacts().then((_) {
        _loadProtectionState();
      });
      // Start background prefetch of nearby emergency services for instant opening
      EmergencyServicesService.prefetchEmergencyServicesInBackground();
    });

    // Listen to timer ticks from Native Foreground Service
    _timerSubscription = SosService.timerTickStream.listen((event) {
      if (!mounted) return;

      int tick = event['secondsLeft'] ?? -1;
      bool isRouteDeviation = event['isRouteDeviation'] ?? false;

      if (tick > 0) {
        _secondsLeft = tick;
        if (!_isModalOpen) {
          SosService.playSiren();
          _showSosCountdownDialog(isRouteDeviation);
        } else {
          _modalSetState?.call(() {});
        }
      } else if (tick == 0) {
        // Countdown finished, alert is dispatching
        SosService.stopSiren();
        if (_isModalOpen) {
          _isModalOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        _onSosDispatched();
      } else if (tick == -1) {
        // Countdown cancelled
        SosService.stopSiren();
        if (_isModalOpen) {
          _isModalOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS Alert & Alarm Siren cancelled.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProtectionState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBackgroundProtectionEnabled = prefs.getBool('background_protection') ?? false;
    });
    if (_isBackgroundProtectionEnabled) {
      _initializeSosService();
    } else {
      SosService.stopForegroundService();
    }
  }

  Future<void> _toggleProtection(bool value) async {
    setState(() {
      _isBackgroundProtectionEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_protection', value);

    if (value) {
      _initializeSosService();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active Protection Mode Enabled.')),
      );
    } else {
      SosService.stopForegroundService();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active Protection Mode Disabled.')),
      );
    }
  }

  Future<void> _initRealtimeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _currentPlaceName = 'GPS Turned Off';
            _currentCoordsText = 'Tap to enable Device Location';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _currentPlaceName = 'Location Permission Required';
            _currentCoordsText = 'Tap to grant GPS permission';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      // 1. INSTANT FALLBACK: Get last known position immediately (<0.1s!)
      Position? lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        _updateLocationUI(lastPos);
      }

      // 2. REAL-TIME STREAM: Subscribe to live position updates
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position pos) {
        if (mounted) {
          _updateLocationUI(pos);
        }
      }, onError: (_) {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPlaceName = 'Current Location';
          _currentCoordsText = 'Tap to view Geofencing Hub';
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _updateLocationUI(Position pos) {
      _currentPosition = pos;
      
      if (_isLiveLocationActive) {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
        AdminDatabaseService.updateEmergencyLocation(userId, pos.latitude, pos.longitude);
      }
    String latStr = pos.latitude.toStringAsFixed(4);
    String lngStr = pos.longitude.toStringAsFixed(4);
    String coordsText = 'Coordinates: $latStr, $lngStr';

    setState(() {
      _currentCoordsText = coordsText;
      if (_currentPlaceName == null || _currentPlaceName == 'Fetching current location...' || _currentPlaceName == 'GPS Turned Off') {
        _currentPlaceName = 'Lat: $latStr, Lng: $lngStr';
      }
      _isLoadingLocation = false;
    });

    // Throttle OpenStreetMap Nominatim reverse geocoding to 1 call per 5 seconds
    final now = DateTime.now();
    if (_lastReverseGeocodeTime == null ||
        now.difference(_lastReverseGeocodeTime!) > const Duration(seconds: 5)) {
      _lastReverseGeocodeTime = now;
      _reverseGeocodeOSM(pos.latitude, pos.longitude);
    }
  }

  Future<void> _reverseGeocodeOSM(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=16',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'StreetPartnerSafetyApp/1.0 (contact: support@streetpartner.app)',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        if (address != null) {
          String name = address['suburb'] ??
              address['neighbourhood'] ??
              address['residential'] ??
              address['road'] ??
              address['city_district'] ??
              address['city'] ??
              address['town'] ??
              address['village'] ??
              address['county'] ??
              '';
          String city = address['city'] ?? address['state'] ?? '';
          String placeResult = '';
          if (name.isNotEmpty && city.isNotEmpty && name != city) {
            placeResult = '$name, $city';
          } else if (name.isNotEmpty) {
            placeResult = name;
          } else if (city.isNotEmpty) {
            placeResult = city;
          } else {
            placeResult = data['display_name']?.split(',').take(2).join(',') ?? '';
          }

          if (placeResult.isNotEmpty && mounted) {
            setState(() {
              _currentPlaceName = placeResult;
            });
          }
        }
      }
    } catch (_) {
      // Fallback coordinates are already safely displayed on UI
    }
  }

  Future<void> _fetchEmergencyContacts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final contacts =
              (data['emergencyContacts'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (contacts.isNotEmpty) {
            _targetNumbers = contacts;
          }
          if (mounted) {
            setState(() {
              _userName = data['fullName'] ?? user.displayName ?? 'Unknown User';
            _userBloodGroup = data['bloodGroup'] ?? 'Unknown';
            _userMobileNumber = data['phoneNumber'] ?? user.phoneNumber ?? 'Unknown';
            });
          }

          // Push the new contacts to the native background service if it is running!
          if (mounted && _isBackgroundProtectionEnabled) {
            _initializeSosService();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data for SOS: $e');
    }
  }

  Future<void> _initializeSosService() async {
    SosService.startSosService(
      phoneNumbers: _targetNumbers,
      message: 'EMERGENCY SOS: $_userName needs immediate assistance! Live Location: https://streetpartner.web.app/?session=${FirebaseAuth.instance.currentUser?.uid ?? "unknown"}',
                        userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
    );
  }

  void _onSosPressed() {
    // Manually trigger the native foreground countdown
    SosService.triggerSosCountdown(
      phoneNumbers: _targetNumbers,
      message: 'EMERGENCY SOS: $_userName needs immediate assistance! Live Location: https://streetpartner.web.app/?session=${FirebaseAuth.instance.currentUser?.uid ?? "unknown"}'
    );
  }

  void _showSosCountdownDialog(bool isRouteDeviation) {
    if (_isModalOpen) return;
    _isModalOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            _modalSetState = setModalState;

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.sosRed, width: 2),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.volume_up_rounded,
                    color: AppTheme.sosRed,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRouteDeviation ? 'ROUTE DEVIATION' : 'EMERGENCY SOS',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isRouteDeviation 
                        ? 'You have deviated from your safe route!' 
                        : 'Emergency alarm sounding.',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.sosRed,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_secondsLeft',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isRouteDeviation
                        ? 'Tap REROUTE to update your path, or SOS will dispatch in 20s.'
                        : 'Tap STOP SOS within 10s to stop siren, calls, and SMS messages.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              actions: [
                if (isRouteDeviation)
                  TextButton(
                    onPressed: () {
                      SosService.stopSosCountdown();
                      _mockRerouteAndResume();
                    },
                    child: Text(
                      'REROUTE',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () {
                      SosService.stopSosCountdown();
                      SosService.stopMonitoring();
                    },
                    child: Text(
                      'STOP SOS',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.sosRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    SosService.triggerSosAlert(
                      phoneNumbers: _targetNumbers,
                      message: 'EMERGENCY SOS: $_userName needs immediate assistance! Live Location: https://streetpartner.web.app/?session=${FirebaseAuth.instance.currentUser?.uid ?? "unknown"}',
                        userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown'
                    );
                    _onSosDispatched();
                  },
                  child: Text(
                    'SEND NOW',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _isModalOpen = false;
      _modalSetState = null;
    });
  }

  void _mockRerouteAndResume() async {
    if (_isModalOpen) {
      _isModalOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rerouting... Fetching new directions.')),
    );
    
    try {
      final prefs = await SharedPreferences.getInstance();
      double? destLat = prefs.getDouble('route_dest_lat');
      double? destLng = prefs.getDouble('route_dest_lng');
      if (destLat == null || destLng == null) throw Exception('No destination saved.');

      // Get current location
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      // Fetch from OSRM
      final url = 'http://router.project-osrm.org/route/v1/driving/${pos.longitude},${pos.latitude};$destLng,$destLat?geometries=geojson';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        
        List<Map<String, double>> newPolyline = coords.map((c) => {
          'lat': (c[1] as num).toDouble(),
          'lng': (c[0] as num).toDouble(),
        }).toList();
        
        await SosService.updateRouteMonitoring(newPolyline);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Route updated! Resuming Route Guard.')),
          );
        }
      } else {
        throw Exception('Failed to fetch route');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reroute: $e')),
        );
      }
    }
  }

  void _onSosDispatched() {
    SosService.stopMonitoring();
    
    // Add to secondary database
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final locationLink = 'https://streetpartner.web.app/?session=$userId';
      AdminDatabaseService.reportEmergencyToAdmin(
        userId: userId,
        userName: _userName,
        bloodGroup: _userBloodGroup,
        mobileNumber: _userMobileNumber,
        liveLocationLink: locationLink,
        lat: _currentPosition?.latitude,
        lng: _currentPosition?.longitude,
      );

    if (mounted) {
      setState(() {
        _isLiveLocationActive = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🚨 Emergency dispatched! Live location active.',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.sosRed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _stopLiveLocation() {
    SosService.stopLiveLocation();
    
    // Clear from secondary database
    AdminDatabaseService.clearEmergencyFromAdmin(
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
    );
    
    setState(() {
      _isLiveLocationActive = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Live location tracking stopped.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            if (_isLiveLocationActive) _buildLiveLocationBanner(),

            // ── Live Location & Geofencing Card ────────────────────────
            _buildLiveLocationCard(context),

            // ── SOS Button Section ──────────────────────────────────────
            _buildSosSection(context),

            // ── Background Protection Toggle ────────────────────────────
            _buildProtectionToggle(),

            const SizedBox(height: 24),

            // ── Quick Features Grid ─────────────────────────────────────
            _buildFeatureGrid(context),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xCCF8F9FA),
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          // App Logo icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Home Dashboard',
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
        // Profile avatar button (Figma node 1:229)
        GestureDetector(
          onTap: () async {
            await Navigator.pushNamed(context, '/profile');
            // Check if we logged out and the screen was disposed
            if (!mounted) return;
            // Refresh contacts in case they were updated
            await _fetchEmergencyContacts();
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryLight,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveLocationCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_currentPlaceName == 'GPS Turned Off') {
              Geolocator.openLocationSettings();
            } else if (_currentPlaceName == 'Location Permission Required') {
              SosService.requestPermissions().then((_) => _initRealtimeLocation());
            } else {
              Navigator.pushNamed(context, '/safety-index');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppTheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'LIVE LOCATION & SAFETY INDEX',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoadingLocation
                            ? 'Fetching current location...'
                            : (_currentPlaceName ?? 'Current Location'),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onBackground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isLoadingLocation
                            ? 'Locating via GPS...'
                            : (_currentCoordsText ?? 'Tap to configure Geofence & Route Guard'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.onSurfaceLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onSurfaceLight,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveLocationBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.sosRedContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sosRed),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppTheme.sosRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live Location Active',
                  style: GoogleFonts.inter(
                    color: AppTheme.sosRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your location is being shared with emergency contacts.',
            style: GoogleFonts.inter(
              color: AppTheme.onSurfaceMid,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sosRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Stop Live Location?'),
                    content: const Text('Are you sure you are safe and want to stop sharing your location?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _stopLiveLocation();
                        },
                        child: const Text('Stop Sharing', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('I am Safe - Stop Sharing'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // SOS Button with pulse animation and active/loading state
          SosButton(
            isActive: false,
            isLoading: false,
            onPressed: _onSosPressed,
          ),
          const SizedBox(height: 24),
          // Description text (Figma node 1:164)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap to launch 3s countdown\nalerts trusted contacts & local authorities.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.onSurfaceMid,
                fontWeight: FontWeight.normal,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        title: Text(
          'Active Protection Mode',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppTheme.onBackground,
          ),
        ),
        subtitle: Text(
          'Keep SOS ready in background via notification & shake-to-trigger when outdoors.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.onSurfaceMid,
            height: 1.4,
          ),
        ),
        value: _isBackgroundProtectionEnabled,
        activeThumbColor: AppTheme.primary,
        onChanged: _toggleProtection,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isBackgroundProtectionEnabled 
                ? AppTheme.primaryLight.withValues(alpha: 0.2) 
                : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isBackgroundProtectionEnabled ? Icons.shield_rounded : Icons.shield_outlined,
            color: _isBackgroundProtectionEnabled ? AppTheme.primary : Colors.grey,
            size: 22,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    // 2x2 grid data (Figma nodes 1:171, 1:181, 1:191, 1:200)
    final features = [
      _FeatureData(
        icon: Icons.radar_rounded,
        iconBg: const Color(0xFF2A73E1),
        iconColor: Colors.white,
        title: 'Fencing',
        description: 'Geo & Route\nperimeters.',
        route: '/fencing-hub',
      ),
      _FeatureData(
        icon: Icons.phone_in_talk_rounded,
        iconBg: const Color(0xFF1A73E8),
        iconColor: Colors.white,
        title: 'Fake Call',
        description: 'Schedule a simulated\nincoming call.',
        route: '/fake-call',
      ),
_FeatureData(
        icon: Icons.emergency_rounded,
        iconBg: AppTheme.sosRedContainer,
        iconColor: AppTheme.sosRed,
        title: 'Emergency',
        description: 'Quick access to\npolice and fire.',
        route: '/emergency-services',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              'Quick Features',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.onBackground,
              ),
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.80,
            children: features
                .map(
                  (f) => FeatureCard(
                    icon: f.icon,
                    iconBgColor: f.iconBg,
                    iconColor: f.iconColor,
                    title: f.title,
                    description: f.description,
                    onTap: () => Navigator.pushNamed(context, f.route),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String description;
  final String route;

  const _FeatureData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.route,
  });
}
