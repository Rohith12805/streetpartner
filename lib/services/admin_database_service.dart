import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AdminDatabaseService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static Future<String?> reportEmergencyToAdmin({
    required String userId,
    required String userName,
    required String bloodGroup,
    required String mobileNumber,
    required String liveLocationLink,
    double? lat,
    double? lng,
    String triggerSource = 'SOS Button',
  }) async {
    try {
      final firestore = _firestore;

      final existing = await firestore.collection('emergencies')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      
      String emergencyId;
      if (existing.docs.isNotEmpty) {
        emergencyId = existing.docs.first.id;
        final link = 'https://streetpartner.web.app/?session=$emergencyId';
        final Map<String, dynamic> updates = {
          'userName': userName,
          'bloodGroup': bloodGroup,
          'mobileNumber': mobileNumber,
          'liveLocationLink': link,
          'triggerSource': triggerSource,
          'isActive': true,
          'active': true,
        };
        if (lat != null) {
          updates['lat'] = lat;
          updates['latitude'] = lat;
        }
        if (lng != null) {
          updates['lng'] = lng;
          updates['longitude'] = lng;
        }
        await existing.docs.first.reference.update(updates);
      } else {
        final docRef = firestore.collection('emergencies').doc();
        emergencyId = docRef.id;
        final link = 'https://streetpartner.web.app/?session=$emergencyId';
        final Map<String, dynamic> data = {
          'userId': userId,
          'userName': userName,
          'bloodGroup': bloodGroup,
          'mobileNumber': mobileNumber,
          'liveLocationLink': link,
          'triggerSource': triggerSource,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'triggeredAt': Timestamp.now(),
          'isActive': true,
          'active': true,
        };
        if (lat != null) {
          data['lat'] = lat;
          data['latitude'] = lat;
        }
        if (lng != null) {
          data['lng'] = lng;
          data['longitude'] = lng;
        }
        await docRef.set(data);
      }

      if (lat != null && lng != null) {
        final formattedLat = (lat + 0.0).toStringAsFixed(2);
        final formattedLng = (lng + 0.0).toStringAsFixed(2);
        final cellId = 'cell_${formattedLat}_$formattedLng';

        // Update merged area_safety_cells in streetpartner
        try {
          await firestore.collection('area_safety_cells').doc(cellId).set({
            'sosCount': FieldValue.increment(1),
            'centerLat': double.parse(formattedLat),
            'centerLng': double.parse(formattedLng),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error updating area_safety_cells: $e');
        }
      }

      debugPrint('Successfully reported emergency: $emergencyId');
      return emergencyId;
    } catch (e) {
      debugPrint('Error reporting emergency: $e');
      return null;
    }
  }

  static Future<void> updateEmergencyLocation(String userId, double lat, double lng) async {
    try {
      final firestore = _firestore;
      final query = await firestore.collection('emergencies')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
          
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'lat': lat,
          'lng': lng,
          'latitude': lat,
          'longitude': lng,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });
      }
      debugPrint('Successfully updated emergency location');
    } catch (e) {
      debugPrint('Error updating emergency location: $e');
    }
  }

  static Future<void> clearEmergencyFromAdmin(String userId) async {
    try {
      final firestore = _firestore;
      final query = await firestore.collection('emergencies')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();
          
      for (final doc in query.docs) {
        await doc.reference.update({
          'isActive': false,
          'active': false,
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      }
      debugPrint('Successfully marked emergency as inactive (history)');
    } catch (e) {
      debugPrint('Error marking emergency as inactive: $e');
    }
  }
}
