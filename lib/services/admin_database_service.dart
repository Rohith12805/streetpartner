import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AdminDatabaseService {
  static FirebaseApp? get _adminApp {
    try {
      return Firebase.app('adminDb');
    } catch (e) {
      debugPrint('AdminDb Firebase app not initialized. Did you replace the placeholders in main.dart?');
      return null;
    }
  }

  static Future<void> reportEmergencyToAdmin({
    required String userId,
    required String userName,
    required String bloodGroup,
    required String mobileNumber,
    required String liveLocationLink,
    double? lat,
    double? lng,
  }) async {
    final app = _adminApp;
    if (app == null) return;
    
    try {
      final firestore = FirebaseFirestore.instanceFor(app: app);
      final Map<String, dynamic> data = {
        'userId': userId,
        'userName': userName,
        'bloodGroup': bloodGroup,
        'mobileNumber': mobileNumber,
        'liveLocationLink': liveLocationLink,
        'timestamp': FieldValue.serverTimestamp(),
        'isActive': true,
      };
      
      if (lat != null) data['lat'] = lat;
      if (lng != null) data['lng'] = lng;

      await firestore.collection('emergencies').doc(userId).set(data);
      debugPrint('Successfully reported emergency to admin database');
    } catch (e) {
      debugPrint('Error reporting emergency to admin database: ');
    }
  }

  static Future<void> updateEmergencyLocation(String userId, double lat, double lng) async {
    final app = _adminApp;
    if (app == null) return;
    
    try {
      final firestore = FirebaseFirestore.instanceFor(app: app);
      await firestore.collection('emergencies').doc(userId).update({
        'lat': lat,
        'lng': lng,
        'liveLocationLink': 'https://streetpartner.web.app/?session=$userId',
      });
      debugPrint('Successfully updated emergency location in admin db');
    } catch (e) {
      debugPrint('Error updating emergency location in admin db: ');
    }
  }

  static Future<void> clearEmergencyFromAdmin(String userId) async {
    final app = _adminApp;
    if (app == null) return;
    
    try {
      final firestore = FirebaseFirestore.instanceFor(app: app);
      await firestore.collection('emergencies').doc(userId).delete();
      debugPrint('Successfully cleared emergency from admin database');
    } catch (e) {
      debugPrint('Error clearing emergency from admin database: ');
    }
  }
}
