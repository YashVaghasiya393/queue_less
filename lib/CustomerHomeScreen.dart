import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:queue_less/Staff/Services_screen.dart';
import 'package:queue_less/QRScannerScreen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;
  const HomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  static const String businessId = 'b6t7TBNRSAjhpBXSNJHA';

  int _selectedTabIndex = 0;
  int _tokensFilterIndex = 0;
  bool _isUploadingProfilePic = false;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
  }

  // ============================================================
  // FIREBASE REFERENCES
  // ============================================================

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  // ============================================================
  // USER STREAM
  // ============================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  // ============================================================
  // HOSPITAL STREAM
  // ============================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> _hospitalStream() {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .snapshots()
        .handleError((error) {
      debugPrint('FIRESTORE ERROR: $error');
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _hospitalStream(),
      builder: (context, hospitalSnapshot) {
        if (hospitalSnapshot.connectionState == ConnectionState.waiting) {
          return _loadingScreen();
        }

        if (hospitalSnapshot.hasError) {
          return _errorScreen(
            context,
            'Unable to load hospital information.',
          );
        }

        if (!hospitalSnapshot.hasData || !hospitalSnapshot.data!.exists) {
          return _errorScreen(
            context,
            'Hospital information not found.',
          );
        }

        final hospitalData = hospitalSnapshot.data!.data() ?? {};

        final Hospital hospital = Hospital.fromMap(hospitalData);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userStream(),
          builder: (context, userSnapshot) {
            String userName = 'User';
            String? profileImage;
            Map<String, dynamic> userData = {};

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data();

              if (data != null) {
                userData = data;
                userName = data['name'] ??
                    data['fullName'] ??
                    data['username'] ??
                    'User';
                profileImage = data['profileImage']?.toString() ??
                    data['photoUrl']?.toString();
              }
            }

            return _buildHome(
              context,
              hospital,
              userName,
              profileImage: profileImage,
              userData: userData,
            );
          },
        );
      },
    );
  }

  // ============================================================
  // HOME SCREEN
  // ============================================================

  Widget _buildHome(
    BuildContext context,
    Hospital hospital,
    String userName, {
    String? profileImage,
    Map<String, dynamic> userData = const {},
  }) {
    final currentUser = _auth.currentUser;
    final currentUid = currentUser?.uid ?? '';
    final userEmail = currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF060810),
      bottomNavigationBar: _bottomNavigation(uid: currentUid),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1B2540),
              Color(0xFF0A0F1E),
              Color(0xFF060810),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              _topBar(profileImage: profileImage),

              // Active Tab Content
              Expanded(
                child: _selectedTabIndex == 0
                    ? _homeDashboardTab(context, hospital, userName, currentUid)
                    : _selectedTabIndex == 1
                        ? _myTokensTab(context, currentUid)
                        : _profileTab(
                            context,
                            userName,
                            userEmail,
                            profileImage: profileImage,
                            userData: userData,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAB 0: HOME DASHBOARD
  // ============================================================

  Widget _homeDashboardTab(
    BuildContext context,
    Hospital hospital,
    String userName,
    String currentUid,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _welcomeHeader(userName),
          const SizedBox(height: 18),
          if (currentUid.isNotEmpty) ...[
            _liveActiveTokenSection(context, currentUid),
            const SizedBox(height: 18),
          ],
          _quickActionsGrid(context),
          const SizedBox(height: 22),
          _quickStats(hospital),
          const SizedBox(height: 26),
          _popularSpecialtiesSection(context),
          const SizedBox(height: 26),
          _hospitalSection(context, hospital),
          const SizedBox(height: 26),
          _howItWorksSection(),
        ],
      ),
    );
  }

  // ============================================================
  // LIVE ACTIVE TOKEN SECTION (VIP HERO BANNER)
  // ============================================================

  Widget _liveActiveTokenSection(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('tokens')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        final activeDocs = docs.where((doc) {
          final s = (doc.data()['status'] ?? '').toString().toLowerCase();
          return s == 'waiting' || s == 'called' || s == 'serving';
        }).toList();

        if (activeDocs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Prioritize called/serving first, then earliest joinedAt
        activeDocs.sort((a, b) {
          final aStatus = (a.data()['status'] ?? '').toString().toLowerCase();
          final bStatus = (b.data()['status'] ?? '').toString().toLowerCase();
          final aIsCalling = aStatus == 'called' || aStatus == 'serving';
          final bIsCalling = bStatus == 'called' || bStatus == 'serving';
          if (aIsCalling && !bIsCalling) return -1;
          if (!aIsCalling && bIsCalling) return 1;

          final aTime = a.data()['joinedAt'] as Timestamp?;
          final bTime = b.data()['joinedAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        });

        final topDoc = activeDocs.first;
        final data = topDoc.data();
        final tokenId = topDoc.id;
        final tokenNumber = data['tokenNumber']?.toString() ?? 'A-000';
        final status = (data['status'] ?? 'waiting').toString().toLowerCase();
        final isCalling = status == 'called' || status == 'serving';
        final serviceName = data['serviceName']?.toString() ?? 'Hospital Service';
        final patientName = data['userName']?.toString() ?? data['customerName']?.toString() ?? '';
        final hospitalName = data['hospitalName']?.toString() ?? 'Sunrise Care Hospital';
        final timeSlot = data['timeSlot']?.toString();
        final estimatedWait = data['estimatedMinutes'] ?? 15;
        final doctorName = data['doctorName']?.toString();
        final doctorDesignation = data['doctorDesignation']?.toString();
        final doctorRoom = (data['doctorRoom'] ?? data['doctorCounter'])?.toString();

        final Color primaryAccent = isCalling ? const Color(0xFF38BDF8) : gold;
        final Color bgGlow = isCalling ? const Color(0xFF0369A1) : const Color(0xFF78350F);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                bgGlow.withValues(alpha: 0.35),
                const Color(0xFF131C2E),
                const Color(0xFF0F172A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: primaryAccent.withValues(alpha: isCalling ? 0.8 : 0.4),
              width: isCalling ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryAccent.withValues(alpha: isCalling ? 0.35 : 0.16),
                blurRadius: isCalling ? 22 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top status bar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: primaryAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCalling ? Icons.campaign_rounded : Icons.hourglass_top_rounded,
                            size: 14,
                            color: primaryAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isCalling ? 'NOW CALLING • GO TO COUNTER' : 'LIVE QUEUE PASS • IN LINE',
                            style: TextStyle(
                              color: primaryAccent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (activeDocs.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+${activeDocs.length - 1} more',
                          style: const TextStyle(color: subTextColor, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Main token details row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Glowing Token Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCalling
                              ? [const Color(0xFF38BDF8), const Color(0xFF0284C7)]
                              : [lightGold, gold],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryAccent.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'TOKEN',
                            style: TextStyle(
                              color: Color(0xFF17100A),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tokenNumber,
                            style: const TextStyle(
                              color: Color(0xFF17100A),
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Service & Patient Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (patientName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.person, size: 13, color: lightGold),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Patient: $patientName',
                                    style: const TextStyle(
                                      color: lightGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (doctorName != null && doctorName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.medical_information_rounded, size: 13, color: Color(0xFF9BD9FF)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Doctor: $doctorName${doctorRoom != null && doctorRoom.isNotEmpty ? ' ($doctorRoom)' : ''}',
                                    style: const TextStyle(
                                      color: Color(0xFF9BD9FF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                timeSlot != null && timeSlot != 'Live Queue'
                                    ? Icons.schedule_rounded
                                    : Icons.bolt_rounded,
                                size: 13,
                                color: subTextColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  timeSlot != null && timeSlot != 'Live Queue'
                                      ? 'Slot: $timeSlot'
                                      : 'Estimated wait: ~$estimatedWait mins',
                                  style: const TextStyle(
                                    color: subTextColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showTokenPassDialog(
                            context,
                            tokenId: tokenId,
                            tokenNumber: tokenNumber,
                            serviceName: serviceName,
                            hospitalName: hospitalName,
                            status: isCalling ? 'NOW CALLING' : 'WAITING',
                            patientName: patientName,
                            timeSlot: timeSlot,
                            doctorName: doctorName,
                            doctorDesignation: doctorDesignation,
                            doctorRoom: doctorRoom,
                          );
                        },
                        icon: const Icon(Icons.qr_code_rounded, size: 17),
                        label: const Text('View Digital Pass'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedTabIndex = 1;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('All Passes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // QUICK ACTIONS GRID
  // ============================================================

  Widget _quickActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCardItem(
                context,
                title: 'Book Service',
                subtitle: 'OPD & Doctors',
                icon: Icons.medical_services_rounded,
                accentColor: gold,
                gradientColors: [
                  const Color(0xFFF5A623).withValues(alpha: 0.20),
                  const Color(0xFF1E283D),
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Services_screen(businessId: businessId),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCardItem(
                context,
                title: 'Scan Desk QR',
                subtitle: 'Instant Token',
                icon: Icons.qr_code_scanner_rounded,
                accentColor: const Color(0xFF38BDF8),
                gradientColors: [
                  const Color(0xFF38BDF8).withValues(alpha: 0.20),
                  const Color(0xFF1E283D),
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QRScannerScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCardItem(
                context,
                title: 'My Passes',
                subtitle: 'Active & History',
                icon: Icons.receipt_long_rounded,
                accentColor: const Color(0xFFA78BFA),
                gradientColors: [
                  const Color(0xFFA78BFA).withValues(alpha: 0.20),
                  const Color(0xFF1E283D),
                ],
                onTap: () {
                  setState(() {
                    _selectedTabIndex = 1;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCardItem(
                context,
                title: 'Emergency',
                subtitle: '24/7 Helpline',
                icon: Icons.emergency_rounded,
                accentColor: const Color(0xFFF87171),
                gradientColors: [
                  const Color(0xFFF87171).withValues(alpha: 0.20),
                  const Color(0xFF1E283D),
                ],
                onTap: () => _showEmergencySheet(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCardItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: accentColor.withValues(alpha: 0.15),
        highlightColor: accentColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 21),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: subTextColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // POPULAR SPECIALTIES SECTION
  // ============================================================

  Widget _popularSpecialtiesSection(BuildContext context) {
    final specialties = [
      {'name': 'General OPD', 'icon': Icons.health_and_safety_rounded, 'time': '~15m', 'tag': 'Doctor'},
      {'name': 'Pathology Lab', 'icon': Icons.biotech_rounded, 'time': '~10m', 'tag': 'Blood Test'},
      {'name': 'Radiology', 'icon': Icons.sensors_rounded, 'time': '~20m', 'tag': 'X-Ray / Scan'},
      {'name': 'Pharmacy', 'icon': Icons.medication_rounded, 'time': '~5m', 'tag': 'Medicines'},
      {'name': 'Pediatrics', 'icon': Icons.child_care_rounded, 'time': '~15m', 'tag': 'Child Care'},
      {'name': 'Dental Clinic', 'icon': Icons.sentiment_very_satisfied_rounded, 'time': '~25m', 'tag': 'Teeth'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Featured Departments',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Services_screen(businessId: businessId),
                  ),
                );
              },
              child: const Row(
                children: [
                  Text('View All', style: TextStyle(color: lightGold, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 11, color: lightGold),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: specialties.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = specialties[i];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Services_screen(businessId: businessId),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 125,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              size: 18,
                              color: lightGold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['time'] as String,
                              style: const TextStyle(color: subTextColor, fontSize: 9.5),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] as String,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['tag'] as String,
                            style: const TextStyle(color: subTextColor, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HOW IT WORKS SECTION
  // ============================================================

  Widget _howItWorksSection() {
    return _glassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline_rounded, color: gold, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'How QueueLess Works',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _stepRow(
            step: '1',
            title: 'Choose Service or Scan QR',
            desc: 'Select a hospital department from your phone or scan the desk QR at reception.',
          ),
          const SizedBox(height: 12),
          _stepRow(
            step: '2',
            title: 'Track Live Queue Anywhere',
            desc: 'Watch real-time wait times and live token progress without standing in waiting rooms.',
          ),
          const SizedBox(height: 12),
          _stepRow(
            step: '3',
            title: 'Direct Counter Walk-in',
            desc: 'Get an instant call alert on your phone and walk straight to the doctor’s chamber.',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _stepRow({
    required String step,
    required String title,
    required String desc,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Text(
                step,
                style: const TextStyle(
                  color: lightGold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 24,
                color: Colors.white.withValues(alpha: 0.1),
                margin: const EdgeInsets.symmetric(vertical: 3),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: subTextColor,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TAB 1: MY TOKENS VIEW
  // ============================================================

  Widget _myTokensTab(BuildContext context, String uid) {
    if (uid.isEmpty) {
      return const Center(
        child: Text(
          'Please log in to view your tokens.',
          style: TextStyle(color: textColor),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('tokens')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: gold),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load tokens.\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final docs = snapshot.data?.docs.toList() ?? [];

        // Sort in memory by joinedAt descending
        docs.sort((a, b) {
          final aTime = a.data()['joinedAt'] as Timestamp?;
          final bTime = b.data()['joinedAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        // Separate active and history
        final activeDocs = docs.where((doc) {
          final s = (doc.data()['status'] ?? '').toString().toLowerCase();
          return s == 'waiting' || s == 'called' || s == 'serving';
        }).toList();

        final historyDocs = docs.where((doc) {
          final s = (doc.data()['status'] ?? '').toString().toLowerCase();
          return s != 'waiting' && s != 'called' && s != 'serving';
        }).toList();

        final currentList = _tokensFilterIndex == 0 ? activeDocs : historyDocs;

        return Column(
          children: [
            // Filter Segment Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tokensFilterIndex = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _tokensFilterIndex == 0 ? gold : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 15,
                                color: _tokensFilterIndex == 0 ? const Color(0xFF17100A) : subTextColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Active Passes (${activeDocs.length})',
                                style: TextStyle(
                                  color: _tokensFilterIndex == 0 ? const Color(0xFF17100A) : subTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tokensFilterIndex = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _tokensFilterIndex == 1 ? gold : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 16,
                                color: _tokensFilterIndex == 1 ? const Color(0xFF17100A) : subTextColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Past Visits (${historyDocs.length})',
                                style: TextStyle(
                                  color: _tokensFilterIndex == 1 ? const Color(0xFF17100A) : subTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Token list / empty state
            Expanded(
              child: currentList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: gold.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: gold.withValues(alpha: 0.25)),
                              ),
                              child: Icon(
                                _tokensFilterIndex == 0
                                    ? Icons.receipt_long_outlined
                                    : Icons.history_edu_rounded,
                                size: 40,
                                color: gold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _tokensFilterIndex == 0
                                  ? 'No Active Queue Passes'
                                  : 'No Past Visits Recorded',
                              style: const TextStyle(
                                color: textColor,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _tokensFilterIndex == 0
                                  ? 'You are not currently waiting in line. Choose a hospital department or scan the desk QR code.'
                                  : 'Completed appointments and past token history will appear here once served.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: subTextColor,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Services_screen(
                                      businessId: businessId,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.medical_services_outlined, size: 18),
                              label: const Text('Book a Service'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gold,
                                foregroundColor: const Color(0xFF17100A),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                      itemCount: currentList.length,
                      itemBuilder: (context, index) {
                        final doc = currentList[index];
                        final data = doc.data();
                        final tokenId = doc.id;
                        if (_tokensFilterIndex == 0) {
                          return _tokenCard(context, tokenId: tokenId, token: data);
                        } else {
                          return _historyTokenCard(context, tokenId: tokenId, token: data);
                        }
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // TOKEN CARD (ACTIVE BOARDING PASS)
  // ============================================================

  Widget _tokenCard(
    BuildContext context, {
    required String tokenId,
    required Map<String, dynamic> token,
  }) {
    final tokenNumber = token['tokenNumber']?.toString() ?? 'A-000';
    final patientName = token['userName']?.toString() ?? token['customerName']?.toString() ?? '';
    final serviceName = token['serviceName']?.toString() ?? 'Hospital Service';
    final status = token['status']?.toString().toLowerCase() ?? 'waiting';
    final hospitalName = token['hospitalName']?.toString() ?? 'Sunrise Care Hospital';
    final estimatedMinutes = token['estimatedMinutes'] ?? 15;
    final doctorName = token['doctorName']?.toString();
    final doctorDesignation = token['doctorDesignation']?.toString();
    final doctorRoom = (token['doctorRoom'] ?? token['doctorCounter'])?.toString();

    Color badgeColor;
    String badgeText;
    bool isCalling = false;

    if (status == 'called' || status == 'serving') {
      badgeColor = const Color(0xFF38BDF8);
      badgeText = 'NOW CALLING • GO TO COUNTER';
      isCalling = true;
    } else if (status == 'waiting') {
      badgeColor = gold;
      badgeText = 'WAITING IN QUEUE';
    } else {
      badgeColor = Colors.grey;
      badgeText = status.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D30),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCalling ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.1),
          width: isCalling ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCalling
                ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: isCalling ? 18 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 3.5, backgroundColor: badgeColor),
                          const SizedBox(width: 6),
                          Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _timeAgo(token['joinedAt']),
                      style: const TextStyle(
                        color: subTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Token number & Service Info
                Row(
                  children: [
                    // Token number badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCalling
                              ? [const Color(0xFF38BDF8), const Color(0xFF0284C7)]
                              : [lightGold, gold],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'TOKEN',
                            style: TextStyle(
                              color: Color(0xFF17100A),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tokenNumber,
                            style: const TextStyle(
                              color: Color(0xFF17100A),
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (patientName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.person, size: 13, color: lightGold),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Patient: $patientName',
                                    style: const TextStyle(
                                      color: lightGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (doctorName != null && doctorName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.medical_information_rounded, size: 13, color: Color(0xFF9BD9FF)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Doctor: $doctorName${doctorRoom != null && doctorRoom.isNotEmpty ? ' • $doctorRoom' : ''}',
                                    style: const TextStyle(
                                      color: Color(0xFF9BD9FF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            hospitalName,
                            style: const TextStyle(
                              color: subTextColor,
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                token['timeSlot'] != null && token['timeSlot'] != 'Live Queue'
                                    ? Icons.schedule_rounded
                                    : Icons.bolt_rounded,
                                color: subTextColor,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                token['timeSlot'] != null && token['timeSlot'] != 'Live Queue'
                                    ? 'Slot: ${token['timeSlot']}'
                                    : 'Est. wait: ~$estimatedMinutes mins',
                                style: const TextStyle(
                                  color: subTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Perforated Dashed Divider
          Row(
            children: [
              Container(
                width: 10,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF060810),
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(10)),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxWidth = constraints.constrainWidth();
                    const dashWidth = 5.0;
                    const dashSpace = 4.0;
                    final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
                    return Flex(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      direction: Axis.horizontal,
                      children: List.generate(dashCount, (_) {
                        return SizedBox(
                          width: dashWidth,
                          height: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              Container(
                width: 10,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF060810),
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showTokenPassDialog(
                        context,
                        tokenId: tokenId,
                        tokenNumber: tokenNumber,
                        serviceName: serviceName,
                        hospitalName: hospitalName,
                        status: badgeText,
                        patientName: patientName,
                        timeSlot: token['timeSlot']?.toString(),
                        doctorName: doctorName,
                        doctorDesignation: doctorDesignation,
                        doctorRoom: doctorRoom,
                      );
                    },
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('Digital Pass'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: lightGold,
                      side: BorderSide(color: gold.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (status == 'waiting') ...[
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () => _confirmCancelToken(context, tokenId),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY TOKEN CARD
  // ============================================================

  Widget _historyTokenCard(
    BuildContext context, {
    required String tokenId,
    required Map<String, dynamic> token,
  }) {
    final tokenNumber = token['tokenNumber']?.toString() ?? 'A-000';
    final patientName = token['userName']?.toString() ?? token['customerName']?.toString() ?? '';
    final serviceName = token['serviceName']?.toString() ?? 'Hospital Service';
    final status = token['status']?.toString().toLowerCase() ?? 'completed';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';

    final Color statusColor = isCompleted
        ? const Color(0xFF4ADE80)
        : (isCancelled ? Colors.grey.shade400 : const Color(0xFF38BDF8));
    final String statusText = isCompleted
        ? 'VISIT COMPLETED'
        : (isCancelled ? 'CANCELLED' : (token['status']?.toString().toUpperCase() ?? 'STATUS'));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131D30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _timeAgo(token['joinedAt']),
                style: const TextStyle(color: subTextColor, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C273E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  tokenNumber,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (patientName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Patient: $patientName',
                        style: const TextStyle(color: subTextColor, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (token['doctorName'] != null && token['doctorName'].toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Doctor: ${token['doctorName']}',
                        style: const TextStyle(color: Color(0xFF9BD9FF), fontSize: 11.5, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Services_screen(businessId: businessId),
                    ),
                  );
                },
                child: const Text('Book Again', style: TextStyle(color: lightGold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTokenPassDialog(
    BuildContext context, {
    required String tokenId,
    required String tokenNumber,
    required String serviceName,
    required String hospitalName,
    required String status,
    String? patientName,
    String? timeSlot,
    String? doctorName,
    String? doctorDesignation,
    String? doctorRoom,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: const Color(0xFF101726),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: gold.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Queue Digital Pass',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hospitalName,
                    style: const TextStyle(color: subTextColor, fontSize: 12),
                  ),
                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          gold.withOpacity(0.18),
                          const Color(0xFF17202F),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: gold.withOpacity(0.35)),
                    ),
                    child: Column(
                      children: [
                        if (timeSlot != null && timeSlot.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: gold.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              timeSlot == 'Live Queue'
                                  ? '⚡ LIVE WALK-IN'
                                  : '🕒 $timeSlot',
                              style: const TextStyle(
                                color: lightGold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          tokenNumber,
                          style: const TextStyle(
                            color: gold,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        if (patientName != null && patientName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: gold.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person, size: 14, color: lightGold),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Patient: $patientName',
                                    style: const TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (doctorName != null && doctorName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: gold.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.medical_information_rounded, size: 15, color: lightGold),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Doctor: $doctorName',
                                        style: const TextStyle(
                                          color: textColor,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if ((doctorDesignation != null && doctorDesignation.isNotEmpty) ||
                                          (doctorRoom != null && doctorRoom.isNotEmpty))
                                        Text(
                                          [
                                            if (doctorDesignation != null && doctorDesignation.isNotEmpty) doctorDesignation,
                                            if (doctorRoom != null && doctorRoom.isNotEmpty) doctorRoom,
                                          ].join(' • '),
                                          style: const TextStyle(
                                            color: subTextColor,
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          serviceName,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: QrImageView(
                            data: 'queueless://token?id=$tokenId&number=$tokenNumber',
                            version: QrVersions.auto,
                            size: 140,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: const Color(0xFF17100A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCancelToken(BuildContext context, String tokenId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF17202F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Cancel Token?',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to cancel your queue token? You will lose your position in line.',
            style: TextStyle(color: subTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No, Keep it', style: TextStyle(color: subTextColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final tokenRef = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('tokens')
            .doc(tokenId);
        final businessRef = _firestore
            .collection('businesses')
            .doc(businessId);

        final wasCancelled = await _firestore.runTransaction<bool>((transaction) async {
          final tokenSnap = await transaction.get(tokenRef);
          if (!tokenSnap.exists) return false;
          final status = (tokenSnap.data()?['status'] ?? '').toString().toLowerCase();
          if (status != 'waiting') return false;

          transaction.update(tokenRef, {
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
          transaction.update(businessRef, {
            'activeTokens': FieldValue.increment(-1),
          });
          return true;
        });

        if (context.mounted) {
          if (wasCancelled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Token cancelled successfully.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Token cannot be cancelled.')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to cancel token.')),
          );
        }
      }
    }
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'Just now';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ============================================================
  // TAB 2: PROFILE TAB
  // ============================================================

  Widget _buildAvatar(
    String? profileImage, {
    required double radius,
    double iconSize = 24,
  }) {
    ImageProvider? imageProvider;

    if (profileImage != null && profileImage.trim().isNotEmpty) {
      final trimmed = profileImage.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        imageProvider = NetworkImage(trimmed);
      } else {
        try {
          String cleanBase64 = trimmed;
          if (cleanBase64.contains(',')) {
            cleanBase64 = cleanBase64.split(',').last;
          }
          final bytes = base64Decode(cleanBase64);
          imageProvider = MemoryImage(bytes);
        } catch (e) {
          debugPrint('Error decoding base64 avatar: $e');
        }
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: lightGold,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(
              Icons.person,
              size: iconSize,
              color: const Color(0xFF452B00),
            )
          : null,
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploadingProfilePic = true);

      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'profileImage': base64String,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: gold, size: 20),
                  SizedBox(width: 10),
                  Text('Profile picture updated successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF101B2B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfilePic = false);
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF17202F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Photo', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove your profile picture?', style: TextStyle(color: subTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: subTextColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isUploadingProfilePic = true);
      await _firestore.collection('users').doc(user.uid).update({
        'profileImage': FieldValue.delete(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfilePic = false);
      }
    }
  }

  void _showPhotoPickerSheet(BuildContext context, String? currentPhoto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose an option to update your photo',
                  style: TextStyle(color: subTextColor, fontSize: 13),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: gold, size: 22),
                  ),
                  title: const Text('Take Photo', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Use your device camera', style: TextStyle(color: subTextColor, fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: gold, size: 22),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pick from your gallery', style: TextStyle(color: subTextColor, fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
                if (currentPhoto != null && currentPhoto.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                    ),
                    title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _removeProfilePicture();
                    },
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEditProfileSheet(
    BuildContext context, {
    required String currentName,
    required String currentPhone,
    required String email,
    String? profileImage,
  }) {
    final nameController = TextEditingController(
      text: currentName == 'User' ? '' : currentName,
    );
    final phoneController = TextEditingController(text: currentPhone);
    String? nameError;
    String? phoneError;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(bottomSheetContext).viewInsets.bottom;
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.92,
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: bottomInset + 24,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF131B2E),
                      Color(0xFF0C1220),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(
                    color: gold.withOpacity(0.28),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern Pill Handle
                      Center(
                        child: Container(
                          width: 48,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: gold.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gold.withOpacity(0.28)),
                            ),
                            child: const Icon(Icons.manage_accounts_rounded, color: lightGold, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Patient Profile',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Update your hospital registration details',
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(bottomSheetContext),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: subTextColor, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Profile Avatar Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF172238).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [lightGold, gold],
                                    ),
                                  ),
                                  child: _buildAvatar(profileImage, radius: 28, iconSize: 32),
                                ),
                                Positioned(
                                  bottom: -1,
                                  right: -1,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: gold,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF101726), width: 1.5),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 11,
                                      color: Color(0xFF17100A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Profile Picture',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Shown on hospital queue & token passes',
                                    style: TextStyle(
                                      color: subTextColor.withOpacity(0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(bottomSheetContext);
                                _showPhotoPickerSheet(context, profileImage);
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: gold.withOpacity(0.14),
                                foregroundColor: lightGold,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SECTION 1: IDENTITY
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 14, color: lightGold.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          const Text(
                            'PATIENT IDENTITY',
                            style: TextStyle(
                              color: lightGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Full Name Field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF17202F),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: nameError != null ? Colors.redAccent : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: TextField(
                          controller: nameController,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{M}\s'-]", unicode: true)),
                          ],
                          onChanged: (val) {
                            if (nameError != null) {
                              setSheetState(() => nameError = null);
                            }
                          },
                          style: const TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            icon: const Icon(Icons.person_outline_rounded, color: lightGold, size: 21),
                            labelText: 'Full Name (Letters Only)',
                            labelStyle: TextStyle(color: subTextColor.withOpacity(0.8), fontSize: 13),
                            hintText: 'e.g. Aditi Sharma',
                            hintStyle: TextStyle(color: subTextColor.withOpacity(0.4), fontSize: 13),
                          ),
                        ),
                      ),
                      if (nameError != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            nameError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            'Strict validation: only alphabetic letters and spaces are accepted.',
                            style: TextStyle(color: subTextColor.withOpacity(0.55), fontSize: 10.5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // SECTION 2: CONTACT INFORMATION
                      Row(
                        children: [
                          Icon(Icons.contact_phone_outlined, size: 14, color: lightGold.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          const Text(
                            'CONTACT & ACCOUNT',
                            style: TextStyle(
                              color: lightGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Phone Number Field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF17202F),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: phoneError != null ? Colors.redAccent : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                          ],
                          onChanged: (val) {
                            if (phoneError != null) {
                              setSheetState(() => phoneError = null);
                            }
                          },
                          style: const TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            icon: const Icon(Icons.phone_outlined, color: lightGold, size: 21),
                            labelText: 'Phone Number',
                            labelStyle: TextStyle(color: subTextColor.withOpacity(0.8), fontSize: 13),
                            hintText: '+91 98765 43210',
                            hintStyle: TextStyle(color: subTextColor.withOpacity(0.4), fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Email Field (Read only)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF121825),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.email_outlined, color: subTextColor, size: 21),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account Email (Protected)',
                                    style: TextStyle(
                                      color: subTextColor.withOpacity(0.65),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email.isNotEmpty ? email : 'Not available',
                                    style: const TextStyle(
                                      color: textColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 11, color: lightGold),
                                  SizedBox(width: 4),
                                  Text(
                                    'Linked',
                                    style: TextStyle(
                                      color: lightGold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 26),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving ? null : () => Navigator.pop(bottomSheetContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: subTextColor,
                                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final rawName = nameController.text.trim();
                                      final rawPhone = phoneController.text.trim();

                                      if (rawName.isEmpty) {
                                        setSheetState(() => nameError = 'Please enter your name.');
                                        return;
                                      }
                                      if (rawName.length < 2) {
                                        setSheetState(() => nameError = 'Name must be at least 2 characters.');
                                        return;
                                      }
                                      final validNameRegex = RegExp(r"^[\p{L}\p{M}\s'-]+$", unicode: true);
                                      if (!validNameRegex.hasMatch(rawName)) {
                                        setSheetState(() => nameError = 'Only letters, spaces, apostrophes and hyphens are allowed.');
                                        return;
                                      }

                                      setSheetState(() => isSaving = true);

                                      try {
                                        final user = _auth.currentUser;
                                        if (user != null) {
                                          await _firestore.collection('users').doc(user.uid).set({
                                            'name': rawName,
                                            'fullName': rawName,
                                            'phone': rawPhone,
                                            'updatedAt': FieldValue.serverTimestamp(),
                                          }, SetOptions(merge: true));

                                          await user.updateDisplayName(rawName);

                                          // Also update any active waiting tokens
                                          final activeTokensSnap = await _firestore
                                              .collection('businesses')
                                              .doc(businessId)
                                              .collection('tokens')
                                              .where('userId', isEqualTo: user.uid)
                                              .where('status', isEqualTo: 'waiting')
                                              .get();

                                          if (activeTokensSnap.docs.isNotEmpty) {
                                            final batch = _firestore.batch();
                                            for (final doc in activeTokensSnap.docs) {
                                              batch.update(doc.reference, {
                                                'userName': rawName,
                                                'customerName': rawName,
                                              });
                                            }
                                            await batch.commit();
                                          }
                                        }

                                        if (!bottomSheetContext.mounted) return;
                                        Navigator.pop(bottomSheetContext);

                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.check_circle_rounded, color: gold, size: 20),
                                                  SizedBox(width: 10),
                                                  Text('Profile updated successfully!'),
                                                ],
                                              ),
                                              backgroundColor: const Color(0xFF101B2B),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setSheetState(() => isSaving = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to update profile: $e'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gold,
                                foregroundColor: const Color(0xFF17100A),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF17100A),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _profileTab(
    BuildContext context,
    String userName,
    String email, {
    String? profileImage,
    Map<String, dynamic> userData = const {},
  }) {
    final currentUser = _auth.currentUser;
    final currentUid = currentUser?.uid ?? '';
    final userPhone = userData['phone']?.toString().trim() ?? '';
    final patientIdSnippet = currentUid.length >= 6
        ? currentUid.substring(0, 6).toUpperCase()
        : 'CARE';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HERO PATIENT IDENTIFICATION CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1B273E),
                  Color(0xFF0F1728),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: gold.withOpacity(0.3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: gold.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Patient ID chip & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gold.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 13, color: lightGold),
                          const SizedBox(width: 5),
                          Text(
                            'PATIENT ID: #$patientIdSnippet',
                            style: const TextStyle(
                              color: lightGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(radius: 3, backgroundColor: Color(0xFF4ADE80)),
                          SizedBox(width: 5),
                          Text(
                            'Active Patient',
                            style: TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Avatar, Name, and Quick Info
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [lightGold, gold, Color(0xFFB87008)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withOpacity(0.35),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: _buildAvatar(profileImage, radius: 36, iconSize: 40),
                        ),
                        if (_isUploadingProfilePic)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: gold,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUploadingProfilePic
                                ? null
                                : () => _showPhotoPickerSheet(context, profileImage),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: gold,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0F1728), width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 13,
                                color: Color(0xFF17100A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 13, color: subTextColor),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  email.isNotEmpty ? email : 'Signed in Patient',
                                  style: const TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (userPhone.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 13, color: lightGold),
                                const SizedBox(width: 5),
                                Text(
                                  userPhone,
                                  style: const TextStyle(
                                    color: lightGold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                Divider(color: Colors.white.withOpacity(0.08), height: 1),
                const SizedBox(height: 14),

                // Edit Profile Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openEditProfileSheet(
                      context,
                      currentName: userName,
                      currentPhone: userPhone,
                      email: email,
                      profileImage: profileImage,
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: const Text('Edit Profile Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: const Color(0xFF17100A),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. PATIENT LIVE STATS
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('businesses')
                .doc(businessId)
                .collection('tokens')
                .where('userId', isEqualTo: currentUid)
                .snapshots(),
            builder: (context, tokenSnap) {
              final tokenDocs = tokenSnap.data?.docs ?? [];
              final activeCount = tokenDocs.where((d) {
                final s = (d.data()['status'] ?? '').toString().toLowerCase();
                return s == 'waiting' || s == 'called' || s == 'serving';
              }).length;
              final totalCount = tokenDocs.length;

              return Row(
                children: [
                  Expanded(
                    child: _glassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      radius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: gold.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.confirmation_number_outlined, size: 15, color: gold),
                              ),
                              const Spacer(),
                              if (activeCount > 0)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4ADE80),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            activeCount > 0 ? '$activeCount Active' : '0 Active',
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Queue Tokens',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _glassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      radius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9BD9FF).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.history_rounded, size: 15, color: Color(0xFF9BD9FF)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$totalCount Visits',
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Total Bookings',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _glassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      radius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4ADE80).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.local_hospital_outlined, size: 15, color: Color(0xFF4ADE80)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sunrise Care',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Default Hospital',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // 3. QUEUE & HOSPITAL SECTION
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'HOSPITAL & QUEUE SERVICES',
              style: TextStyle(
                color: lightGold.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _glassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _profileOption(
                  icon: Icons.receipt_long_rounded,
                  iconColor: gold,
                  title: 'My Tokens',
                  subtitle: 'View live queue order & digital token passes',
                  trailingWidget: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Live Queue',
                      style: TextStyle(color: lightGold, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () => setState(() => _selectedTabIndex = 1),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                _profileOption(
                  icon: Icons.medical_services_outlined,
                  iconColor: const Color(0xFF9BD9FF),
                  iconBgColor: const Color(0xFF9BD9FF).withOpacity(0.12),
                  title: 'Book a Service',
                  subtitle: 'Browse departments & get an instant token',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Services_screen(businessId: businessId),
                      ),
                    );
                  },
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                _profileOption(
                  icon: Icons.qr_code_scanner_rounded,
                  iconColor: const Color(0xFF4ADE80),
                  iconBgColor: const Color(0xFF4ADE80).withOpacity(0.12),
                  title: 'Scan Hospital QR',
                  subtitle: 'Scan desk code to check in instantly',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const QRScannerScreen(),
                      ),
                    );
                  },
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                _profileOption(
                  icon: Icons.local_hospital_rounded,
                  iconColor: lightGold,
                  title: 'Hospital Details',
                  subtitle: 'Sunrise Care Hospital • Multi-Specialty Care',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF101726),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: gold.withOpacity(0.3)),
                        ),
                        title: const Row(
                          children: [
                            Icon(Icons.local_hospital_rounded, color: gold),
                            SizedBox(width: 10),
                            Text('Sunrise Care Hospital', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Address: Opp. Civil Hospital, Ring Road', style: TextStyle(color: subTextColor.withOpacity(0.9), fontSize: 13)),
                            const SizedBox(height: 8),
                            Text('Queue Status: Open & Active', style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Emergency Help: +91 98765 00000', style: TextStyle(color: subTextColor.withOpacity(0.9), fontSize: 13)),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close', style: TextStyle(color: gold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. ACCOUNT SETTINGS & PREFERENCES
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'ACCOUNT & SECURITY',
              style: TextStyle(
                color: lightGold.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _glassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _profileOption(
                  icon: Icons.person_outline_rounded,
                  iconColor: gold,
                  title: 'Edit Personal Profile',
                  subtitle: 'Full name & contact telephone',
                  onTap: () => _openEditProfileSheet(
                    context,
                    currentName: userName,
                    currentPhone: userPhone,
                    email: email,
                    profileImage: profileImage,
                  ),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                _profileOption(
                  icon: Icons.verified_user_outlined,
                  iconColor: const Color(0xFFC084FC),
                  iconBgColor: const Color(0xFFC084FC).withOpacity(0.12),
                  title: 'Account Authentication',
                  subtitle: email.isNotEmpty ? email : 'Verified Patient Account',
                  trailingWidget: const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 16),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                _profileOption(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF2DD4BF),
                  iconBgColor: const Color(0xFF2DD4BF).withOpacity(0.12),
                  title: 'QueueLess Care Patient Portal',
                  subtitle: 'Version 2.4.0 • Enterprise Healthcare System',
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 5. SIGN OUT BUTTON
          Container(
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF17202F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: const Row(
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text('Sign Out', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: const Text(
                        'Are you sure you want to log out from QueueLess?',
                        style: TextStyle(color: subTextColor),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text('Cancel', style: TextStyle(color: subTextColor)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Log Out'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await _auth.signOut();
                    if (!context.mounted) return;
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Sign Out of Account',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Color? iconBgColor,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBgColor ?? gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (iconColor ?? gold).withOpacity(0.2),
                  ),
                ),
                child: Icon(icon, color: iconColor ?? gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: subTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingWidget != null) ...[
                trailingWidget,
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: subTextColor.withOpacity(0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING SCREEN
  // ============================================================

  Widget _loadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFF060810),
      body: Center(
        child: CircularProgressIndicator(
          color: gold,
        ),
      ),
    );
  }

  // ============================================================
  // ERROR SCREEN
  // ============================================================

  Widget _errorScreen(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF060810),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: gold,
                size: 50,
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: subTextColor,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: const Color(0xFF452B00),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _topBar({String? profileImage}) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1323).withValues(alpha: 0.65),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_selectedTabIndex == 0) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [lightGold, gold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: gold.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: Color(0xFF17100A),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Sunrise Care',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 2.5, backgroundColor: Color(0xFF4ADE80)),
                            SizedBox(width: 4),
                            Text(
                              'OPD OPEN',
                              style: TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Smart Hospital Queue Portal',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_selectedTabIndex == 1) ...[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'My Queue Passes',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Live tokens & visit history',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Patient Profile',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Personal identity & preferences',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 4),

          // Emergency SOS Quick Button
          IconButton(
            onPressed: () => _showEmergencySheet(context),
            tooltip: 'Emergency SOS',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.emergency_outlined,
                color: Color(0xFFF87171),
                size: 18,
              ),
            ),
          ),

          // Notifications Button
          IconButton(
            onPressed: () => _showNotificationsSheet(context),
            tooltip: 'Notifications',
            icon: Stack(
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: textColor,
                  size: 22,
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Avatar
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedTabIndex = 2;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gold.withValues(alpha: 0.8), width: 1.5),
              ),
              child: _buildAvatar(profileImage, radius: 16, iconSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMERGENCY SHEET
  // ============================================================

  void _showEmergencySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF131722),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency & Trauma Care',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '24/7 Rapid Response Casualty Unit',
                            style: TextStyle(color: subTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFF87171), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Critical emergency cases do not require token booking. Please proceed straight to Emergency Gate 1.',
                          style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _emergencyContactTile(
                  icon: Icons.phone_in_talk_rounded,
                  title: 'Casualty Emergency Line',
                  number: '+91 98765 43210',
                ),
                const SizedBox(height: 10),
                _emergencyContactTile(
                  icon: Icons.airport_shuttle_rounded,
                  title: 'Ambulance Helpline',
                  number: '108 (Toll Free)',
                ),
                const SizedBox(height: 10),
                _emergencyContactTile(
                  icon: Icons.local_hospital_rounded,
                  title: 'Hospital Reception Desk',
                  number: '+91 22 2849 0000',
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emergencyContactTile({
    required IconData icon,
    required String title,
    required String number,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF17202F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: lightGold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: subTextColor, fontSize: 11)),
                const SizedBox(height: 2),
                Text(number, style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOTIFICATIONS SHEET
  // ============================================================

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF131722),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: gold.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, color: gold, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Queue Updates & Alerts',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _notificationTile(
                  title: 'Queue Desk Operational',
                  subtitle: 'Sunrise Care Hospital OPD counters are actively processing live tokens.',
                  time: 'Live',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF4ADE80),
                ),
                const SizedBox(height: 10),
                _notificationTile(
                  title: 'Digital Pass Guidance',
                  subtitle: 'Show your token QR pass directly at the doctor’s chamber door for fast entry.',
                  time: '1h ago',
                  icon: Icons.qr_code_2_rounded,
                  iconColor: lightGold,
                ),
                const SizedBox(height: 10),
                _notificationTile(
                  title: 'Calling Audio Alerts',
                  subtitle: 'Device sound and push notifications will chime once your token number is announced.',
                  time: 'Today',
                  icon: Icons.volume_up_rounded,
                  iconColor: const Color(0xFF38BDF8),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: const Color(0xFF17100A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notificationTile({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF17202F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(time, style: const TextStyle(color: subTextColor, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: subTextColor, fontSize: 11.5, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WELCOME HEADER
  // ============================================================

  Widget _welcomeHeader(String userName) {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $userName 👋',
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sunrise Care Hospital • Live Queue Portal',
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // QUICK STATS
  // ============================================================

  Widget _quickStats(Hospital hospital) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Queue Live Telemetry',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.timer_rounded,
                iconColor: gold,
                title: 'Average Wait',
                value: '${hospital.averageWait} mins',
                subValue: 'Fast Movement',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.people_alt_rounded,
                iconColor: const Color(0xFF38BDF8),
                title: 'Active Queue',
                value: '${hospital.activeTokens} waiting',
                subValue: 'Live Count',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: hospital.queueOpen ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                iconColor: hospital.queueOpen ? const Color(0xFF4ADE80) : Colors.redAccent,
                title: 'Queue Desk',
                value: hospital.queueOpen ? 'Open Now' : 'Closed',
                subValue: 'OPD Hours',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? subValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: subTextColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textColor,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 2),
            Text(
              subValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: iconColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // HOSPITAL SECTION
  // ============================================================

  Widget _hospitalSection(
    BuildContext context,
    Hospital hospital,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Hospital Information',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: hospital.queueOpen ? const Color(0xFF4ADE80) : Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: hospital.queueOpen
                    ? const Color(0xFF4ADE80).withValues(alpha: 0.12)
                    : Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hospital.queueOpen
                      ? const Color(0xFF4ADE80).withValues(alpha: 0.3)
                      : Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                hospital.queueOpen ? 'OPD Active' : 'OPD Closed',
                style: TextStyle(
                  color: hospital.queueOpen ? const Color(0xFF4ADE80) : Colors.redAccent,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF162035),
                Color(0xFF101726),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [lightGold, gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: Color(0xFF17100A),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hospital.name,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hospital.type,
                          style: const TextStyle(
                            color: subTextColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Row(
                          children: [
                            Icon(Icons.star_rounded, color: gold, size: 15),
                            SizedBox(width: 3),
                            Text(
                              '4.9 (1.4k+ Reviews) • NABH Accredited',
                              style: TextStyle(
                                color: lightGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded, color: lightGold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hospital.address,
                      style: const TextStyle(color: subTextColor, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.access_time_filled_rounded, color: lightGold, size: 16),
                  SizedBox(width: 8),
                  Text(
                    '24/7 Casualty • OPD 08:00 AM – 08:00 PM',
                    style: TextStyle(color: subTextColor, fontSize: 12.5),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const Services_screen(businessId: businessId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.medical_services_rounded, size: 17),
                      label: const Text('Browse Services'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: const Color(0xFF17100A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showEmergencySheet(context),
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: const Text('Helpline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: lightGold,
                      side: BorderSide(color: gold.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _bottomNavigation({String uid = ''}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070D1B).withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              Expanded(
                child: _BottomItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: _selectedTabIndex == 0,
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = 0;
                    });
                  },
                ),
              ),
              Expanded(
                child: uid.isNotEmpty
                    ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _firestore
                            .collection('businesses')
                            .doc(businessId)
                            .collection('tokens')
                            .where('userId', isEqualTo: uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          int badgeCount = 0;
                          if (snapshot.hasData) {
                            badgeCount = snapshot.data!.docs.where((d) {
                              final s = (d.data()['status'] ?? '').toString().toLowerCase();
                              return s == 'waiting' || s == 'called' || s == 'serving';
                            }).length;
                          }
                          return _BottomItem(
                            icon: Icons.receipt_long_rounded,
                            label: 'My Tokens',
                            badgeCount: badgeCount,
                            selected: _selectedTabIndex == 1,
                            onTap: () {
                              setState(() {
                                _selectedTabIndex = 1;
                              });
                            },
                          );
                        },
                      )
                    : _BottomItem(
                        icon: Icons.receipt_long_rounded,
                        label: 'My Tokens',
                        selected: _selectedTabIndex == 1,
                        onTap: () {
                          setState(() {
                            _selectedTabIndex = 1;
                          });
                        },
                      ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: _selectedTabIndex == 2,
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = 2;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GLASS CARD
  // ============================================================

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double radius = 18,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 14,
          sigmaY: 14,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF17202F).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ================================================================
// BOTTOM NAVIGATION ITEM
// ================================================================

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback? onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.badgeCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFF5A623);
    const inactiveColor = Color(0xFFD7C3AE);

    final color = selected ? activeColor : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: activeColor.withValues(alpha: 0.10),
        highlightColor: activeColor.withValues(alpha: 0.05),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? activeColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: color,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        alignment: Alignment.center,
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Color(0xFF17100A),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// HOSPITAL MODEL
// ================================================================

class Hospital {
  final String name;
  final String type;
  final String address;
  final bool queueOpen;
  final int averageWait;
  final int activeTokens;

  Hospital({
    required this.name,
    required this.type,
    required this.address,
    required this.queueOpen,
    required this.averageWait,
    required this.activeTokens,
  });

  factory Hospital.fromMap(
    Map<String, dynamic> data,
  ) {
    return Hospital(
      name: data['name']?.toString() ?? 'Sunrise Care Hospital',
      type: data['type']?.toString() ?? 'Multi-speciality Hospital',
      address: data['address']?.toString() ?? 'Address unavailable',
      queueOpen: data['isQueueOpen'] == true || data['isOpen'] == true,
      averageWait: data['averageWait'] is num
          ? (data['averageWait'] as num).toInt()
          : 0,
      activeTokens: data['activeTokens'] is num
          ? (data['activeTokens'] as num).toInt()
          : 0,
    );
  }
}