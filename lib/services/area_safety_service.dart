import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../models/area_safety_model.dart';

class AreaSafetyService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _cellsRef => _firestore.collection('area_safety_cells');

  /// Calculate Cell ID by rounding coordinates to 2 decimal places.
  /// This creates a grid where each cell is roughly 1.1km x 1.1km.
  static String getCellId(double lat, double lng) {
    // We add 0.0 to prevent negative zero string representation like "-0.00"
    final formattedLat = (lat + 0.0).toStringAsFixed(2);
    final formattedLng = (lng + 0.0).toStringAsFixed(2);
    return 'cell_${formattedLat}_$formattedLng';
  }

  /// Calculates the exact center of a cell given its string ID
  static LatLng getCellCenter(String cellId) {
    try {
      final parts = cellId.replaceFirst('cell_', '').split('_');
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (e) {
      return const LatLng(0, 0);
    }
  }

  /// Search location using OpenStreetMap Nominatim API
  Future<LatLng?> searchLocation(String query) async {
    if (query.trim().isEmpty) return null;

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'com.example.streetpartner/1.0', // Important for OSM
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      // Ignore network errors or parsing errors
    }
    return null;
  }

  /// Stream a single area safety cell
  Stream<AreaSafetyCell?> streamCell(String cellId) {
    return _cellsRef.doc(cellId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return AreaSafetyCell.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  /// Stream all area safety cells for grid rendering
  Stream<Map<String, AreaSafetyCell>> streamAllCells() {
    return _cellsRef.snapshots().map((snapshot) {
      final map = <String, AreaSafetyCell>{};
      for (var doc in snapshot.docs) {
        if (doc.data() != null) {
          map[doc.id] = AreaSafetyCell.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }
      }
      return map;
    });
  }

  /// Stream reviews for a specific cell
  Stream<List<AreaSafetyReview>> streamReviews(String cellId) {
    return _cellsRef
        .doc(cellId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AreaSafetyReview.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Submit a safety review
  /// Uses a Firestore transaction to update the aggregate counts safely.
  Future<void> submitReview({
    required LatLng location,
    required double rating,
    required List<String> issues,
    required String experienceText,
  }) async {
    final cellId = getCellId(location.latitude, location.longitude);
    final cellCenter = getCellCenter(cellId);
    final cellDocRef = _cellsRef.doc(cellId);

    final userId = _auth.currentUser?.uid ?? 'anonymous';
    final isAnonymous = userId == 'anonymous';
    
    // Get existing reviews by this user to remove them (if any)
    final existingReviewsSnapshot = await cellDocRef.collection('reviews')
        .where('userId', isEqualTo: userId)
        .get();

    // Use a specific doc ID for logged-in users so they only have one review per cell.
    final newReviewRef = isAnonymous 
        ? cellDocRef.collection('reviews').doc() 
        : cellDocRef.collection('reviews').doc(userId);

    final review = AreaSafetyReview(
      id: newReviewRef.id,
      rating: rating,
      issues: issues,
      experienceText: experienceText,
      userId: userId,
    );

    await _firestore.runTransaction((transaction) async {
      final cellSnapshot = await transaction.get(cellDocRef);

      int totalRatings = 0;
      double ratingSum = 0.0;
      Map<String, int> issueCounts = {};

      if (cellSnapshot.exists && cellSnapshot.data() != null) {
        final existingCell =
            AreaSafetyCell.fromMap(cellSnapshot.data() as Map<String, dynamic>, cellId);
        totalRatings = existingCell.totalRatings;
        ratingSum = existingCell.ratingSum;
        issueCounts = Map<String, int>.from(existingCell.issueCounts);
      }

      // If not anonymous, remove all existing reviews by this user to avoid duplicates
      if (!isAnonymous) {
        for (var doc in existingReviewsSnapshot.docs) {
          final oldReview = AreaSafetyReview.fromMap(doc.data(), doc.id);
          
          totalRatings = (totalRatings - 1).clamp(0, 999999999);
          ratingSum = (ratingSum - oldReview.rating).clamp(0.0, 999999999.0);
          
          for (var issue in oldReview.issues) {
            if (issueCounts.containsKey(issue)) {
              issueCounts[issue] = (issueCounts[issue]! - 1).clamp(0, 999999999);
              if (issueCounts[issue] == 0) {
                issueCounts.remove(issue);
              }
            }
          }
          
          transaction.delete(doc.reference);
        }
      }

      // Add the new review data to aggregates
      totalRatings += 1;
      ratingSum += rating;
      
      for (var issue in issues) {
        issueCounts[issue] = (issueCounts[issue] ?? 0) + 1;
      }

      final averageRating = totalRatings > 0 ? ratingSum / totalRatings : 0.0;

      final updatedCell = AreaSafetyCell(
        cellId: cellId,
        centerLat: cellCenter.latitude,
        centerLng: cellCenter.longitude,
        totalRatings: totalRatings,
        ratingSum: ratingSum,
        averageRating: averageRating,
        issueCounts: issueCounts,
      );

      // Write changes
      transaction.set(cellDocRef, updatedCell.toMap(), SetOptions(merge: true));
      transaction.set(newReviewRef, review.toMap());
    });
  }

  /// Delete a safety review and decrement aggregate counts
  Future<void> deleteReview(String cellId, String reviewId) async {
    final cellDocRef = _cellsRef.doc(cellId);
    final reviewDocRef = cellDocRef.collection('reviews').doc(reviewId);

    await _firestore.runTransaction((transaction) async {
      final reviewSnapshot = await transaction.get(reviewDocRef);
      if (!reviewSnapshot.exists) return;

      final reviewToDelete = AreaSafetyReview.fromMap(reviewSnapshot.data()!, reviewSnapshot.id);

      final cellSnapshot = await transaction.get(cellDocRef);
      if (cellSnapshot.exists && cellSnapshot.data() != null) {
        final existingCell = AreaSafetyCell.fromMap(
            cellSnapshot.data() as Map<String, dynamic>, cellId);
        
        int totalRatings = (existingCell.totalRatings - 1).clamp(0, 999999999);
        double ratingSum = (existingCell.ratingSum - reviewToDelete.rating).clamp(0.0, 999999999.0);
        Map<String, int> issueCounts = Map<String, int>.from(existingCell.issueCounts);

        for (var issue in reviewToDelete.issues) {
          if (issueCounts.containsKey(issue)) {
            issueCounts[issue] = (issueCounts[issue]! - 1).clamp(0, 999999999);
            if (issueCounts[issue] == 0) {
              issueCounts.remove(issue);
            }
          }
        }

        final averageRating = totalRatings > 0 ? ratingSum / totalRatings : 0.0;

        final updatedCell = AreaSafetyCell(
          cellId: cellId,
          centerLat: existingCell.centerLat,
          centerLng: existingCell.centerLng,
          totalRatings: totalRatings,
          ratingSum: ratingSum,
          averageRating: averageRating,
          issueCounts: issueCounts,
        );

        transaction.set(cellDocRef, updatedCell.toMap(), SetOptions(merge: true));
      }

      transaction.delete(reviewDocRef);
    });
  }
}
