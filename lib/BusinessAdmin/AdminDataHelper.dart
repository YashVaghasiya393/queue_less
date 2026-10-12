import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseIntegrityReport {
  final bool isAuthConnected;
  final String? authEmail;
  final String? authUid;
  final bool isFirestoreConnected;
  final int firestoreLatencyMs;
  final bool isHospitalDataFound;
  final String hospitalName;
  final String businessId;
  final int servicesCount;
  final String? errorMessage;

  const FirebaseIntegrityReport({
    required this.isAuthConnected,
    this.authEmail,
    this.authUid,
    required this.isFirestoreConnected,
    required this.firestoreLatencyMs,
    required this.isHospitalDataFound,
    required this.hospitalName,
    required this.businessId,
    required this.servicesCount,
    this.errorMessage,
  });
}

class AdminDataHelper {
  // Default Hospital ID established in the project (from CustomerHomeScreen and QRScannerScreen)
  static const String defaultBusinessId = 'b6t7TBNRSAjhpBXSNJHA';
  static const String adminEmail = 'admin@queueless.com';
  static const String adminPassword = 'adminPassword123';

  /// Ensures a valid authenticated session for static admin without prompting the user.
  static Future<void> ensureAdminAuth() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
      }
    } catch (e) {
      debugPrint('AdminDataHelper: Silent admin auth failed: $e');
    }
  }

  /// Resolves the current hospital business ID.
  static Future<String> getBusinessId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final id = doc.data()?['businessId']?.toString();
        if (id != null && id.isNotEmpty) {
          return id;
        }
      } catch (e) {
        debugPrint('AdminDataHelper: Error getting user businessId: $e');
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(defaultBusinessId)
          .get();
      if (doc.exists) {
        return defaultBusinessId;
      }

      final query = await FirebaseFirestore.instance
          .collection('businesses')
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
    } catch (e) {
      debugPrint('AdminDataHelper: Error resolving business in Firestore: $e');
    }

    return defaultBusinessId;
  }

  /// Measures Firebase connection integrity and fetches diagnostic health data.
  static Future<FirebaseIntegrityReport> measureFirebaseIntegrity() async {
    await ensureAdminAuth();

    final user = FirebaseAuth.instance.currentUser;
    final isAuth = user != null;
    final authEmail = user?.email;
    final authUid = user?.uid;

    final stopwatch = Stopwatch()..start();
    bool firestoreOk = false;
    bool hospitalFound = false;
    String hospitalName = 'Not Loaded';
    String businessId = defaultBusinessId;
    int servicesCount = 0;
    String? errorMsg;

    try {
      businessId = await getBusinessId();
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get();
      stopwatch.stop();

      firestoreOk = true;
      if (doc.exists) {
        hospitalFound = true;
        hospitalName = doc.data()?['name']?.toString() ?? 'Sunrise Care Hospital';
      }

      // Check services count
      final servicesSnap = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('services')
          .get();
      servicesCount = servicesSnap.docs.length;
    } catch (e) {
      stopwatch.stop();
      errorMsg = e.toString();
      debugPrint('AdminDataHelper: Integrity check error: $e');
    }

    return FirebaseIntegrityReport(
      isAuthConnected: isAuth,
      authEmail: authEmail,
      authUid: authUid,
      isFirestoreConnected: firestoreOk,
      firestoreLatencyMs: stopwatch.elapsedMilliseconds,
      isHospitalDataFound: hospitalFound,
      hospitalName: hospitalName,
      businessId: businessId,
      servicesCount: servicesCount,
      errorMessage: errorMsg,
    );
  }
}
