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
import '../services/sos_service.dart';
import '../services/admin_database_service.dart';
import '../services/emergency_services_service.dart';
import 'package:streetpartner/main.dart';
import 'package:streetpartner/l10n/app_localizations.dart';

/// Home Dashboard â€” Figma node 1:149
/// AppBar with logo + profile avatar, large SOS button centered, 2x2 feature grid
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> with WidgetsBindingObserver {
  bool _isModalOpen = false;
  int _secondsLeft = 10;
  bool _isLiveLocationActive = false;
  bool _manualAlertTriggered = false;
  bool _isBackgroundProtectionEnabled = false;

  String? _currentPlaceName;
  String? _currentCoordsText;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  StreamSubscription<Position>? _positionStreamSub;
  DateTime? _lastReverseGeocodeTime;
  
  List<String> _targetNumbers = [];
  String _userName = 'Unknown User';
  String _userBloodGroup = 'Unknown';
  String _userMobileNumber = 'Unknown';

  StreamSubscription<Map<dynamic, dynamic>>? _timerSubscription;
  StateSetter? _modalSetState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Sync state with native background service immediately on startup
    _syncWithServiceState();

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
      String? triggerFromNative = event['triggerSource'] as String?;
      if (triggerFromNative != null && triggerFromNative.isNotEmpty) {
        _activeTriggerSource = triggerFromNative;
      }

      if (tick > 0) {
        // If live location is already active from a previous dispatch, ignore duplicate countdowns
        if (_isLiveLocationActive) return;

        _secondsLeft = tick;
        if (!_isModalOpen) {
          if (!_manualAlertTriggered) { SosService.playSiren(); }
          _showSosCountdownDialog(isRouteDeviation);
        } else {
          _modalSetState?.call(() {});
        }
      } else if (tick == 0) {
        _manualAlertTriggered = false;
        // Countdown finished, alert is dispatching
        SosService.stopSiren();
        if (_isModalOpen) {
          _isModalOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (!_isLiveLocationActive) {
          _onSosDispatched();
        }
      } else if (tick == -1) {
        _manualAlertTriggered = false;
        // Countdown cancelled
        SosService.stopSiren();
        if (_isModalOpen) {
          _isModalOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.sosAlertAlarmSirenCancelled ?? 'SOS Alert & Alarm Siren cancelled.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncWithServiceState();
    }
  }

  Future<void> _syncWithServiceState() async {
    try {
      final status = await SosService.getServiceStatus();
      if (!mounted) return;

      bool isLiveActive = status['isLiveLocationActive'] == true;
      final bool isCountingDown = status['isCountingDown'] == true;
      final int secondsLeft = (status['secondsLeft'] as num?)?.toInt() ?? -1;
      final bool isRouteDeviation = status['isRouteDeviation'] == true;
      final String? triggerSource = status['triggerSource'] as String?;

      if (triggerSource != null && triggerSource.isNotEmpty) {
        _activeTriggerSource = triggerSource;
      }

      // Check Firestore active emergency if native state did not report liveActive
      if (!isLiveActive && !isCountingDown) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final activeDocs = await FirebaseFirestore.instance
                .collection('emergencies')
                .where('userId', isEqualTo: user.uid)
                .where('isActive', isEqualTo: true)
                .limit(1)
                .get();
            if (activeDocs.docs.isNotEmpty) {
              isLiveActive = true;
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;

      if (isLiveActive) {
        // Native background service already dispatched the emergency
        SosService.stopSiren();
        if (_isModalOpen) {
          _isModalOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (!_isLiveLocationActive) {
          setState(() {
            _isLiveLocationActive = true;
          });
        }
      } else if (isCountingDown && secondsLeft > 0) {
        _secondsLeft = secondsLeft;
        if (!_isModalOpen) {
          if (!_manualAlertTriggered) {
            SosService.playSiren();
          }
          _showSosCountdownDialog(isRouteDeviation);
        } else {
          _modalSetState?.call(() {});
        }
      } else if (!isCountingDown && !isLiveActive) {
        if (_isModalOpen) {
          _isModalOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (_isLiveLocationActive) {
          setState(() {
            _isLiveLocationActive = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error syncing with native service state: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerSubscription?.cancel();
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProtectionState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBackgroundProtectionEnabled = prefs.getBool('background_protection') ?? true;
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
    } else {
      SosService.stopForegroundService();
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
      final prefs = await SharedPreferences.getInstance();
      // Load cached contacts immediately so we never send SMS to emergency services
      final cachedContacts = prefs.getStringList('cached_emergency_contacts') ?? [];
      const emergencyServiceNumbers = {'112', '911', '100', '101', '108'};
      if (cachedContacts.isNotEmpty) {
        _targetNumbers = cachedContacts.where((n) => !emergencyServiceNumbers.contains(n.trim())).toList();
      }

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
                  ?.map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty && !emergencyServiceNumbers.contains(e))
                  .toList() ??
              [];
          if (contacts.isNotEmpty) {
            _targetNumbers = contacts;
            await prefs.setStringList('cached_emergency_contacts', contacts);
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
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown';

    if (_targetNumbers.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final cachedContacts = prefs.getStringList('cached_emergency_contacts') ?? [];
      const emergencyServiceNumbers = {'112', '911', '100', '101', '108'};
      _targetNumbers = cachedContacts.where((n) => !emergencyServiceNumbers.contains(n.trim())).toList();
    }

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user.uid);
    }

    SosService.startSosService(
      phoneNumbers: _targetNumbers,
      message: 'EMERGENCY SOS: $_userName needs immediate assistance!',
      userId: userId,
    );
  }

  void _onSosPressed() async {
    if (_isLiveLocationActive) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)?.cancelEmergency ?? 'Cancel Emergency?'),
          content: Text(AppLocalizations.of(context)?.areYouSureYouWantToStopSharing ?? 'Are you sure you want to stop sharing your live location and cancel the SOS alert?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)?.cancel1 ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _stopLiveLocation();
              },
              child: Text(AppLocalizations.of(context)?.stopSharing ?? 'Stop Sharing', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return;
    }
    
    _manualAlertTriggered = true;
    final user = FirebaseAuth.instance.currentUser;
    if (_targetNumbers.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final cachedContacts = prefs.getStringList('cached_emergency_contacts') ?? [];
      const emergencyServiceNumbers = {'112', '911', '100', '101', '108'};
      _targetNumbers = cachedContacts.where((n) => !emergencyServiceNumbers.contains(n.trim())).toList();
    }

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user.uid);
    }

    // Manually trigger the native foreground countdown
    SosService.triggerSosCountdown(
      phoneNumbers: _targetNumbers,
      message: 'EMERGENCY SOS: $_userName needs immediate assistance!',
      userId: user?.uid ?? 'unknown',
    );
  }

  String _activeTriggerSource = 'SOS Button';

  void _showSosCountdownDialog(bool isRouteDeviation, {String? triggerSource}) {
    if (triggerSource != null) {
      _activeTriggerSource = triggerSource;
    }
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
              backgroundColor: AppTheme.background,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: AppTheme.sosRed,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRouteDeviation ? 'ROUTE DEVIATION' : 'EMERGENCY SOS',
                      style: GoogleFonts.inter(
                        color: AppTheme.onBackground,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
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
                      color: AppTheme.onSurfaceMid,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFB45309)),
                        const SizedBox(width: 6),
                        Text(
                          'Triggered by: $_activeTriggerSource',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFB45309),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.sosRedContainer,
                      border: Border.all(color: AppTheme.sosRed, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_secondsLeft',
                      style: GoogleFonts.inter(
                        color: AppTheme.sosRed,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isRouteDeviation
                        ? 'Tap REROUTE to update your path, or SOS will dispatch in 20s.'
                        : 'Tap CANCEL within 10s to stop siren and prevent SMS alerts.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppTheme.onSurfaceMid,
                      fontSize: 13,
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
                    child: Text(AppLocalizations.of(context)?.reroute ?? 'REROUTE',
                      style: GoogleFonts.inter(
                        color: AppTheme.primary,
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
                    child: Text(AppLocalizations.of(context)?.cancel ?? 'CANCEL',
                      style: GoogleFonts.inter(
                        color: AppTheme.onSurfaceMid,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.sosRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
                    final emergencyId = await AdminDatabaseService.reportEmergencyToAdmin(
                      userId: userId,
                      userName: _userName,
                      bloodGroup: _userBloodGroup,
                      mobileNumber: _userMobileNumber,
                      liveLocationLink: '',
                      lat: _currentPosition?.latitude,
                      lng: _currentPosition?.longitude,
                      triggerSource: _activeTriggerSource,
                    );
                    final link = 'https://streetpartner.web.app/?session=${emergencyId ?? userId}';
                    SosService.triggerSosAlert(
                      phoneNumbers: _targetNumbers,
                      message: 'EMERGENCY SOS: $_userName needs immediate assistance! Live Location: $link',
                      userId: userId,
                      emergencyId: emergencyId,
                    );
                    _onSosDispatched(emergencyId);
                  },
                  child: Text(
                    isRouteDeviation ? 'DISPATCH NOW' : 'SEND NOW',
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
        SnackBar(content: Text(AppLocalizations.of(context)?.reroutingFetchingNewDirections ?? 'Rerouting... Fetching new directions.')),
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
              SnackBar(content: Text(AppLocalizations.of(context)?.routeUpdatedResumingRouteGuard ?? 'Route updated! Resuming Route Guard.')),
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

  void _onSosDispatched([String? passedEmergencyId]) async {
    SosService.stopMonitoring();
    
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    if (passedEmergencyId == null) {
      await AdminDatabaseService.reportEmergencyToAdmin(
        userId: userId,
        userName: _userName,
        bloodGroup: _userBloodGroup,
        mobileNumber: _userMobileNumber,
        liveLocationLink: '',
        lat: _currentPosition?.latitude,
        lng: _currentPosition?.longitude,
        triggerSource: _activeTriggerSource,
      );
    }

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
                child: Text(AppLocalizations.of(context)?.emergencyDispatchedLiveLocatio ?? 'Emergency dispatched! Live location active.',
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

    _manualAlertTriggered = false;
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
        content: Text(AppLocalizations.of(context)?.liveLocationTrackingStopped ?? 'Live location tracking stopped.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/ai-assistant');
        },
        backgroundColor: Colors.blue[800],
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            if (_isLiveLocationActive) _buildLiveLocationBanner(),

            // â”€â”€ Live Location & Geofencing Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildLiveLocationCard(context),

            // â”€â”€ SOS Button Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildSosSection(context),

            // â”€â”€ Background Protection Toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildProtectionToggle(),

            const SizedBox(height: 24),

            // â”€â”€ Quick Features Grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildFeatureGrid(context),

            const SizedBox(height: 24),

            // Bottom Banner
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/stay_safe_banner.jpg',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),

            const SizedBox(height: 80),
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
            child: Text(AppLocalizations.of(context)?.homeDashboard ?? 'Home Dashboard',
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
        ValueListenableBuilder<Locale>(
          valueListenable: appLocale,
          builder: (context, currentLocale, child) {
            return PopupMenuButton<Locale>(
              icon: const Icon(Icons.translate, size: 28, color: Colors.black87),
              onSelected: (Locale locale) {
                appLocale.value = locale;
              },
              itemBuilder: (BuildContext context) {
                final activeLocale = currentLocale.languageCode;
                PopupMenuItem<Locale> buildItem(String code, String label) {
                  final isSelected = activeLocale == code;
                  return PopupMenuItem<Locale>(
                    value: Locale(code),
                    child: Row(
                      children: [
                        Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppTheme.primary : Colors.black87)),
                        if (isSelected) const Spacer(),
                        if (isSelected) const Icon(Icons.check, color: AppTheme.primary, size: 20),
                      ],
                    ),
                  );
                }
                return <PopupMenuEntry<Locale>>[
                  buildItem('en', 'English'),
                  buildItem('hi', 'हिंदी'),
                  buildItem('te', 'తెలుగు'),
                  buildItem('ta', 'தமிழ்'),
                  buildItem('ml', 'മലയാളം'),
                  buildItem('kn', 'ಕನ್ನಡ'),
                ];
              },
            );
          },
        ),
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
                            child: Text(AppLocalizations.of(context)?.liveLocationSafetyIndex ?? 'LIVE LOCATION & SAFETY INDEX',
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
                          Text(AppLocalizations.of(context)?.active ?? 'Active',
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
                child: Text(AppLocalizations.of(context)?.liveLocationActive ?? 'Live Location Active',
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
          Text(AppLocalizations.of(context)?.yourLocationIsBeingSharedWithE ?? 'Your location is being shared with emergency contacts.',
            style: GoogleFonts.inter(
              color: AppTheme.onSurfaceMid,
              fontSize: 14,
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
          Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/sos_shield.png',
                width: 320,
                height: 320,
                fit: BoxFit.contain,
              ),
              SosButton(
                isActive: _isLiveLocationActive,
                isLoading: false,
                onPressed: _onSosPressed,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Description text (Figma node 1:164)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _isLiveLocationActive 
                ? '🚨 SOS ALERT ACTIVE\nPress again to cancel or stop sharing location.' 
                : AppLocalizations.of(context)?.sosTriggerDesc ?? 'Press to trigger a 10-second emergency countdown.\nAlerts trusted contacts & sounds a siren.',
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
        title: Text(AppLocalizations.of(context)?.activeProtectionMode ?? 'Active Protection Mode',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppTheme.onBackground,
          ),
        ),
        subtitle: Text(AppLocalizations.of(context)?.keepSosReadyInBackgroundViaNot ?? 'Keep SOS ready in background with shake-to-trigger detection when outdoors.',
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
        icon: Icons.my_location_rounded,
        iconBg: const Color(0xFF2A73E1),
        iconColor: Colors.white,
        title: AppLocalizations.of(context)?.geoFencingTitle ?? 'Geo-Fencing',
        description: 'Safe perimeter\ncircular zone.',
        route: '/geofencing',
      ),
      _FeatureData(
        icon: Icons.navigation_rounded,
        iconBg: const Color(0xFF10B981),
        iconColor: Colors.white,
        title: 'Navigation',
        description: 'Safe routes &\ndirections.',
        route: '/navigation',
      ),
      _FeatureData(
        icon: Icons.phone_in_talk_rounded,
        iconBg: const Color(0xFF1A73E8),
        iconColor: Colors.white,
        title: AppLocalizations.of(context)?.fakeCallFeature ?? 'Fake Call',
        description: AppLocalizations.of(context)?.fakeCallFeatureDesc ?? 'Schedule a simulated\nincoming call.',
        route: '/fake-call',
      ),
      _FeatureData(
        icon: Icons.emergency_rounded,
        iconBg: AppTheme.sosRedContainer,
        iconColor: AppTheme.sosRed,
        title: AppLocalizations.of(context)?.emergencyFeature ?? 'Emergency',
        description: AppLocalizations.of(context)?.emergencyFeatureDesc ?? 'Quick access to\npolice and fire.',
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
            child: Text(AppLocalizations.of(context)?.quickFeatures ?? 'Quick Features',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.onBackground,
              ),
            ),
          ),
          Column(
            children: features.map((f) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, f.route);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: f.iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(f.icon, color: f.iconColor, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.title,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.onBackground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                f.description.replaceAll('\n', ' '),

                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.onSurfaceMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
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







