import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Services_screen extends StatefulWidget {
  final String businessId;
  const Services_screen({super.key, required this.businessId});

  @override
  State<Services_screen> createState() => _Services_screenState();
}

class _Services_screenState extends State<Services_screen> {
  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  bool _isBooking = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1323),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: textColor,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Select Service',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('businesses')
            .doc(widget.businessId)
            .collection('services')
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
                'Unable to load services.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No services available right now.',
                style: TextStyle(color: subTextColor, fontSize: 16),
              ),
            );
          }

          final services = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final document = services[index];
              final data = document.data();

              return _serviceCard(
                context,
                serviceId: document.id,
                data: data,
              );
            },
          );
        },
      ),
    );
  }

  Widget _serviceCard(
    BuildContext context, {
    required String serviceId,
    required Map<String, dynamic> data,
  }) {
    final serviceName = data['name']?.toString() ?? 'Unnamed Service';
    final description = data['description']?.toString() ?? 'No description available';
    final isAvailable = (data['isActive'] ?? data['isAvailable'] ?? true) as bool;
    final estimatedMinutes = (data['estimatedMinutes'] is num)
        ? (data['estimatedMinutes'] as num).toInt()
        : 15;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF17202F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isAvailable
              ? () => _openBookingSheet(
                    context,
                    serviceId: serviceId,
                    serviceName: serviceName,
                    description: description,
                    estimatedMinutes: estimatedMinutes,
                  )
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This service is currently unavailable.'),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: gold.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: lightGold,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? const Color(0xFF4ADE80).withOpacity(0.12)
                                  : Colors.redAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAvailable ? 'Available' : 'Unavailable',
                              style: TextStyle(
                                color: isAvailable
                                    ? const Color(0xFF4ADE80)
                                    : Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.schedule,
                            color: subTextColor.withOpacity(0.7),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '~$estimatedMinutes mins',
                            style: const TextStyle(
                              color: subTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Book Action Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAvailable ? gold : Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Book',
                    style: TextStyle(
                      color: isAvailable ? const Color(0xFF17100A) : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openBookingSheet(
    BuildContext context, {
    required String serviceId,
    required String serviceName,
    required String description,
    required int estimatedMinutes,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    final nameController = TextEditingController(
      text: user?.displayName ?? 'Patient',
    );

    // Fetch user profile name from Firestore if displayName is empty
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists) {
          final data = doc.data();
          final storedName = data?['name'] ?? data?['fullName'] ?? data?['username'];
          if (storedName != null && storedName.toString().isNotEmpty) {
            nameController.text = storedName.toString();
          }
        }
      });
    }

    bool isLiveQueue = true;
    String selectedSlot = '10:30 AM';
    final List<String> availableSlots = [
      '09:30 AM',
      '10:00 AM',
      '10:30 AM',
      '11:00 AM',
      '11:30 AM',
      '12:00 PM',
      '02:00 PM',
      '02:30 PM',
      '03:00 PM',
      '03:30 PM',
      '04:00 PM',
      '04:30 PM',
      '05:00 PM',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.88,
                ),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF101726),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle Bar
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

                      // Title & Subtitle
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Book Service Token',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Choose live walk-in or pick a preferred time',
                                  style: const TextStyle(
                                    color: subTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: gold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: gold,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '~$estimatedMinutes min',
                                  style: const TextStyle(
                                    color: gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Service Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17202F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: gold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.medical_services_outlined,
                                color: gold,
                                size: 24,
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: subTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Booking Mode Segment Switch
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17202F),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setSheetState(() => isLiveQueue = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isLiveQueue ? gold : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 17,
                                        color: isLiveQueue ? const Color(0xFF17100A) : subTextColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Live Walk-in',
                                        style: TextStyle(
                                          color: isLiveQueue ? const Color(0xFF17100A) : subTextColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setSheetState(() => isLiveQueue = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !isLiveQueue ? gold : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 16,
                                        color: !isLiveQueue ? const Color(0xFF17100A) : subTextColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Pick Time Slot',
                                        style: TextStyle(
                                          color: !isLiveQueue ? const Color(0xFF17100A) : subTextColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
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

                      const SizedBox(height: 18),

                      // If Time Slot Selected: Show Slot Chips
                      if (!isLiveQueue) ...[
                        Row(
                          children: [
                            const Text(
                              'Available Slots Today',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Selected: $selectedSlot',
                              style: const TextStyle(
                                color: lightGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableSlots.map((slot) {
                            final isSelected = selectedSlot == slot;
                            return InkWell(
                              onTap: () => setSheetState(() => selectedSlot = slot),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? gold : const Color(0xFF17202F),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? gold : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Text(
                                  slot,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF17100A) : textColor,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: gold.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gold.withOpacity(0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: lightGold, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'You will receive the next available token. Your turn is called based on live queue order.',
                                  style: TextStyle(color: lightGold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Patient Name Input
                      const Text(
                        'Patient Name',
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: textColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF17202F),
                          hintText: 'Enter patient name',
                          hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                          prefixIcon: const Icon(Icons.person_outline, color: lightGold),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: gold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Book Token Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isBooking
                              ? null
                              : () async {
                                  final patientName = nameController.text.trim();
                                  if (patientName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter patient name.'),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() => _isBooking = true);
                                  setState(() => _isBooking = true);

                                  Navigator.pop(bottomSheetContext);

                                  await _bookToken(
                                    serviceId: serviceId,
                                    serviceName: serviceName,
                                    patientName: patientName,
                                    estimatedMinutes: estimatedMinutes,
                                    timeSlot: isLiveQueue ? 'Live Queue' : selectedSlot,
                                    bookingType: isLiveQueue ? 'Live Walk-in' : 'Scheduled Slot',
                                  );

                                  if (mounted) {
                                    setState(() => _isBooking = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: const Color(0xFF17100A),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isBooking
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF17100A),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isLiveQueue
                                      ? 'Get Instant Token'
                                      : 'Book Slot ($selectedSlot)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
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

  Future<void> _bookToken({
    required String serviceId,
    required String serviceName,
    required String patientName,
    required int estimatedMinutes,
    required String timeSlot,
    required String bookingType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to book a token.'),
        ),
      );
      return;
    }

    try {
      final businessRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId);

      final tokenRef = businessRef.collection('tokens').doc();
      String generatedTokenNumber = 'A-001';
      String hospitalName = 'Sunrise Care Hospital';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final businessSnapshot = await transaction.get(businessRef);

        if (!businessSnapshot.exists) {
          throw Exception('Hospital business not found');
        }

        final bData = businessSnapshot.data() ?? {};
        hospitalName = bData['name']?.toString() ?? 'Sunrise Care Hospital';

        final bool isQueueOpen = bData['isQueueOpen'] ?? bData['isOpen'] ?? false;
        if (!isQueueOpen) {
          throw Exception('The hospital queue is currently closed.');
        }

        int currentCount = (bData['tokenCount'] as num?)?.toInt() ?? 0;
        int nextCount = currentCount + 1;
        generatedTokenNumber = 'A-${nextCount.toString().padLeft(3, '0')}';

        // Update business token counter and active tokens
        transaction.update(businessRef, {
          'tokenCount': nextCount,
          'activeTokens': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Set token document in businesses/{id}/tokens
        transaction.set(tokenRef, {
          'tokenId': tokenRef.id,
          'tokenNumber': generatedTokenNumber,
          'serviceId': serviceId,
          'serviceName': serviceName,
          'businessId': widget.businessId,
          'hospitalName': hospitalName,
          'userId': user.uid,
          'userName': patientName,
          'status': 'waiting',
          'timeSlot': timeSlot,
          'bookingType': bookingType,
          'joinedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'estimatedMinutes': estimatedMinutes,
        });
      });

      if (!mounted) return;

      // Show Token Slip Confirmation Dialog
      _showTokenSlipDialog(
        context,
        tokenId: tokenRef.id,
        tokenNumber: generatedTokenNumber,
        serviceName: serviceName,
        hospitalName: hospitalName,
        estimatedMinutes: estimatedMinutes,
        timeSlot: timeSlot,
        bookingType: bookingType,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showTokenSlipDialog(
    BuildContext context, {
    required String tokenId,
    required String tokenNumber,
    required String serviceName,
    required String hospitalName,
    required int estimatedMinutes,
    required String timeSlot,
    required String bookingType,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: const Color(0xFF101726),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: gold.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Header
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF4ADE80),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Token Booked!',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hospitalName,
                    style: const TextStyle(
                      color: subTextColor,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Digital Pass Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          gold.withOpacity(0.2),
                          const Color(0xFF17202F),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: gold.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tokenNumber,
                          style: const TextStyle(
                            color: gold,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          serviceName,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimated wait: ~$estimatedMinutes mins',
                          style: const TextStyle(
                            color: subTextColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // QR Code
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: QrImageView(
                            data: 'queueless://token?id=$tokenId&number=$tokenNumber',
                            version: QrVersions.auto,
                            size: 110,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); // Close dialog
                        Navigator.pop(context); // Return to customer home
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: const Color(0xFF17100A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'View in My Tokens',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
}
