import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'BusinessAdmin/AdminDataHelper.dart';

class QueueManagementScreen extends StatefulWidget {
  const QueueManagementScreen({super.key});

  @override
  State<QueueManagementScreen> createState() => _QueueManagementScreenState();
}

class _QueueManagementScreenState extends State<QueueManagementScreen> {
  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  String? businessId;
  bool isSaving = false;
  String _selectedFilter = 'Active';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initBusiness();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initBusiness() async {
    await AdminDataHelper.ensureAdminAuth();
    final id = await AdminDataHelper.getBusinessId();
    if (mounted) {
      setState(() {
        businessId = id;
      });
    }
  }

  Future<void> _toggleQueueStatus(bool currentStatus) async {
    if (businessId == null || isSaving) return;

    final newStatus = !currentStatus;

    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .set({
        'isQueueOpen': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'Queue opened successfully.' : 'Queue closed successfully.',
          ),
          backgroundColor: newStatus ? const Color(0xFF4ADE80) : const Color(0xFFFF7B7B),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update queue status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _updateTokenStatus(String tokenId, String newStatus, {String? counter}) async {
    if (businessId == null) return;

    try {
      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'called' || newStatus == 'serving') {
        updateData['calledAt'] = FieldValue.serverTimestamp();
        updateData['counter'] = counter ?? 'Counter 1';
      } else if (newStatus == 'completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'skipped') {
        updateData['skippedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'cancelled') {
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('tokens')
          .doc(tokenId)
          .update(updateData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Token marked as ${newStatus.toUpperCase()}.'),
          backgroundColor: const Color(0xFF2D3546),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating token: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _callNextPatient(List<Map<String, dynamic>> waitingTokens) async {
    if (businessId == null) return;
    if (waitingTokens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No waiting patients in queue.'),
          backgroundColor: Color(0xFF2D3546),
        ),
      );
      return;
    }

    final nextToken = waitingTokens.first;
    final tokenId = nextToken['id'] as String;
    final tokenNumber = nextToken['tokenNumber']?.toString() ?? 'Next';

    await _updateTokenStatus(tokenId, 'called');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now calling Token $tokenNumber to Counter 1! 📢'),
        backgroundColor: gold,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _skipTokenWithConfirmation(Map<String, dynamic> token) async {
    final tokenId = token['id'] as String;
    final tokenNumber = token['tokenNumber']?.toString() ?? 'Token';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Skip Token', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to skip Token $tokenNumber? It can be re-queued later if needed.',
          style: const TextStyle(color: subTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: subTextColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7B7B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Skip Token'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateTokenStatus(tokenId, 'skipped');
    }
  }

  static Map<String, dynamic> _resolveDoctorForService(
      String serviceName, Map<String, dynamic> serviceData) {
    final customName = (serviceData['doctorName'] ?? '').toString().trim();
    if (customName.isNotEmpty) {
      return {
        'doctorId': (serviceData['doctorId'] ?? '').toString(),
        'doctorName': customName,
        'doctorDesignation':
            (serviceData['doctorDesignation'] ?? '').toString(),
        'doctorRoom': (serviceData['doctorRoom'] ?? '').toString(),
        'doctorPhone': (serviceData['doctorPhone'] ?? '').toString(),
        'doctorStatus': (serviceData['doctorStatus'] ?? 'On Duty').toString(),
      };
    }
    return {};
  }

  Future<void> _showAddWalkinDialog(String hospitalName) async {
    if (businessId == null) return;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String? nameError;
    String? selectedServiceId;
    String? selectedServiceName;
    Map<String, dynamic> assignedDoctor = {};
    int estimatedMinutes = 15;
    bool isGenerating = false;

    // Fetch active services
    final servicesSnap = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('services')
        .get();

    final serviceDocs = servicesSnap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).where((s) => s['isActive'] != false).toList();

    if (serviceDocs.isNotEmpty) {
      final firstService = serviceDocs.first;
      selectedServiceId = firstService['id']?.toString();
      selectedServiceName = firstService['name']?.toString() ?? 'General Consultation';
      estimatedMinutes = (firstService['avgWaitMinutes'] as num?)?.toInt() ?? 15;
      assignedDoctor = _resolveDoctorForService(selectedServiceName!, firstService);
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E2638),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1, color: lightGold),
                SizedBox(width: 10),
                Text('Add Walk-in Patient', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Patient Name', style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{M}\s'-]", unicode: true)),
                    ],
                    onChanged: (val) {
                      if (nameError != null) {
                        setDialogState(() => nameError = null);
                      }
                    },
                    style: const TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Enter patient full name (letters only)',
                      hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                      helperText: 'Letters and spaces only (no numbers or special characters)',
                      helperStyle: TextStyle(color: subTextColor.withOpacity(0.6), fontSize: 11),
                      errorText: nameError,
                      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF2D3546),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent)),
                      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Phone Number (Optional)', style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'e.g. +91 98765 43210',
                      hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                      filled: true,
                      fillColor: const Color(0xFF2D3546),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Select Service', style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (serviceDocs.isEmpty)
                    const Text('No active services available.', style: TextStyle(color: Colors.redAccent, fontSize: 13))
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3546),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedServiceId,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2D3546),
                          style: const TextStyle(color: textColor),
                          items: serviceDocs.map((s) {
                            final sId = s['id']?.toString() ?? '';
                            final sName = s['name']?.toString() ?? 'Service';
                            return DropdownMenuItem<String>(
                              value: sId,
                              child: Text(sName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            final matched = serviceDocs.firstWhere((s) => s['id'] == val, orElse: () => {});
                            setDialogState(() {
                              selectedServiceId = val;
                              selectedServiceName = matched['name']?.toString() ?? 'Service';
                              estimatedMinutes = (matched['avgWaitMinutes'] as num?)?.toInt() ?? 15;
                              assignedDoctor = _resolveDoctorForService(selectedServiceName!, matched);
                            });
                          },
                        ),
                      ),
                    ),
                  if (assignedDoctor.isNotEmpty && (assignedDoctor['doctorName'] ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('Assigned Doctor', style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: gold.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFF2D3546),
                            child: Icon(Icons.person, color: lightGold, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assignedDoctor['doctorName'] ?? '',
                                  style: const TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${assignedDoctor['doctorDesignation'] ?? ''} • ${assignedDoctor['doctorRoom'] ?? ''}',
                                  style: const TextStyle(
                                    color: subTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ADE80).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              assignedDoctor['doctorStatus'] ?? 'On Duty',
                              style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isGenerating ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: subTextColor)),
              ),
              ElevatedButton(
                onPressed: isGenerating || selectedServiceId == null
                    ? null
                    : () async {
                        final rawName = nameController.text.trim();
                        if (rawName.isEmpty) {
                          setDialogState(() => nameError = 'Please enter patient name.');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter patient name.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        if (rawName.length < 2) {
                          setDialogState(() => nameError = 'Name must be at least 2 characters.');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Patient name must be at least 2 characters long.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        final validNameRegex = RegExp(r"^[\p{L}\p{M}\s'-]+$", unicode: true);
                        if (!validNameRegex.hasMatch(rawName)) {
                          setDialogState(() => nameError = 'Only letters, spaces, apostrophes and hyphens allowed.');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Patient name can only contain letters, spaces, apostrophes, and hyphens.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        final pName = rawName;
                        final pPhone = phoneController.text.trim();

                        setDialogState(() {
                          isGenerating = true;
                        });

                        try {
                          final businessRef = FirebaseFirestore.instance.collection('businesses').doc(businessId);
                          final tokenRef = businessRef.collection('tokens').doc();
                          String generatedTokenNumber = 'A-001';

                          await FirebaseFirestore.instance.runTransaction((transaction) async {
                            final bSnap = await transaction.get(businessRef);
                            if (!bSnap.exists) throw Exception('Hospital record not found');
                            final bData = bSnap.data() ?? {};
                            int currentCount = (bData['tokenCount'] as num?)?.toInt() ?? 0;
                            int nextCount = currentCount + 1;
                            generatedTokenNumber = 'A-${nextCount.toString().padLeft(3, '0')}';

                            transaction.update(businessRef, {
                              'tokenCount': nextCount,
                              'activeTokens': FieldValue.increment(1),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin_walkin';

                            transaction.set(tokenRef, {
                              'tokenId': tokenRef.id,
                              'tokenNumber': generatedTokenNumber,
                              'serviceId': selectedServiceId,
                              'serviceName': selectedServiceName,
                              'businessId': businessId,
                              'hospitalName': hospitalName,
                              'userId': uid,
                              'userName': pName,
                              'customerName': pName,
                              'phoneNumber': pPhone,
                              'status': 'waiting',
                              'bookingType': 'Walk-in',
                              'doctorId': assignedDoctor['doctorId'] ?? '',
                              'doctorName': assignedDoctor['doctorName'] ?? '',
                              'doctorDesignation': assignedDoctor['doctorDesignation'] ?? '',
                              'doctorRoom': assignedDoctor['doctorRoom'] ?? '',
                              'doctorPhone': assignedDoctor['doctorPhone'] ?? '',
                              'doctorStatus': (assignedDoctor['doctorName'] ?? '').toString().isNotEmpty ? (assignedDoctor['doctorStatus'] ?? 'On Duty') : '',
                              'joinedAt': FieldValue.serverTimestamp(),
                              'createdAt': FieldValue.serverTimestamp(),
                              'estimatedMinutes': estimatedMinutes,
                            });
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Walk-in Token $generatedTokenNumber created for $pName!'),
                              backgroundColor: const Color(0xFF4ADE80),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() {
                            isGenerating = false;
                          });
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to generate token: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: const Color(0xFF1A1208),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isGenerating ? 'Generating...' : 'Issue Token'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1050;

    if (businessId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: gold),
        ),
      );
    }

    // Real-time stream of hospital document for live queue status & hospital name
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('businesses').doc(businessId).snapshots(),
      builder: (context, hospitalSnap) {
        final hospitalData = hospitalSnap.data?.data() ?? {};
        final hospitalName = hospitalData['name']?.toString() ?? 'Sunrise Care Hospital';
        final isQueueOpen = hospitalData['isQueueOpen'] == true;

        // Real-time stream of tokens
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .collection('tokens')
              .snapshots(),
          builder: (context, tokensSnap) {
            final allTokenDocs = (tokensSnap.data?.docs ?? []).map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList();

            // Sort by joinedAt ascending for queue sequence
            allTokenDocs.sort((a, b) {
              final tA = a['joinedAt'];
              final tB = b['joinedAt'];
              if (tA is Timestamp && tB is Timestamp) {
                return tA.compareTo(tB);
              }
              return 0;
            });

            final waitingTokens = allTokenDocs.where((t) {
              final st = (t['status'] ?? 'waiting').toString().toLowerCase();
              return st == 'waiting';
            }).toList();

            final calledTokens = allTokenDocs.where((t) {
              final st = (t['status'] ?? '').toString().toLowerCase();
              return st == 'called' || st == 'serving';
            }).toList();

            final completedTokens = allTokenDocs.where((t) {
              final st = (t['status'] ?? '').toString().toLowerCase();
              return st == 'completed';
            }).toList();

            final skippedTokens = allTokenDocs.where((t) {
              final st = (t['status'] ?? '').toString().toLowerCase();
              return st == 'skipped';
            }).toList();

            final currentPatient = calledTokens.isNotEmpty ? calledTokens.first : null;
            final upNextPatient = waitingTokens.isNotEmpty ? waitingTokens.first : null;

            final avgWaitMinutes = waitingTokens.isEmpty ? 0 : (waitingTokens.length * 8);

            // Filter tokens for live table
            List<Map<String, dynamic>> displayTokens;
            if (_selectedFilter == 'Waiting') {
              displayTokens = waitingTokens;
            } else if (_selectedFilter == 'Called') {
              displayTokens = calledTokens;
            } else if (_selectedFilter == 'Completed') {
              displayTokens = completedTokens;
            } else if (_selectedFilter == 'Skipped') {
              displayTokens = skippedTokens;
            } else if (_selectedFilter == 'All') {
              displayTokens = allTokenDocs;
            } else {
              // 'Active': called + waiting
              displayTokens = [...calledTokens, ...waitingTokens];
            }

            // Apply search query
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              displayTokens = displayTokens.where((t) {
                final tNum = (t['tokenNumber'] ?? '').toString().toLowerCase();
                final sName = (t['serviceName'] ?? '').toString().toLowerCase();
                final pName = (t['userName'] ?? t['customerName'] ?? '').toString().toLowerCase();
                return tNum.contains(q) || sName.contains(q) || pName.contains(q);
              }).toList();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(isWide, hospitalName, isQueueOpen),
                  const SizedBox(height: 28),
                  _summaryCards(
                    waitingCount: waitingTokens.length,
                    currentTokenNumber: currentPatient != null ? (currentPatient['tokenNumber']?.toString() ?? '-') : (waitingTokens.isNotEmpty ? '-' : 'None'),
                    servedCount: completedTokens.length,
                    avgWaitTime: '$avgWaitMinutes min',
                  ),
                  const SizedBox(height: 28),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _liveQueue(
                            tokens: displayTokens,
                            activeCount: calledTokens.length + waitingTokens.length,
                            waitingCount: waitingTokens.length,
                            calledCount: calledTokens.length,
                            completedCount: completedTokens.length,
                            allCount: allTokenDocs.length,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _rightCards(
                            currentPatient: currentPatient,
                            upNextPatient: upNextPatient,
                            waitingTokens: waitingTokens,
                            hospitalName: hospitalName,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _liveQueue(
                          tokens: displayTokens,
                          activeCount: calledTokens.length + waitingTokens.length,
                          waitingCount: waitingTokens.length,
                          calledCount: calledTokens.length,
                          completedCount: completedTokens.length,
                          allCount: allTokenDocs.length,
                        ),
                        const SizedBox(height: 24),
                        _rightCards(
                          currentPatient: currentPatient,
                          upNextPatient: upNextPatient,
                          waitingTokens: waitingTokens,
                          hospitalName: hospitalName,
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _header(bool isWide, String hospitalName, bool isQueueOpen) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Dashboard',
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.chevron_right,
                color: subTextColor,
                size: 17,
              ),
            ),
            Text(
              'Queue Management',
              style: TextStyle(color: lightGold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Queue Management',
          style: TextStyle(
            color: textColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Monitor and manage the live patient queue for $hospitalName.',
          style: const TextStyle(color: subTextColor, fontSize: 14),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: (isQueueOpen
                ? const Color(0xFF4ADE80)
                : const Color(0xFFFF7B7B))
                .withOpacity(0.12),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: (isQueueOpen
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFFFF7B7B))
                  .withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 4,
                backgroundColor: isQueueOpen
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFFF7B7B),
              ),
              const SizedBox(width: 8),
              Text(
                isQueueOpen ? 'Queue Open' : 'Queue Closed',
                style: TextStyle(
                  color: isQueueOpen
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFFF7B7B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: businessId == null || isSaving
              ? null
              : () => _toggleQueueStatus(isQueueOpen),
          style: OutlinedButton.styleFrom(
            foregroundColor: lightGold,
            side: const BorderSide(color: gold),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            isSaving
                ? 'Please wait...'
                : isQueueOpen
                ? 'Close Queue'
                : 'Open Queue',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showAddWalkinDialog(hospitalName),
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('Add Walk-in', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: const Color(0xFF1A1208),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          actions,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 18),
        actions,
      ],
    );
  }

  Widget _summaryCards({
    required int waitingCount,
    required String currentTokenNumber,
    required int servedCount,
    required String avgWaitTime,
  }) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _summaryCard(
          title: 'WAITING NOW',
          value: '$waitingCount',
          icon: Icons.groups_outlined,
          color: const Color(0xFF9BD9FF),
        ),
        _summaryCard(
          title: 'CURRENT TOKEN',
          value: currentTokenNumber,
          icon: Icons.confirmation_number_outlined,
          color: lightGold,
        ),
        _summaryCard(
          title: 'SERVED TODAY',
          value: '$servedCount',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF4ADE80),
        ),
        _summaryCard(
          title: 'AVERAGE WAIT',
          value: avgWaitTime,
          icon: Icons.schedule_outlined,
          color: const Color(0xFFFFB86B),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return _glassCard(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              color: textColor,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: subTextColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveQueue({
    required List<Map<String, dynamic>> tokens,
    required int activeCount,
    required int waitingCount,
    required int calledCount,
    required int completedCount,
    required int allCount,
  }) {
    return _glassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count & search
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Live Queue',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${tokens.length} Patients',
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search field & filter tabs
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                        style: const TextStyle(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search by token, patient name, or service...',
                          hintStyle: TextStyle(color: subTextColor.withOpacity(0.5), fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: subTextColor, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: subTextColor, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF1E2638),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Active', 'Active ($activeCount)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Waiting', 'Waiting ($waitingCount)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Called', 'Called ($calledCount)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed', 'Completed ($completedCount)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('All', 'All ($allCount)'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: Colors.white.withOpacity(0.10), height: 1),

          if (tokens.isEmpty)
            Padding(
              padding: const EdgeInsets.all(45),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, color: subTextColor.withOpacity(0.4), size: 40),
                    const SizedBox(height: 10),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No patients match "$_searchQuery".'
                          : 'No patients found in "$_selectedFilter" queue.',
                      style: const TextStyle(color: subTextColor),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  Colors.black.withOpacity(0.18),
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      'TOKEN',
                      style: TextStyle(
                        color: subTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'PATIENT / SERVICE',
                      style: TextStyle(
                        color: subTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'WAITING TIME',
                      style: TextStyle(
                        color: subTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'STATUS',
                      style: TextStyle(
                        color: subTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'ACTIONS',
                      style: TextStyle(
                        color: subTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                rows: tokens.map((token) {
                  return _queueRow(token);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final bool isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? gold.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? gold : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? gold : subTextColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String waitingTime(dynamic joinedAt) {
    if (joinedAt is! Timestamp) {
      return 'Joined just now';
    }

    final difference = DateTime.now().difference(joinedAt.toDate());

    if (difference.inMinutes < 1) {
      return 'Joined just now';
    }

    if (difference.inMinutes < 60) {
      return 'Joined ${difference.inMinutes} min ago';
    }

    return 'Joined ${difference.inHours} hr ago';
  }

  DataRow _queueRow(Map<String, dynamic> token) {
    final tokenId = token['id'] as String;
    final tokenNumber = token['tokenNumber']?.toString() ?? 'A-000';
    final service = token['serviceName']?.toString() ?? 'Hospital Service';
    final patientName = token['userName']?.toString() ?? token['customerName']?.toString() ?? '';
    final doctorName = (token['doctorName'] ?? '').toString();
    final doctorRoom = (token['doctorRoom'] ?? '').toString();
    final wait = waitingTime(token['joinedAt']);
    final rawStatus = (token['status'] ?? 'waiting').toString();
    final statusLower = rawStatus.toLowerCase();
    final bool isCalled = statusLower == 'called' || statusLower == 'serving';
    final bool isCompleted = statusLower == 'completed';
    final bool isSkipped = statusLower == 'skipped';

    Color statusColor;
    if (isCompleted) {
      statusColor = const Color(0xFF4ADE80);
    } else if (isCalled) {
      statusColor = const Color(0xFF9BD9FF);
    } else if (isSkipped) {
      statusColor = const Color(0xFF9E9E9E);
    } else {
      statusColor = const Color(0xFFFFB86B);
    }

    return DataRow(
      cells: [
        // Token Box
        DataCell(
          Container(
            width: 48,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: gold.withOpacity(0.15),
              border: Border.all(color: gold.withOpacity(0.30)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              tokenNumber,
              style: const TextStyle(
                color: lightGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Patient & Service
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                patientName.isNotEmpty ? patientName : service,
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (patientName.isNotEmpty)
                Text(
                  service,
                  style: const TextStyle(
                    color: subTextColor,
                    fontSize: 11,
                  ),
                ),
              if (doctorName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 12, color: lightGold),
                      const SizedBox(width: 3),
                      Text(
                        doctorRoom.isNotEmpty ? '$doctorName ($doctorRoom)' : doctorName,
                        style: const TextStyle(
                          color: lightGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Waiting time
        DataCell(
          Text(
            wait,
            style: const TextStyle(color: subTextColor, fontSize: 12),
          ),
        ),
        // Status Badge
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              rawStatus.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Action Buttons
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (statusLower == 'waiting') ...[
                IconButton(
                  tooltip: 'Call Patient',
                  onPressed: () => _updateTokenStatus(tokenId, 'called'),
                  icon: const Icon(Icons.campaign, color: lightGold, size: 22),
                ),
                IconButton(
                  tooltip: 'Skip Token',
                  onPressed: () => _skipTokenWithConfirmation(token),
                  icon: const Icon(Icons.skip_next_outlined, color: subTextColor, size: 20),
                ),
              ] else if (isCalled) ...[
                IconButton(
                  tooltip: 'Mark Completed',
                  onPressed: () => _updateTokenStatus(tokenId, 'completed'),
                  icon: const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 22),
                ),
                IconButton(
                  tooltip: 'Call Patient Again',
                  onPressed: () {
                    _updateTokenStatus(tokenId, 'called');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Re-announcing Token $tokenNumber!'),
                        backgroundColor: gold,
                      ),
                    );
                  },
                  icon: const Icon(Icons.volume_up, color: lightGold, size: 20),
                ),
                IconButton(
                  tooltip: 'Skip Token',
                  onPressed: () => _skipTokenWithConfirmation(token),
                  icon: const Icon(Icons.skip_next_outlined, color: subTextColor, size: 20),
                ),
              ] else if (isCompleted || isSkipped) ...[
                IconButton(
                  tooltip: 'Re-queue Token',
                  onPressed: () => _updateTokenStatus(tokenId, 'waiting'),
                  icon: const Icon(Icons.replay, color: subTextColor, size: 19),
                ),
              ],
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: subTextColor, size: 18),
                color: const Color(0xFF1E2638),
                onSelected: (val) {
                  if (val == 'call') {
                    _updateTokenStatus(tokenId, 'called');
                  } else if (val == 'complete') {
                    _updateTokenStatus(tokenId, 'completed');
                  } else if (val == 'skip') {
                    _skipTokenWithConfirmation(token);
                  } else if (val == 'cancel') {
                    _updateTokenStatus(tokenId, 'cancelled');
                  } else if (val == 'waiting') {
                    _updateTokenStatus(tokenId, 'waiting');
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'call', child: Text('Call Patient', style: TextStyle(color: textColor))),
                  const PopupMenuItem(value: 'complete', child: Text('Mark Completed', style: TextStyle(color: textColor))),
                  const PopupMenuItem(value: 'skip', child: Text('Skip Token', style: TextStyle(color: textColor))),
                  const PopupMenuItem(value: 'waiting', child: Text('Move to Waiting', style: TextStyle(color: textColor))),
                  const PopupMenuItem(value: 'cancel', child: Text('Cancel Token', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rightCards({
    required Map<String, dynamic>? currentPatient,
    required Map<String, dynamic>? upNextPatient,
    required List<Map<String, dynamic>> waitingTokens,
    required String hospitalName,
  }) {
    return Column(
      children: [
        _currentPatient(currentPatient, waitingTokens),
        const SizedBox(height: 24),
        _callNext(upNextPatient, waitingTokens, hospitalName),
      ],
    );
  }

  Widget _currentPatient(Map<String, dynamic>? currentPatient, List<Map<String, dynamic>> waitingTokens) {
    if (currentPatient == null) {
      return _glassCard(
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.person_outline, color: lightGold),
                SizedBox(width: 8),
                Text(
                  'Current Patient',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Icon(Icons.person_off_outlined, color: subTextColor.withOpacity(0.3), size: 48),
            const SizedBox(height: 12),
            const Text(
              'No Active Patient',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              waitingTokens.isNotEmpty
                  ? '${waitingTokens.length} patient(s) waiting in queue'
                  : 'All patients have been served',
              style: const TextStyle(color: subTextColor, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: waitingTokens.isNotEmpty ? () => _callNextPatient(waitingTokens) : null,
                icon: const Icon(Icons.campaign),
                label: const Text('Call Next Patient'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: const Color(0xFF1A1208),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tokenId = currentPatient['id'] as String;
    final tokenNumber = currentPatient['tokenNumber']?.toString() ?? 'A-000';
    final service = currentPatient['serviceName']?.toString() ?? 'Hospital Service';
    final patientName = currentPatient['userName']?.toString() ?? currentPatient['customerName']?.toString() ?? 'Patient';
    final doctorName = (currentPatient['doctorName'] ?? '').toString();
    final doctorDesignation = (currentPatient['doctorDesignation'] ?? '').toString();
    final doctorRoom = (currentPatient['doctorRoom'] ?? '').toString();
    final wait = waitingTime(currentPatient['joinedAt']);
    final counter = currentPatient['counter']?.toString() ?? 'Counter 1';

    return _glassCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_outline, color: lightGold),
                  SizedBox(width: 8),
                  Text(
                    'Current Patient',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.3)),
                ),
                child: const Text('CALLED', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            tokenNumber,
            style: const TextStyle(
              color: lightGold,
              fontSize: 54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            patientName,
            style: const TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            service,
            style: const TextStyle(
              color: lightGold,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$wait • $counter',
            style: const TextStyle(color: subTextColor, fontSize: 13),
          ),
          if (doctorName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: gold.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medical_services_outlined, size: 18, color: lightGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorName,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (doctorDesignation.isNotEmpty || doctorRoom.isNotEmpty)
                          Text(
                            [doctorDesignation, doctorRoom].where((s) => s.isNotEmpty).join(' • '),
                            style: const TextStyle(color: subTextColor, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _updateTokenStatus(tokenId, 'completed'),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Complete Service', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: const Color(0xFF1A1208),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _updateTokenStatus(tokenId, 'called');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Re-announcing Token $tokenNumber!'),
                        backgroundColor: gold,
                      ),
                    );
                  },
                  icon: const Icon(Icons.volume_up, size: 16),
                  label: const Text('Re-Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: lightGold,
                    side: const BorderSide(color: gold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _skipTokenWithConfirmation(currentPatient),
                  icon: const Icon(Icons.skip_next_outlined, size: 16),
                  label: const Text('Skip Token'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: subTextColor,
                    side: BorderSide(color: Colors.white.withOpacity(0.18)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _callNext(
    Map<String, dynamic>? upNextPatient,
    List<Map<String, dynamic>> waitingTokens,
    String hospitalName,
  ) {
    if (upNextPatient == null) {
      return _glassCard(
        child: Column(
          children: [
            const Text(
              'UP NEXT',
              style: TextStyle(
                color: subTextColor,
                fontSize: 12,
                letterSpacing: 1.3,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2D3546),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: const Text(
                '--',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Queue is Empty',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'No waiting patients',
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddWalkinDialog(hospitalName),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Walk-in Patient'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: lightGold,
                  side: const BorderSide(color: gold),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tokenNumber = upNextPatient['tokenNumber']?.toString() ?? 'A-000';
    final service = upNextPatient['serviceName']?.toString() ?? 'Hospital Service';
    final patientName = upNextPatient['userName']?.toString() ?? upNextPatient['customerName']?.toString() ?? '';
    final doctorName = (upNextPatient['doctorName'] ?? '').toString();

    return _glassCard(
      child: Column(
        children: [
          const Text(
            'UP NEXT',
            style: TextStyle(
              color: subTextColor,
              fontSize: 12,
              letterSpacing: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2D3546),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
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
          const SizedBox(height: 10),
          if (patientName.isNotEmpty)
            Text(
              patientName,
              style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          Text(
            service,
            style: const TextStyle(color: subTextColor, fontSize: 12),
          ),
          if (doctorName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Doctor: $doctorName',
                style: const TextStyle(color: lightGold, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _callNextPatient(waitingTokens),
              icon: const Icon(Icons.campaign),
              label: const Text('Call Next Patient', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: const Color(0xFF1A1208),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    double? width,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0x662D3546),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}