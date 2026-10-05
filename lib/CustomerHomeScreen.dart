import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData = userSnapshot.data!.data();

              if (userData != null) {
                userName = userData['name'] ??
                    userData['fullName'] ??
                    userData['username'] ??
                    'User';
                profileImage = userData['profileImage']?.toString() ??
                    userData['photoUrl']?.toString();
              }
            }

            return _buildHome(
              context,
              hospital,
              userName,
              profileImage: profileImage,
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
  }) {
    final currentUser = _auth.currentUser;
    final currentUid = currentUser?.uid ?? '';
    final userEmail = currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF060810),
      bottomNavigationBar: _bottomNavigation(),
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
                    ? _homeDashboardTab(context, hospital, userName)
                    : _selectedTabIndex == 1
                        ? _myTokensTab(context, currentUid)
                        : _profileTab(
                            context,
                            userName,
                            userEmail,
                            profileImage: profileImage,
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
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _welcomeHeader(userName),
          const SizedBox(height: 22),
          _joinQueueCard(context),
          const SizedBox(height: 18),
          _quickStats(hospital),
          const SizedBox(height: 26),
          _hospitalSection(context, hospital),
        ],
      ),
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

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: gold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Active Tokens',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You have not booked any service tokens yet. Browse available hospital services to join the queue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 14,
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
                    icon: const Icon(Icons.medical_services_outlined),
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
          );
        }

        // Sort in memory by joinedAt descending
        docs.sort((a, b) {
          final aTime = a.data()['joinedAt'] as Timestamp?;
          final bTime = b.data()['joinedAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final tokenId = doc.id;
            return _tokenCard(context, tokenId: tokenId, token: data);
          },
        );
      },
    );
  }

  Widget _tokenCard(
    BuildContext context, {
    required String tokenId,
    required Map<String, dynamic> token,
  }) {
    final tokenNumber = token['tokenNumber']?.toString() ?? 'A-000';
    final serviceName = token['serviceName']?.toString() ?? 'Hospital Service';
    final status = token['status']?.toString().toLowerCase() ?? 'waiting';
    final hospitalName = token['hospitalName']?.toString() ?? 'Sunrise Care Hospital';
    final estimatedMinutes = token['estimatedMinutes'] ?? 15;

    Color badgeColor;
    String badgeText;
    bool isCalling = false;

    if (status == 'called' || status == 'serving') {
      badgeColor = const Color(0xFF9BD9FF);
      badgeText = 'NOW CALLING - GO TO COUNTER';
      isCalling = true;
    } else if (status == 'waiting') {
      badgeColor = gold;
      badgeText = 'WAITING IN QUEUE';
    } else if (status == 'completed') {
      badgeColor = const Color(0xFF4ADE80);
      badgeText = 'COMPLETED';
    } else {
      badgeColor = Colors.grey;
      badgeText = status.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF17202F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCalling ? const Color(0xFF9BD9FF) : Colors.white.withOpacity(0.08),
          width: isCalling ? 1.5 : 1,
        ),
        boxShadow: isCalling
            ? [
                BoxShadow(
                  color: const Color(0xFF9BD9FF).withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
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
                    color: badgeColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withOpacity(0.3)),
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
                    gradient: const LinearGradient(
                      colors: [lightGold, gold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    tokenNumber,
                    style: const TextStyle(
                      color: Color(0xFF17100A),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
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
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hospitalName,
                        style: const TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            token['timeSlot'] != null && token['timeSlot'] != 'Live Queue'
                                ? Icons.schedule_rounded
                                : Icons.bolt_rounded,
                            color: lightGold,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            token['timeSlot'] != null && token['timeSlot'] != 'Live Queue'
                                ? 'Slot: ${token['timeSlot']}'
                                : 'Est. wait: ~$estimatedMinutes mins',
                            style: const TextStyle(
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
            Divider(color: Colors.white.withOpacity(0.08), height: 1),
            const SizedBox(height: 14),

            // Action Buttons
            Row(
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
                        timeSlot: token['timeSlot']?.toString(),
                      );
                    },
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Digital Pass'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: lightGold,
                      side: const BorderSide(color: gold),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (status == 'waiting') ...[
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () => _confirmCancelToken(context, tokenId),
                    icon: const Icon(Icons.cancel_outlined, size: 17),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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
    String? timeSlot,
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
        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('tokens')
            .doc(tokenId)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .update({
          'activeTokens': FieldValue.increment(-1),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token cancelled successfully.')),
          );
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

  Widget _profileTab(
    BuildContext context,
    String userName,
    String email, {
    String? profileImage,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [gold, lightGold, Color(0xFFC97C10)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gold.withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _buildAvatar(profileImage, radius: 52, iconSize: 58),
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
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            color: gold,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isUploadingProfilePic
                          ? null
                          : () => _showPhotoPickerSheet(context, profileImage),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF060810), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: Color(0xFF17100A),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _isUploadingProfilePic
                ? null
                : () => _showPhotoPickerSheet(context, profileImage),
            icon: const Icon(Icons.edit_rounded, size: 15, color: lightGold),
            label: Text(
              profileImage != null && profileImage.isNotEmpty
                  ? 'Change Photo'
                  : 'Add Profile Photo',
              style: const TextStyle(
                color: lightGold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              backgroundColor: gold.withOpacity(0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            style: const TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email.isNotEmpty ? email : 'Signed in Patient',
            style: const TextStyle(
              color: subTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          _glassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _profileOption(
                  icon: Icons.local_hospital_outlined,
                  title: 'Default Hospital',
                  subtitle: 'Sunrise Care Hospital',
                ),
                Divider(color: Colors.white.withOpacity(0.08)),
                _profileOption(
                  icon: Icons.confirmation_number_outlined,
                  title: 'My Tokens',
                  subtitle: 'View queue history',
                  onTap: () => setState(() => _selectedTabIndex = 1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await _auth.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              label: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: gold, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: subTextColor,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: subTextColor,
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
    String title = 'Home';
    if (_selectedTabIndex == 1) title = 'My Tokens';
    if (_selectedTabIndex == 2) title = 'Profile';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1323).withOpacity(0.45),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: gold.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.hourglass_empty_rounded,
              color: gold,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: subTextColor,
            ),
          ),
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
                border: Border.all(color: gold.withOpacity(0.6), width: 1.5),
              ),
              child: _buildAvatar(profileImage, radius: 16, iconSize: 18),
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
        Text(
          '$greeting, $userName',
          style: const TextStyle(
            color: textColor,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Skip the queue at your hospital.',
          style: TextStyle(
            color: subTextColor,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // JOIN QUEUE CARD
  // ============================================================

  Widget _joinQueueCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF5A623),
            Color(0xFFFFC880),
            Color(0xFFF9BC57),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            bottom: -32,
            child: Icon(
              Icons.qr_code_2_rounded,
              size: 150,
              color: const Color(0xFF452B00).withOpacity(0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF452B00).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFF452B00),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'INSTANT ACCESS',
                      style: TextStyle(
                        color: Color(0xFF452B00),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Join a queue',
                style: TextStyle(
                  color: Color(0xFF452B00),
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const SizedBox(
                width: 240,
                child: Text(
                  'Scan hospital QR code to get your token instantly.',
                  style: TextStyle(
                    color: Color(0xFF452B00),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QRScannerScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan QR Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF060E1D),
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK STATS
  // ============================================================

  Widget _quickStats(Hospital hospital) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.timer_outlined,
            iconColor: gold,
            title: 'Average Wait',
            value: '${hospital.averageWait} mins',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.verified_outlined,
            iconColor: const Color(0xFF9BD9FF),
            title: 'Active Tokens',
            value: '${hospital.activeTokens} active',
          ),
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
  }) {
    return _glassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: subTextColor,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
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
              'Your Hospital',
              style: TextStyle(
                color: textColor,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: hospital.queueOpen
                    ? const Color(0xFF4ADE80)
                    : Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: hospital.queueOpen
                    ? const Color(0xFF4ADE80).withOpacity(0.12)
                    : Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 3,
                    backgroundColor: hospital.queueOpen
                        ? const Color(0xFF4ADE80)
                        : Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hospital.queueOpen ? 'Queue Open' : 'Queue Closed',
                    style: TextStyle(
                      color: hospital.queueOpen
                          ? const Color(0xFF4ADE80)
                          : Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _glassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: lightGold,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hospital.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hospital.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: subTextColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: lightGold,
                              size: 16,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                hospital.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              const Text(
                'Choose a service and take your token.',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: hospital.queueOpen
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Services_screen(
                                businessId: businessId,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: const Color(0xFF452B00),
                    disabledBackgroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Services',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                      ),
                    ],
                  ),
                ),
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

  Widget _bottomNavigation() {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFF060E1D).withOpacity(0.97),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: _selectedTabIndex == 0,
              onTap: () {
                setState(() {
                  _selectedTabIndex = 0;
                });
              },
            ),
            _BottomItem(
              icon: Icons.receipt_long_rounded,
              label: 'My Tokens',
              selected: _selectedTabIndex == 1,
              onTap: () {
                setState(() {
                  _selectedTabIndex = 1;
                });
              },
            ),
            _BottomItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              selected: _selectedTabIndex == 2,
              onTap: () {
                setState(() {
                  _selectedTabIndex = 2;
                });
              },
            ),
          ],
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
            color: const Color(0xFF17202F).withOpacity(0.72),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
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
  final VoidCallback? onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    this.selected = false,
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
        splashColor: activeColor.withOpacity(0.10),
        highlightColor: activeColor.withOpacity(0.05),
        child: SizedBox(
          width: 90,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 23,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
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