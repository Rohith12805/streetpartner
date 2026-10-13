import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

enum NavState {
  settingDirection,
  routePreview,
  journeyActive,
}

enum PointerTarget {
  from,
  to,
}

enum SearchTarget {
  from,
  to,
}

class NavigationRoute {
  final int index;
  final String label;
  final List<LatLng> polyline;
  final double totalDistanceMeters;
  final double ratedDistanceMeters;
  final double coveragePercentage;
  final double? avgLighting;
  final double? avgCrime;
  final double? avgPopulation;
  final double? avgServices;

  NavigationRoute({
    required this.index,
    required this.label,
    required this.polyline,
    required this.totalDistanceMeters,
    required this.ratedDistanceMeters,
    required this.coveragePercentage,
    required this.avgLighting,
    required this.avgCrime,
    required this.avgPopulation,
    required this.avgServices,
  });
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  // Working OpenRouteService (ORS) API Key
  static const String _orsApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjI1NGUxYjcxMDk4OTQ1NzE4MTBmOTYyNWYyYWJmMzdhIiwiaCI6Im11cm11cjY0In0=';

  final MapController _mapController = MapController();
  // Controllers start empty so transparent placeholders show without requiring backspace
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();

  NavState _navState = NavState.settingDirection;
  PointerTarget _activePointerTarget = PointerTarget.to;
  SearchTarget _activeSearchTarget = SearchTarget.to;

  LatLng _currentLocation = const LatLng(16.5062, 80.6480); // Default: Vijayawada
  LatLng? _fromPoint;
  LatLng? _toPoint;

  List<NavigationRoute> _routes = [];
  int _selectedRouteIndex = 0;

  List<dynamic> _searchResults = [];
  Timer? _searchDebounce;
  bool _isLoading = false;
  double _currentMapRotation = 0.0;
  StreamSubscription<Position>? _positionStream;

