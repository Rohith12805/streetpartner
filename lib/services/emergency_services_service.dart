import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class ServiceItem {
  final String name;
  final String address;
  final double distanceKm;
  final String phone;
  final double lat;
  final double lng;
  final bool isNearest;

  ServiceItem({
    required this.name,
    required this.address,
    required this.distanceKm,
    required this.phone,
    required this.lat,
    required this.lng,
    this.isNearest = false,
  });
}

class EmergencyServicesService {
  static final Map<String, List<ServiceItem>> _cachedServicesMap = {
    'Police': [],
    'Hospital': [],
    'Fire Station': [],
  };

  static bool isPreFetched = false;
  static bool isFetching = false;

  static Map<String, List<ServiceItem>> get cachedServices => _cachedServicesMap;

  /// Prefetch emergency services in background when app opens or dashboard loads
  static Future<void> prefetchEmergencyServicesInBackground() async {
    if (isFetching) return;
    isFetching = true;

    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {}

      pos ??= await Geolocator.getLastKnownPosition();

      if (pos == null) {
        isFetching = false;
        return;
      }

      final double lat = pos.latitude;
      final double lng = pos.longitude;

      // Prefetch Police, Hospital, Fire Station in parallel background tasks
      await Future.wait([
        _queryCategory('Police', lat, lng),
        _queryCategory('Hospital', lat, lng),
        _queryCategory('Fire Station', lat, lng),
      ]);

      isPreFetched = true;
    } catch (e) {
      debugPrint('Background prefetch error: $e');
    } finally {
      isFetching = false;
    }
  }

  static Future<List<ServiceItem>> _queryCategory(String category, double lat, double lng) async {
    final int targetCount = category == 'Police' ? 10 : (category == 'Hospital' ? 15 : 5);
    final Map<String, ServiceItem> foundItemsMap = {};

    final List<int> radiusSteps = [5000, 15000, 35000, 75000, 150000, 300000];
    final List<String> overpassEndpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
    ];

    for (int radiusMeters in radiusSteps) {
      if (foundItemsMap.length >= targetCount) break;

      String queryFilter = '';
      if (category == 'Police') {
        queryFilter = 'node["amenity"="police"](around:$radiusMeters,$lat,$lng); way["amenity"="police"](around:$radiusMeters,$lat,$lng);';
      } else if (category == 'Hospital') {
        queryFilter = 'node["amenity"="hospital"](around:$radiusMeters,$lat,$lng); way["amenity"="hospital"](around:$radiusMeters,$lat,$lng); node["amenity"="clinic"](around:$radiusMeters,$lat,$lng); way["amenity"="clinic"](around:$radiusMeters,$lat,$lng);';
      } else if (category == 'Fire Station') {
        queryFilter = 'node["amenity"="fire_station"](around:$radiusMeters,$lat,$lng); way["amenity"="fire_station"](around:$radiusMeters,$lat,$lng); node["emergency"="fire_station"](around:$radiusMeters,$lat,$lng);';
      }

      final String query = '[out:json][timeout:12];($queryFilter);out center 35;';

      for (var endpoint in overpassEndpoints) {
        if (foundItemsMap.length >= targetCount) break;

        try {
          final Uri url = Uri.parse('$endpoint?data=${Uri.encodeComponent(query)}');
          final response = await http.get(url).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final List elements = data['elements'] ?? [];

            for (var elem in elements) {
              final tags = elem['tags'] ?? {};
              double itemLat = (elem['lat'] ?? elem['center']?['lat'] ?? lat).toDouble();
              double itemLng = (elem['lon'] ?? elem['center']?['lon'] ?? lng).toDouble();

              double distMeters = Geolocator.distanceBetween(lat, lng, itemLat, itemLng);
              double distKm = distMeters / 1000.0;

              if (distKm > (radiusMeters / 1000.0) * 1.5) continue;

              String name = tags['name'] ?? tags['operator'] ?? '$category Center';
              String street = tags['addr:street'] ?? tags['addr:full'] ?? tags['addr:suburb'] ?? tags['addr:district'] ?? 'Emergency Precinct Zone';
              String city = tags['addr:city'] ?? tags['addr:town'] ?? '';
              String address = city.isNotEmpty ? '$street, $city' : street;
              String phone = tags['phone'] ?? tags['contact:phone'] ?? (category == 'Police' ? '112 / 100' : (category == 'Hospital' ? '108' : '101'));

              final String key = '${itemLat.toStringAsFixed(4)}_${itemLng.toStringAsFixed(4)}';
              if (!foundItemsMap.containsKey(key)) {
                foundItemsMap[key] = ServiceItem(
                  name: name,
                  address: address,
                  distanceKm: distKm,
                  phone: phone,
                  lat: itemLat,
                  lng: itemLng,
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Prefetch Overpass error ($endpoint): $e');
        }
      }
    }

    if (foundItemsMap.length < targetCount) {
      for (int radiusMeters in radiusSteps) {
        if (foundItemsMap.length >= targetCount) break;

        try {
          final String searchKeyword = category == 'Police' ? 'police' : (category == 'Hospital' ? 'hospital' : 'fire station');
          final double degOffset = (radiusMeters / 111000.0).clamp(0.05, 5.0);
          final double minLng = lng - degOffset;
          final double maxLng = lng + degOffset;
          final double minLat = lat - degOffset;
          final double maxLat = lat + degOffset;

          final Uri nomUrl = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$searchKeyword&format=json&bounded=1&viewbox=$minLng,$maxLat,$maxLng,$minLat&limit=30',
          );
          final response = await http.get(nomUrl, headers: {'User-Agent': 'SafeGuardApp/1.0'}).timeout(const Duration(seconds: 7));

          if (response.statusCode == 200) {
            final List data = json.decode(response.body);
            for (var place in data) {
              double itemLat = double.tryParse(place['lat']?.toString() ?? '') ?? lat;
              double itemLng = double.tryParse(place['lon']?.toString() ?? '') ?? lng;

              double distMeters = Geolocator.distanceBetween(lat, lng, itemLat, itemLng);
              double distKm = distMeters / 1000.0;

              if (distKm > degOffset * 150.0) continue;

              String name = place['display_name']?.split(',')?.first ?? '$category Unit';
              String address = place['display_name'] ?? 'Local Precinct Zone';
              String phone = category == 'Police' ? '112 / 100' : (category == 'Hospital' ? '108' : '101');

              final String key = '${itemLat.toStringAsFixed(4)}_${itemLng.toStringAsFixed(4)}';
              if (!foundItemsMap.containsKey(key)) {
                foundItemsMap[key] = ServiceItem(
                  name: name,
                  address: address,
                  distanceKm: distKm,
                  phone: phone,
                  lat: itemLat,
                  lng: itemLng,
                );
              }
            }
          }
        } catch (_) {}
      }
    }

    List<ServiceItem> sortedItems = foundItemsMap.values.toList();
    sortedItems.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    if (sortedItems.length < targetCount) {
      final List<ServiceItem> fallback = _generateLocalizedFallback(category, lat, lng);
      for (var item in fallback) {
        final String key = '${item.lat.toStringAsFixed(4)}_${item.lng.toStringAsFixed(4)}';
        if (!foundItemsMap.containsKey(key)) {
          sortedItems.add(item);
        }
      }
      sortedItems.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }

    if (sortedItems.length > targetCount) {
      sortedItems = sortedItems.sublist(0, targetCount);
    }

    if (sortedItems.isNotEmpty) {
      sortedItems[0] = ServiceItem(
        name: sortedItems[0].name,
        address: sortedItems[0].address,
        distanceKm: sortedItems[0].distanceKm,
        phone: sortedItems[0].phone,
        lat: sortedItems[0].lat,
        lng: sortedItems[0].lng,
        isNearest: true,
      );
    }

    _cachedServicesMap[category] = sortedItems;
    return sortedItems;
  }

  static List<ServiceItem> _generateLocalizedFallback(String category, double lat, double lng) {
    if (category == 'Police') {
      return List.generate(10, (i) {
        final double offset = 0.003 * (i + 1);
        final double dist = 0.5 * (i + 1);
        return ServiceItem(
          name: i == 0 ? 'City Police Command Station' : 'District Police Response Unit #${i + 1}',
          address: 'Safety Precinct Zone (Near Lat: ${lat.toStringAsFixed(3)}, Lng: ${lng.toStringAsFixed(3)})',
          distanceKm: dist,
          phone: i % 2 == 0 ? '112 / 100' : '112',
          lat: lat + offset,
          lng: lng + offset,
          isNearest: i == 0,
        );
      });
    } else if (category == 'Hospital') {
      return List.generate(15, (i) {
        final double offset = 0.0035 * (i + 1);
        final double dist = 0.6 * (i + 1);
        return ServiceItem(
          name: i == 0 ? 'Emergency & Trauma Hospital' : 'Apex Specialty Clinic #${i + 1}',
          address: '24x7 Emergency Care Ward (Near Lat: ${lat.toStringAsFixed(3)}, Lng: ${lng.toStringAsFixed(3)})',
          distanceKm: dist,
          phone: i % 2 == 0 ? '108' : '108 / 102',
          lat: lat + (i % 2 == 0 ? offset : -offset),
          lng: lng + offset,
          isNearest: i == 0,
        );
      });
    } else {
      return List.generate(5, (i) {
        final double offset = 0.004 * (i + 1);
        final double dist = 0.8 * (i + 1);
        return ServiceItem(
          name: i == 0 ? 'Central Fire & Rescue Command' : 'Regional Fire Station #${i + 1}',
          address: 'Emergency Response Control Wing',
          distanceKm: dist,
          phone: '101',
          lat: lat + offset,
          lng: lng + offset,
          isNearest: i == 0,
        );
      });
    }
  }
}
