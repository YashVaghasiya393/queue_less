import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Consultation',
    'Diagnostics',
    'Radiology',
    'Pharmacy',
    'Emergency',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Service',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Sunrise Care Hospital • Smart Queue',
              style: TextStyle(
                color: subTextColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1323).withValues(alpha: 0.6),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: textColor, fontSize: 14),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF131D30),
                    hintText: 'Search doctor, test, or service...',
                    hintStyle: TextStyle(
                      color: subTextColor.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: lightGold, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: subTextColor, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: gold, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Filter Chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final cat = _categories[i];
                      final isSel = _selectedCategory == cat;
                      return InkWell(
                        onTap: () => setState(() => _selectedCategory = cat),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSel ? gold : const Color(0xFF131D30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel ? gold : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSel ? const Color(0xFF17100A) : subTextColor,
                              fontSize: 11.5,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Services Stream List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

                final allDocs = snapshot.data!.docs;

                // Apply Search & Category Filters
                final services = allDocs.where((doc) {
                  final data = doc.data();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final desc = (data['description'] ?? '').toString().toLowerCase();
                  final cat = (data['category'] ?? '').toString().toLowerCase();

                  final matchesQuery = _searchQuery.isEmpty ||
                      name.contains(_searchQuery.toLowerCase()) ||
                      desc.contains(_searchQuery.toLowerCase());

                  bool matchesCat = true;
                  if (_selectedCategory != 'All') {
                    final target = _selectedCategory.toLowerCase();
                    matchesCat = name.contains(target) ||
                        desc.contains(target) ||
                        cat.contains(target);
                  }

                  return matchesQuery && matchesCat;
                }).toList();

                if (services.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 50, color: subTextColor.withValues(alpha: 0.5)),
                          const SizedBox(height: 14),
                          const Text(
                            'No matching services found',
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try searching with a different term or clear the filter.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subTextColor, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _selectedCategory = 'All';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: lightGold,
                              side: const BorderSide(color: gold),
                            ),
                            child: const Text('Reset Filter'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
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
          ),
        ],
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
                    serviceData: data,
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

  Map<String, dynamic> _getDefaultDoctorForService(String serviceName) {
    return {
      'id': '',
      'name': '',
      'designation': '',
      'room': '',
      'phone': '',
      'status': 'Unassigned',
      'isOnDuty': false,
    };
  }

  Map<String, dynamic> _getInitialDoctorForService(String serviceName, Map<String, dynamic> serviceData) {
    final directDoctorName = (serviceData['doctorName'] ?? serviceData['doctor'])?.toString().trim();
    if (directDoctorName != null && directDoctorName.isNotEmpty) {
      return {
        'id': serviceData['doctorId']?.toString() ?? 'svc_doc',
        'name': directDoctorName.startsWith('Dr.') ? directDoctorName : 'Dr. $directDoctorName',
        'designation': (serviceData['doctorDesignation'] ?? serviceData['doctorSpecialty'] ?? 'Consultant Specialist').toString(),
        'room': (serviceData['doctorRoom'] ?? serviceData['doctorCounter'] ?? serviceData['room'] ?? 'Chamber 1').toString(),
        'phone': serviceData['doctorPhone']?.toString() ?? '',
        'status': (serviceData['doctorStatus'] ?? 'On Duty').toString(),
        'isOnDuty': true,
      };
    }
    return _getDefaultDoctorForService(serviceName);
  }

  Future<List<Map<String, dynamic>>> _fetchDoctorsForService(String serviceName, Map<String, dynamic> serviceData) async {
    List<Map<String, dynamic>> doctors = [];

    // 1. If service has direct doctor, include it
    final directDoctorName = (serviceData['doctorName'] ?? serviceData['doctor'])?.toString().trim();
    if (directDoctorName != null && directDoctorName.isNotEmpty) {
      doctors.add({
        'id': serviceData['doctorId']?.toString() ?? 'svc_doc',
        'name': directDoctorName.startsWith('Dr.') ? directDoctorName : 'Dr. $directDoctorName',
        'designation': (serviceData['doctorDesignation'] ?? serviceData['doctorSpecialty'] ?? 'Consultant Specialist').toString(),
        'room': (serviceData['doctorRoom'] ?? serviceData['doctorCounter'] ?? serviceData['room'] ?? 'Chamber 1').toString(),
        'phone': serviceData['doctorPhone']?.toString() ?? '',
        'status': (serviceData['doctorStatus'] ?? 'On Duty').toString(),
        'isOnDuty': true,
      });
    }

    // 2. Fetch from hospital staff collection
    try {
      final staffSnap = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('staff')
          .get();

      for (var doc in staffSnap.docs) {
        final s = doc.data();
        final assignedSvc = (s['assignedService'] ?? '').toString();
        final role = (s['role'] ?? s['designation'] ?? '').toString().toLowerCase();
        final isDoc = role.contains('doctor') || role.contains('physician') || role.contains('consultant') || role.contains('surgeon') || role.contains('specialist');

        final matchesService = assignedSvc == 'All services' || assignedSvc.toLowerCase() == serviceName.toLowerCase();
        if (matchesService && isDoc) {
          final name = (s['name'] ?? '').toString().trim();
          if (name.isNotEmpty && !doctors.any((d) => d['name'].toString().toLowerCase() == name.toLowerCase())) {
            doctors.add({
              'id': doc.id,
              'name': name.startsWith('Dr.') ? name : 'Dr. $name',
              'designation': (s['designation'] ?? 'Consultant Doctor').toString(),
              'room': (s['assignedCounter'] ?? 'Chamber 1').toString(),
              'phone': (s['phone'] ?? '').toString(),
              'status': (s['status'] ?? 'On Duty').toString(),
              'isOnDuty': s['isOnDuty'] ?? true,
            });
          }
        }
      }
    } catch (_) {}

    // 3. Fallback default doctor if none found
    if (doctors.isEmpty) {
      doctors.add(_getDefaultDoctorForService(serviceName));
    }

    return doctors;
  }

  void _openBookingSheet(
    BuildContext context, {
    required String serviceId,
    required String serviceName,
    required String description,
    required int estimatedMinutes,
    required Map<String, dynamic> serviceData,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    String initialName = '';
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      initialName = user.displayName!.trim().replaceAll(RegExp(r"[^\p{L}\p{M}\s'-]", unicode: true), '');
    }
    final nameController = TextEditingController(text: initialName);
    String? nameError;

    // Fetch user profile name from Firestore if displayName is empty
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists) {
          final data = doc.data();
          final storedName = (data?['name'] ?? data?['fullName'] ?? data?['username'])?.toString().trim();
          if (storedName != null && storedName.isNotEmpty) {
            final sanitized = storedName.replaceAll(RegExp(r"[^\p{L}\p{M}\s'-]", unicode: true), '');
            if (sanitized.isNotEmpty && (nameController.text.isEmpty || nameController.text == initialName)) {
              nameController.text = sanitized;
            }
          }
        }
      }).catchError((_) {});
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

    Map<String, dynamic> selectedDoctor = _getInitialDoctorForService(serviceName, serviceData);
    List<Map<String, dynamic>> availableDoctors = [selectedDoctor];
    bool fetchedDoctors = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!fetchedDoctors) {
              fetchedDoctors = true;
              _fetchDoctorsForService(serviceName, serviceData).then((docs) {
                if (docs.isNotEmpty && bottomSheetContext.mounted) {
                  setSheetState(() {
                    availableDoctors = docs;
                    if (!docs.any((d) => d['name'] == selectedDoctor['name'])) {
                      selectedDoctor = docs.first;
                    }
                  });
                }
              }).catchError((_) {});
            }
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

                      const SizedBox(height: 14),

                      // Assigned Doctor Details Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17202F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: gold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.medical_information_rounded,
                                    color: lightGold,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ASSIGNED DOCTOR',
                                        style: TextStyle(
                                          color: gold,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      Text(
                                        (selectedDoctor['name'] ?? '').toString().trim().isNotEmpty
                                            ? selectedDoctor['name']
                                            : 'Unassigned',
                                        style: const TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4ADE80),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        (selectedDoctor['name'] ?? '').toString().trim().isNotEmpty
                                            ? (selectedDoctor['status'] ?? 'On Duty')
                                            : 'Unassigned',
                                        style: const TextStyle(
                                          color: Color(0xFF4ADE80),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.workspace_premium_rounded, size: 14, color: lightGold.withValues(alpha: 0.8)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    (selectedDoctor['name'] ?? '').toString().trim().isNotEmpty
                                        ? (selectedDoctor['designation'] ?? 'Specialist')
                                        : 'Consultation by available staff',
                                    style: const TextStyle(color: subTextColor, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.meeting_room_rounded, size: 14, color: lightGold.withValues(alpha: 0.8)),
                                const SizedBox(width: 6),
                                Text(
                                  (selectedDoctor['name'] ?? '').toString().trim().isNotEmpty
                                      ? (selectedDoctor['room'] ?? '')
                                      : 'To be assigned',
                                  style: const TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            if (availableDoctors.length > 1 && availableDoctors.any((d) => (d['name'] ?? '').toString().trim().isNotEmpty)) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Select Preferred Doctor:',
                                style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: availableDoctors.map((doc) {
                                    final isSel = selectedDoctor['name'] == doc['name'];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: InkWell(
                                        onTap: () => setSheetState(() => selectedDoctor = doc),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSel ? gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSel ? gold : Colors.white.withValues(alpha: 0.1),
                                            ),
                                          ),
                                          child: Text(
                                            doc['name'] ?? '',
                                            style: TextStyle(
                                              color: isSel ? gold : textColor,
                                              fontSize: 12,
                                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
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
                        style: const TextStyle(color: textColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF17202F),
                          hintText: 'Enter patient full name',
                          hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                          prefixIcon: const Icon(Icons.person_outline, color: lightGold),
                          helperText: 'Letters and spaces only (no numbers or special characters)',
                          helperStyle: TextStyle(color: subTextColor.withOpacity(0.6), fontSize: 11),
                          errorText: nameError,
                          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: nameError != null ? Colors.redAccent : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: nameError != null ? Colors.redAccent : gold,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.redAccent),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
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
                                    setSheetState(() => nameError = 'Please enter patient name.');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter patient name.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }

                                  if (patientName.length < 2) {
                                    setSheetState(() => nameError = 'Patient name must be at least 2 characters.');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Patient name must be at least 2 characters long.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }

                                  final validNameRegex = RegExp(r"^[\p{L}\p{M}\s'-]+$", unicode: true);
                                  if (!validNameRegex.hasMatch(patientName)) {
                                    setSheetState(() => nameError = 'Only letters, spaces, apostrophes and hyphens are allowed.');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Patient name can only contain letters, spaces, apostrophes, and hyphens.'),
                                        backgroundColor: Colors.redAccent,
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
                                    doctorDetails: selectedDoctor,
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
    required Map<String, dynamic> doctorDetails,
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
          'customerName': patientName,
          'doctorId': doctorDetails['id'] ?? '',
          'doctorName': doctorDetails['name'] ?? '',
          'doctorDesignation': doctorDetails['designation'] ?? '',
          'doctorRoom': doctorDetails['room'] ?? '',
          'doctorPhone': doctorDetails['phone'] ?? '',
          'doctorStatus': doctorDetails['status'] ?? 'On Duty',
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
        patientName: patientName,
        estimatedMinutes: estimatedMinutes,
        timeSlot: timeSlot,
        bookingType: bookingType,
        doctorDetails: doctorDetails,
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
    required String patientName,
    required int estimatedMinutes,
    required String timeSlot,
    required String bookingType,
    required Map<String, dynamic> doctorDetails,
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
                        const SizedBox(height: 8),

                        // Patient Name Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gold.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person, color: lightGold, size: 16),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Patient: $patientName',
                                  style: const TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        if ((doctorDetails['name'] ?? '').toString().trim().isNotEmpty) ...[
                          const SizedBox(height: 8),

                          // Assigned Doctor Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: gold.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.medical_information_rounded, color: lightGold, size: 16),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    (doctorDetails['room'] ?? '').toString().trim().isNotEmpty
                                        ? 'Doctor: ${doctorDetails['name']} (${doctorDetails['room']})'
                                        : 'Doctor: ${doctorDetails['name']}',
                                    style: const TextStyle(
                                      color: lightGold,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

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