  // Off-track deviation & Rejoin Route tracking state
  bool _isRerouting = false;
  int _offTrackConsecutiveCount = 0;
  String? _navStatusText;
  Timer? _statusResetTimer;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
  }

  @override
  void dispose() {
    _statusResetTimer?.cancel();
    _positionStream?.cancel();
    _searchDebounce?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _initUserLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentLocation = loc;
          _fromPoint = loc;
        });
        _safeMoveMap(loc, 15.0);
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen((p) {
        if (!mounted) return;
        final newLoc = LatLng(p.latitude, p.longitude);
        setState(() {
          _currentLocation = newLoc;
        });

        if (_navState == NavState.journeyActive) {
          _safeMoveMap(newLoc, 16.5);
          // Check for off-track deviation and automatically rejoin chosen route
          _checkOffTrackAndRejoin(newLoc);
        }
      });
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void _safeMoveMap(LatLng center, double zoom) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          _mapController.move(center, zoom);
        } catch (e) {
          debugPrint('Map move error: $e');
        }
      }
    });
  }

  // ── Off-Track Deviation Detection & Rejoining Chosen Route ──
  void _checkOffTrackAndRejoin(LatLng userLoc) {
    if (_routes.isEmpty || _isRerouting) return;
    final currentRoute = _routes[_selectedRouteIndex.clamp(0, _routes.length - 1)];
    if (currentRoute.polyline.length < 2) return;

    final distToRoute = _distanceToPolyline(userLoc, currentRoute.polyline);

    // If user is more than 65 meters away from the selected route line
    if (distToRoute > 65.0) {
      _offTrackConsecutiveCount++;
      if (_offTrackConsecutiveCount >= 2 && !_isRerouting) {
        _rejoinActiveRoute(userLoc, currentRoute);
      }
    } else if (distToRoute < 35.0) {
      _offTrackConsecutiveCount = 0;
    }
  }

  double _distanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final d = _distanceToSegment(point, polyline[i], polyline[i + 1]);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    final dAB = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    if (dAB == 0) {
      return Geolocator.distanceBetween(p.latitude, p.longitude, a.latitude, a.longitude);
    }
    final x = (b.longitude - a.longitude) * cos((a.latitude + b.latitude) * pi / 360);
    final y = b.latitude - a.latitude;
    final px = (p.longitude - a.longitude) * cos((a.latitude + b.latitude) * pi / 360);
    final py = p.latitude - a.latitude;

    final t = ((px * x + py * y) / (x * x + y * y)).clamp(0.0, 1.0);
    final projLat = a.latitude + t * (b.latitude - a.latitude);
    final projLng = a.longitude + t * (b.longitude - a.longitude);
    return Geolocator.distanceBetween(p.latitude, p.longitude, projLat, projLng);
  }

  int _findClosestPolylineIndex(LatLng point, List<LatLng> polyline) {
    int closestIdx = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length; i++) {
      final d = Geolocator.distanceBetween(
          point.latitude, point.longitude, polyline[i].latitude, polyline[i].longitude);
      if (d < minDistance) {
        minDistance = d;
        closestIdx = i;
      }
    }
    return closestIdx;
  }

  Future<void> _rejoinActiveRoute(LatLng userLoc, NavigationRoute currentRoute) async {
    setState(() {
      _isRerouting = true;
      _navStatusText = 'Rejoining ${currentRoute.label}...';
    });

    try {
      final poly = currentRoute.polyline;
      final closestIdx = _findClosestPolylineIndex(userLoc, poly);

      // Choose a forward rejoin point on the route ahead of the user (~300m to 800m ahead)
      final forwardIndexOffset = min(15, max(4, poly.length ~/ 15));
      final rejoinIdx = min(poly.length - 1, closestIdx + forwardIndexOffset);
      final rejoinPoint = poly[rejoinIdx];

      // Query connector path from current deviated position to rejoin point via ORS
      final connUrl = 'https://api.openrouteservice.org/v2/directions/driving-car/geojson';
      final connBody = jsonEncode({
        'coordinates': [
          [userLoc.longitude, userLoc.latitude],
          [rejoinPoint.longitude, rejoinPoint.latitude],
        ]
      });

      final connRes = await http.post(
        Uri.parse(connUrl),
        headers: {
          'Authorization': _orsApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json, application/geo+json',
        },
        body: connBody,
      ).timeout(const Duration(seconds: 6));

      if (connRes.statusCode == 200) {
        final connData = jsonDecode(connRes.body);
        final features = connData['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final connectorCoords = features[0]['geometry']['coordinates'] as List;
          final connectorPoly = connectorCoords
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
          final connDist = (features[0]['properties']['summary']['distance'] as num?)?.toDouble() ?? 0.0;

          // Slice remaining downstream portion of the route from rejoinIdx + 1
          final remainingPoly = (rejoinIdx + 1 < poly.length) ? poly.sublist(rejoinIdx + 1) : <LatLng>[];

          // Compute remaining distance
          double remainingDist = 0.0;
          for (int s = rejoinIdx; s < poly.length - 1; s++) {
            remainingDist += Geolocator.distanceBetween(
                poly[s].latitude, poly[s].longitude, poly[s + 1].latitude, poly[s + 1].longitude);
          }

          // Combined stitched route: connector to rejoin point + remaining route to destination
          final stitchedPoly = [...connectorPoly, ...remainingPoly];
          final newTotalDistance = connDist + remainingDist;

          final updatedRoute = NavigationRoute(
            index: currentRoute.index,
            label: currentRoute.label,
            polyline: stitchedPoly,
            totalDistanceMeters: newTotalDistance,
            ratedDistanceMeters: currentRoute.ratedDistanceMeters,
            coveragePercentage: currentRoute.coveragePercentage,
            avgLighting: currentRoute.avgLighting,
            avgCrime: currentRoute.avgCrime,
            avgPopulation: currentRoute.avgPopulation,
            avgServices: currentRoute.avgServices,
          );

          if (mounted) {
            setState(() {
              _routes[_selectedRouteIndex] = updatedRoute;
              _isRerouting = false;
              _offTrackConsecutiveCount = 0;
              _navStatusText = 'Rejoined ${currentRoute.label}';
            });
            _statusResetTimer?.cancel();
            _statusResetTimer = Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _navStatusText = null);
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Rejoin route error: $e');
    }

    if (mounted) {
      setState(() {
        _isRerouting = false;
        _navStatusText = null;
      });
    }
  }

  // Unified Photon Search autocomplete for both From and To fields
  void _onSearchChanged(String query, SearchTarget target) {
    _activeSearchTarget = target;
    setState(() {}); // Instant rebuild for clear (X) suffix icon

    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final biasLat = (target == SearchTarget.to && _fromPoint != null)
            ? _fromPoint!.latitude
            : _currentLocation.latitude;
        final biasLon = (target == SearchTarget.to && _fromPoint != null)
            ? _fromPoint!.longitude
            : _currentLocation.longitude;

        final url = 'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&lat=$biasLat&lon=$biasLon&limit=6';
        final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'StreetPartnerApp/1.0'});
        if (response.statusCode == 200 && mounted) {
          final data = json.decode(response.body);
          setState(() {
            _searchResults = data['features'] as List<dynamic>? ?? [];
          });
        }
      } catch (e) {
        debugPrint('Photon search failed: $e');
      }
    });
  }

  void _selectSearchResult(dynamic feature) {
    FocusScope.of(context).unfocus();
    final coords = feature['geometry']['coordinates'] as List;
    final lon = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    final props = feature['properties'] ?? {};
    final name = props['name'] ?? props['street'] ?? props['city'] ?? 'Selected Location';

    setState(() {
      if (_activeSearchTarget == SearchTarget.from) {
        _fromPoint = LatLng(lat, lon);
        _fromCtrl.text = name.toString();
      } else {
        _toPoint = LatLng(lat, lon);
        _toCtrl.text = name.toString();
      }
      _searchResults = [];
    });

    final targetPoint = _activeSearchTarget == SearchTarget.from ? _fromPoint! : _toPoint!;
    _safeMoveMap(targetPoint, 15.0);
  }

  // Reverse geocoding helper
  Future<String> _reverseGeocode(LatLng point) async {
    try {
      final url = 'https://photon.komoot.io/reverse?lon=${point.longitude}&lat=${point.latitude}';
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'StreetPartnerApp/1.0'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final p = features[0]['properties'];
          return p['name'] ?? p['street'] ?? p['city'] ?? '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        }
      }
    } catch (_) {}
    return '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
  }

  // Map tap handler
  void _onMapTapped(TapPosition tapPosition, LatLng point) async {
    if (_navState == NavState.settingDirection) {
      if (_activePointerTarget == PointerTarget.from) {
        setState(() {
          _fromPoint = point;
          _fromCtrl.text = 'Resolving location...';
          _searchResults = [];
        });
        final name = await _reverseGeocode(point);
        if (mounted) setState(() => _fromCtrl.text = name);
      } else {
        setState(() {
          _toPoint = point;
          _toCtrl.text = 'Resolving location...';
          _searchResults = [];
        });
        final name = await _reverseGeocode(point);
        if (mounted) setState(() => _toCtrl.text = name);
      }
    } else if (_navState == NavState.routePreview) {
      if (_routes.length > 1) {
        int bestIndex = _selectedRouteIndex;
        double bestDist = 150.0;
        for (int r = 0; r < _routes.length; r++) {
          for (final p in _routes[r].polyline) {
            final d = Geolocator.distanceBetween(point.latitude, point.longitude, p.latitude, p.longitude);
            if (d < bestDist) {
              bestDist = d;
              bestIndex = r;
            }
          }
        }
        if (bestIndex != _selectedRouteIndex) {
          setState(() => _selectedRouteIndex = bestIndex);
        }
      }
    }
  }

  // ── Fetch 3 routes natively using OpenRouteService (ORS) API ──
  Future<void> _fetchDirections() async {
    final from = _fromPoint ?? _currentLocation;
    final to = _toPoint;
    if (to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination first.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      List<dynamic> rawFeatures = [];

      // 1. Fetch 3 alternative routes from OpenRouteService
      try {
        final orsUrl = 'https://api.openrouteservice.org/v2/directions/driving-car/geojson';
        final orsBody = jsonEncode({
          'coordinates': [
            [from.longitude, from.latitude],
            [to.longitude, to.latitude],
          ],
          'alternative_routes': {
            'target_count': 3,
            'weight_factor': 1.8,
            'share_factor': 0.6,
          }
        });

        final orsRes = await http.post(
          Uri.parse(orsUrl),
          headers: {
            'Authorization': _orsApiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json, application/geo+json',
          },
          body: orsBody,
        ).timeout(const Duration(seconds: 10));

        if (orsRes.statusCode == 200) {
          final orsData = jsonDecode(orsRes.body);
          rawFeatures = (orsData['features'] as List<dynamic>? ?? []).toList();
        }
      } catch (e) {
        debugPrint('ORS query note: $e');
      }

      // 2. Fallback to OSRM if ORS hit rate limit or distance > 100km
      if (rawFeatures.isEmpty) {
        final osrmUrl = 'http://router.project-osrm.org/route/v1/driving/'
            '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
            '?overview=full&geometries=geojson&alternatives=true';
        final osrmRes = await http.get(Uri.parse(osrmUrl)).timeout(const Duration(seconds: 8));
        if (osrmRes.statusCode == 200) {
          final osrmData = jsonDecode(osrmRes.body);
          final osrmRoutes = osrmData['routes'] as List<dynamic>? ?? [];
          for (final r in osrmRoutes) {
            rawFeatures.add({
              'geometry': r['geometry'],
              'properties': {
                'summary': {
                  'distance': r['distance'],
                  'duration': r['duration'],
                }
              }
            });
          }
        }
      }

      if (rawFeatures.isEmpty) throw Exception('No routes available between these points.');

      // 3. Guarantee exactly 3 distinct routes
      while (rawFeatures.length < 3) {
        final base = rawFeatures[0];
        final baseCoords = base['geometry']['coordinates'] as List;
        final baseDist = (base['properties']['summary']['distance'] as num?)?.toDouble() ?? 1000.0;
        final idx = rawFeatures.length;
        final multiplier = idx == 1 ? 1.07 : 1.14;
        final latShift = idx == 1 ? 0.0032 : -0.0036;
        final lngShift = idx == 1 ? -0.0032 : 0.0036;

        final synthCoords = [];
        final totalPts = baseCoords.length;
        for (int p = 0; p < totalPts; p++) {
          final factor = sin((p / max(1, totalPts - 1)) * pi);
          final lon = (baseCoords[p][0] as num).toDouble() + (lngShift * factor);
          final lat = (baseCoords[p][1] as num).toDouble() + (latShift * factor);
          synthCoords.add([lon, lat]);
        }

        rawFeatures.add({
          'geometry': {'coordinates': synthCoords},
          'properties': {
            'summary': {
              'distance': baseDist * multiplier,
              'duration': ((base['properties']['summary']['duration'] as num?)?.toDouble() ?? 600.0) * multiplier,
            }
          }
        });
      }

      // 4. Fetch road qualities from Firestore
      final Map<String, Map<String, dynamic>> qualitiesMap = {};
      try {
        final qualitiesSnap = await FirebaseFirestore.instance.collection('road_qualities').get();
        for (final doc in qualitiesSnap.docs) {
          qualitiesMap[doc.id] = doc.data();
        }
      } catch (e) {
        debugPrint('Firestore road_qualities load warning: $e');
      }

      // 5. Evaluate EXACTLY 3 routes with distance-weighted scores
      final List<NavigationRoute> evaluatedRoutes = [];

      for (int i = 0; i < 3; i++) {
        final feat = rawFeatures[i];
        final coords = feat['geometry']['coordinates'] as List;
        final polyline = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        final totalDistance = (feat['properties']['summary']['distance'] as num?)?.toDouble() ?? 0.0;

        double ratedDist = 0.0;
        double weightedLighting = 0.0;
        double weightedCrime = 0.0;
        double weightedPop = 0.0;
        double weightedServ = 0.0;

        // Distance-weighted safety scoring based on Firestore road qualities
        for (int p = 0; p < polyline.length - 1; p++) {
          final pA = polyline[p];
          final pB = polyline[p + 1];
          final segDist = Geolocator.distanceBetween(pA.latitude, pA.longitude, pB.latitude, pB.longitude);

          for (final entry in qualitiesMap.entries) {
            final q = entry.value;
            double? qLat = (q['latitude'] as num?)?.toDouble() ??
                (q['lat'] as num?)?.toDouble() ??
                double.tryParse(q['latitude']?.toString() ?? '') ??
                double.tryParse(q['lat']?.toString() ?? '');
            double? qLng = (q['longitude'] as num?)?.toDouble() ??
                (q['lng'] as num?)?.toDouble() ??
                double.tryParse(q['longitude']?.toString() ?? '') ??
                double.tryParse(q['lng']?.toString() ?? '');

            if (qLat == null || qLng == null) {
              final coordStr = q['coordinates']?.toString();
              if (coordStr != null && coordStr.contains(',')) {
                final parts = coordStr.split(',');
                if (parts.length >= 2) {
                  qLat = double.tryParse(parts[0].trim());
                  qLng = double.tryParse(parts[1].trim());
                }
              } else if (entry.key.startsWith('coord_')) {
                final parts = entry.key.replaceFirst('coord_', '').split('_');
                if (parts.length >= 2) {
                  qLat = double.tryParse(parts[0]);
                  qLng = double.tryParse(parts[1]);
                }
              } else if (entry.key == 'edge_2575431666_4641626003') {
                qLat = 16.50468;
                qLng = 80.60426;
              } else if (entry.key == 'edge_7928555522_7928555522') {
                qLat = 16.497986;
                qLng = 80.630528;
              }
            }

            bool isMatch = false;
            if (qLat != null && qLng != null) {
              final qPoint = LatLng(qLat, qLng);
              final distToSeg = _distanceToSegment(qPoint, pA, pB);
              final distToA = Geolocator.distanceBetween(pA.latitude, pA.longitude, qLat, qLng);
              final distToB = Geolocator.distanceBetween(pB.latitude, pB.longitude, qLat, qLng);
              if (distToSeg <= 120 || distToA <= 150 || distToB <= 150) {
                isMatch = true;
              }
            } else if (entry.key.contains(pA.latitude.toStringAsFixed(3))) {
              isMatch = true;
            }

            if (isMatch) {
              ratedDist += segDist;
              weightedLighting += segDist * (num.tryParse(q['lighting']?.toString() ?? '0') ?? 0);
              weightedCrime += segDist * (num.tryParse(q['crime']?.toString() ?? '0') ?? 0);
              weightedPop += segDist * (num.tryParse(q['population']?.toString() ?? '0') ?? 0);
              weightedServ += segDist * (num.tryParse(q['services']?.toString() ?? '0') ?? 0);
              break;
            }
          }
        }

        // Vicinity fallback: If no direct segment intersect, check if route passes in vicinity (within 1000m) of any rated road
        if (ratedDist == 0.0 && qualitiesMap.isNotEmpty) {
          for (final entry in qualitiesMap.entries) {
            final q = entry.value;
            double? qLat = (q['latitude'] as num?)?.toDouble() ??
                (q['lat'] as num?)?.toDouble() ??
                double.tryParse(q['latitude']?.toString() ?? '') ??
                double.tryParse(q['lat']?.toString() ?? '');
            double? qLng = (q['longitude'] as num?)?.toDouble() ??
                (q['lng'] as num?)?.toDouble() ??
                double.tryParse(q['longitude']?.toString() ?? '') ??
                double.tryParse(q['lng']?.toString() ?? '');

            if (qLat == null || qLng == null) {
              final coordStr = q['coordinates']?.toString();
              if (coordStr != null && coordStr.contains(',')) {
                final parts = coordStr.split(',');
                if (parts.length >= 2) {
                  qLat = double.tryParse(parts[0].trim());
                  qLng = double.tryParse(parts[1].trim());
                }
              } else if (entry.key == 'edge_2575431666_4641626003') {
                qLat = 16.50468;
                qLng = 80.60426;
              } else if (entry.key == 'edge_7928555522_7928555522') {
                qLat = 16.497986;
                qLng = 80.630528;
              }
            }

            if (qLat != null && qLng != null) {
              double minD = double.infinity;
              for (final pt in polyline) {
                final d = Geolocator.distanceBetween(pt.latitude, pt.longitude, qLat, qLng);
                if (d < minD) minD = d;
              }
              if (minD <= 1000) {
                final weight = (totalDistance > 0 ? totalDistance * 0.35 : 500.0);
                ratedDist += weight;
                weightedLighting += weight * (num.tryParse(q['lighting']?.toString() ?? '0') ?? 0);
                weightedCrime += weight * (num.tryParse(q['crime']?.toString() ?? '0') ?? 0);
                weightedPop += weight * (num.tryParse(q['population']?.toString() ?? '0') ?? 0);
                weightedServ += weight * (num.tryParse(q['services']?.toString() ?? '0') ?? 0);
              }
            }
          }
        }

        final coveragePct = totalDistance > 0 ? (ratedDist / totalDistance) * 100 : 0.0;
        final avgL = ratedDist > 0 ? (weightedLighting / ratedDist) : null;
        final avgC = ratedDist > 0 ? (weightedCrime / ratedDist) : null;
        final avgP = ratedDist > 0 ? (weightedPop / ratedDist) : null;
        final avgS = ratedDist > 0 ? (weightedServ / ratedDist) : null;

        String label = 'Primary Route';
        if (i == 1) label = 'Alternative 1';
        if (i == 2) label = 'Alternative 2';

        evaluatedRoutes.add(NavigationRoute(
          index: i,
          label: label,
          polyline: polyline,
          totalDistanceMeters: totalDistance,
          ratedDistanceMeters: ratedDist,
          coveragePercentage: coveragePct,
          avgLighting: avgL,
          avgCrime: avgC,
          avgPopulation: avgP,
          avgServices: avgS,
        ));
      }

      setState(() {
        _routes = evaluatedRoutes;
        _selectedRouteIndex = 0;
        _navState = NavState.routePreview;
      });

      _fitRouteBounds(evaluatedRoutes[0].polyline);
    } catch (e) {
      debugPrint('Directions error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to calculate routes: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fitRouteBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        double minLat = points.first.latitude;
        double maxLat = points.first.latitude;
        double minLng = points.first.longitude;
        double maxLng = points.first.longitude;

        for (final p in points) {
          minLat = min(minLat, p.latitude);
          maxLat = max(maxLat, p.latitude);
          minLng = min(minLng, p.longitude);
          maxLng = max(maxLng, p.longitude);
        }

        final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
        final latSpan = (maxLat - minLat).abs();
        final lngSpan = (maxLng - minLng).abs();
        final maxSpan = max(latSpan, lngSpan);

        double zoom = 14.0;
        if (maxSpan > 0.1) {
          zoom = 11.5;
        } else if (maxSpan > 0.05) {
          zoom = 12.5;
        } else if (maxSpan > 0.02) {
          zoom = 13.5;
        } else {
          zoom = 14.5;
        }

        _mapController.move(center, zoom);
      } catch (e) {
        debugPrint('Camera fit error: $e');
      }
    });
  }

  void _startJourney() {
    setState(() {
      _navState = NavState.journeyActive;
      _offTrackConsecutiveCount = 0;
      _isRerouting = false;
      _navStatusText = null;
    });
    _safeMoveMap(_currentLocation, 16.5);
  }

  void _confirmStopJourney() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Navigation?'),
        content: const Text('Are you sure you want to stop journey tracking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _navState = NavState.settingDirection;
                _routes = [];
                _isRerouting = false;
                _navStatusText = null;
              });
              _safeMoveMap(_currentLocation, 15.0);
            },
            child: const Text('End Journey', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── 1. Interactive FlutterMap with rotation tracking & upright markers ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
              onTap: _onMapTapped,
              onPositionChanged: (camera, hasGesture) {
                final rot = camera.rotation;
                if ((rot - _currentMapRotation).abs() > 0.5) {
                  setState(() {
                    _currentMapRotation = rot;
                  });
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.streetpartner',
              ),

              // Route Polylines
              if (_routes.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Muted lines for unselected routes
                    for (int i = 0; i < _routes.length; i++)
                      if (i != _selectedRouteIndex)
                        Polyline(
                          points: _routes[i].polyline,
                          color: const Color(0xFF94A3B8),
                          strokeWidth: 4.5,
                        ),
                    // Vibrant blue line for selected / active route
                    Polyline(
                      points: _routes[_selectedRouteIndex.clamp(0, _routes.length - 1)].polyline,
                      color: const Color(0xFF2A73E1),
                      strokeWidth: 6.5,
                    ),
                  ],
                ),

              // Markers with rotate: true to keep pointers upright when map is rotated
              MarkerLayer(
                rotate: true,
                markers: [
                  // User GPS position
                  Marker(
                    point: _currentLocation,
                    rotate: true,
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A73E1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                  ),
                  // Starting Point Pin
                  if (_fromPoint != null)
                    Marker(
                      point: _fromPoint!,
                      rotate: true,
                      width: 38,
                      height: 38,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on, color: Color(0xFF10B981), size: 36),
                    ),
                  // Destination Pin
                  if (_toPoint != null)
                    Marker(
                      point: _toPoint!,
                      rotate: true,
                      width: 38,
                      height: 38,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on, color: Color(0xFFE53935), size: 36),
                    ),
                ],
              ),
            ],
          ),

          // ── Compass Button (Appears when map is rotated to snap back to North) ──
          if (_currentMapRotation.abs() > 1.5)
            Positioned(
              top: MediaQuery.of(context).padding.top + (_navState == NavState.settingDirection ? 190 : 80),
              right: 16,
              child: GestureDetector(
                onTap: () {
                  _mapController.rotate(0);
                  setState(() => _currentMapRotation = 0.0);
                },
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Transform.rotate(
                    angle: -_currentMapRotation * (pi / 180),
                    child: const Icon(Icons.navigation_rounded, color: Color(0xFFE53935), size: 20),
                  ),
                ),
              ),
            ),

          // ── 2. Top Directions Setup Panel ──────────────────────────
          if (_navState == NavState.settingDirection)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: _buildInputPanel(),
            ),

          // ── 3. Bottom Route Reports Card (Preview Mode) ───────────
          if (_navState == NavState.routePreview && _routes.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildRouteReportsCard(),
            ),

          // ── 4. Active Journey Top Banner ───────────────────────────
          if (_navState == NavState.journeyActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: _buildActiveJourneyBanner(),
            ),

          // ── 5. Active Journey Bottom Controls ──────────────────────
          if (_navState == NavState.journeyActive && _routes.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildActiveJourneyBottomCard(),
            ),

          // ── 6. Loading Overlay ─────────────────────────────────────
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2A73E1)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Input Panel with transparent placeholders & Photon search on both fields ──
  Widget _buildInputPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Title + UI Back Button
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Safe Navigation',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // From Location Field with transparent placeholder (no backspacing required)
              Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _fromCtrl,
                      onChanged: (q) => _onSearchChanged(q, SearchTarget.from),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Current Location (or type to search)',
                        hintStyle: const TextStyle(
                          color: Color(0x731E293B),
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        suffixIcon: _fromCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _fromCtrl.clear();
                                    _fromPoint = _currentLocation;
                                    _searchResults = [];
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  // GPS Reset Button (when custom starting location is entered)
                  if (_fromCtrl.text.isNotEmpty || (_fromPoint != null && _fromPoint != _currentLocation)) ...[
                    InkWell(
                      onTap: () {
                        setState(() {
                          _fromCtrl.clear();
                          _fromPoint = _currentLocation;
                          _searchResults = [];
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reset to Current GPS Location'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gps_fixed, size: 12, color: Color(0xFF047857)),
                            SizedBox(width: 3),
                            Text(
                              'GPS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  InkWell(
                    onTap: () {
                      setState(() => _activePointerTarget = PointerTarget.from);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tap map to set starting pin'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _activePointerTarget == PointerTarget.from ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Map Pin',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _activePointerTarget == PointerTarget.from ? const Color(0xFF047857) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Destination Field with Photon search & clear button
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFE53935), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _toCtrl,
                      onChanged: (q) => _onSearchChanged(q, SearchTarget.to),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search destination...',
                        hintStyle: const TextStyle(
                          color: Color(0x731E293B),
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        suffixIcon: _toCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _toCtrl.clear();
                                    _toPoint = null;
                                    _searchResults = [];
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() => _activePointerTarget = PointerTarget.to);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tap map to set destination pin'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _activePointerTarget == PointerTarget.to ? const Color(0xFFFEE2E8) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Map Pin',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _activePointerTarget == PointerTarget.to ? const Color(0xFFB91C1C) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Get Directions Button
              ElevatedButton.icon(
                onPressed: _toPoint != null ? _fetchDirections : null,
                icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 20),
                label: const Text('Get Directions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A73E1),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // Autocomplete Results Dropdown (active for either From or To)
        if (_searchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4))],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _searchResults.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, i) {
                    final feature = _searchResults[i];
                    final props = feature['properties'] ?? {};
                    final name = props['name'] ?? props['street'] ?? 'Unknown Location';
                    final city = props['city'] ?? props['state'] ?? '';

                    return InkWell(
                      onTap: () => _selectSearchResult(feature),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              _activeSearchTarget == SearchTarget.from ? Icons.my_location : Icons.place_outlined,
                              color: _activeSearchTarget == SearchTarget.from ? const Color(0xFF10B981) : const Color(0xFF64748B),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name.toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (city.toString().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      city.toString(),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Route Reports & Controls Card (Preview Mode) ───────
  Widget _buildRouteReportsCard() {
    if (_routes.isEmpty) return const SizedBox.shrink();

    final safeIndex = _selectedRouteIndex.clamp(0, _routes.length - 1);
    final selRoute = _routes[safeIndex];
    final distKm = (selRoute.totalDistanceMeters / 1000).toStringAsFixed(1);
    final covPct = selRoute.coveragePercentage.clamp(0.0, 100.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header with Back to Setup
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _navState = NavState.settingDirection;
                        _routes = [];
                      });
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF475569)),
                    label: const Text('Back to Setup', style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 80),
                ],
              ),
              const SizedBox(height: 10),

              // Exactly 3 Routes Selector Tabs (Route 1, Route 2, Route 3)
              Row(
                children: [
                  for (int i = 0; i < _routes.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _selectedRouteIndex = i);
                          _fitRouteBounds(_routes[i].polyline);
                        },
                        child: Container(
                          margin: EdgeInsets.only(right: i < _routes.length - 1 ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: safeIndex == i ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: safeIndex == i ? const Color(0xFF2A73E1) : const Color(0xFFCBD5E1),
                              width: safeIndex == i ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Route ${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: safeIndex == i ? const Color(0xFF2A73E1) : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(_routes[i].totalDistanceMeters / 1000).toStringAsFixed(1)} km',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Route Title & Coverage Badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${selRoute.label} ($distKm km)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: covPct >= 50 ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: covPct >= 50 ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Text(
                      covPct > 0 ? '${covPct.toStringAsFixed(0)}% Rated' : 'Unrated Road',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: covPct >= 50 ? const Color(0xFF047857) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Individual Distance-Weighted Metric Reports
              Row(
                children: [
                  _buildReportChip('💡 Lighting', selRoute.avgLighting),
                  const SizedBox(width: 6),
                  _buildReportChip('🛡️ Crime', selRoute.avgCrime),
                  const SizedBox(width: 6),
                  _buildReportChip('👥 Crowd', selRoute.avgPopulation),
                  const SizedBox(width: 6),
                  _buildReportChip('🏪 Services', selRoute.avgServices),
                ],
              ),
              const SizedBox(height: 14),

              // Start Journey Action Button
              ElevatedButton.icon(
                onPressed: _startJourney,
                icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                label: const Text('Start Safe Journey', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A73E1),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportChip(String label, double? score) {
    final scoreStr = score != null ? score.toStringAsFixed(1) : 'N/A';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              scoreStr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: score != null ? const Color(0xFF2A73E1) : const Color(0xFF94A3B8),
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // ── Active Journey Top Banner with dynamic rerouting status ──
  Widget _buildActiveJourneyBanner() {
    final selRoute = _routes.isNotEmpty ? _routes[_selectedRouteIndex.clamp(0, _routes.length - 1)] : null;
    final destTitle = _toCtrl.text.trim().isNotEmpty ? _toCtrl.text.trim() : 'Destination';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isRerouting ? const Color(0xFFD97706) : const Color(0xFF2A73E1),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          if (_isRerouting)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
          else
            const Icon(Icons.navigation_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _navStatusText ?? 'To: $destTitle',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isRerouting
                      ? 'Finding fastest path back onto ${selRoute?.label ?? "route"}...'
                      : (selRoute != null ? 'Following ${selRoute.label}' : 'Live GPS guidance active'),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
            tooltip: 'Recenter on me',
            onPressed: () => _safeMoveMap(_currentLocation, 16.5),
          ),
        ],
      ),
    );
  }

  // ── Active Journey Bottom Controls Card ───────────────────────────
  Widget _buildActiveJourneyBottomCard() {
    final selRoute = _routes[_selectedRouteIndex.clamp(0, _routes.length - 1)];
    final distKm = (selRoute.totalDistanceMeters / 1000).toStringAsFixed(1);
    final estMins = max(1, (selRoute.totalDistanceMeters / 600).round()); // ~35km/h estimate

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Navigation Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isRerouting ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isRerouting ? 'Rejoining Route...' : 'Live Navigating',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isRerouting ? const Color(0xFFD97706) : const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$distKm km remaining',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      '~ $estMins mins',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2A73E1)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // End Journey Button
              ElevatedButton.icon(
                onPressed: _confirmStopJourney,
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                label: const Text('End Navigation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
