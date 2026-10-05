import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class QueueManagementScreen extends StatefulWidget {
  const QueueManagementScreen({super.key});

  @override
  State<QueueManagementScreen> createState() =>
      _QueueManagementScreenState();
}

class _QueueManagementScreenState extends State<QueueManagementScreen> {
  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  String? businessId;
  bool isQueueOpen = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadQueueStatus();
  }

  Future<void> loadQueueStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final id = userDoc.data()?['businessId'];

    if (id == null) return;

    final businessDoc = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(id)
        .get();

    if (!mounted) return;

    setState(() {
      businessId = id;
      isQueueOpen = businessDoc.data()?['isQueueOpen'] ?? false;
    });
  }

  Future<void> toggleQueueStatus() async {
    if (businessId == null || isSaving) return;

    final newStatus = !isQueueOpen;

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

      setState(() {
        isQueueOpen = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'Queue opened successfully.' : 'Queue closed successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update queue status.'),
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

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1050;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(isWide),
          const SizedBox(height: 28),
          _summaryCards(),
          const SizedBox(height: 28),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _liveQueue()),
                const SizedBox(width: 24),
                Expanded(child: _rightCards()),
              ],
            )
          else
            Column(
              children: [
                _liveQueue(),
                const SizedBox(height: 24),
                _rightCards(),
              ],
            ),
        ],
      ),
    );
  }
  Widget _header(bool isWide) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Row(
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
        SizedBox(height: 12),
        Text(
          'Queue Management',
          style: TextStyle(
            color: textColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Monitor and manage the live patient queue for Sunrise Care Hospital.',
          style: TextStyle(color: subTextColor, fontSize: 14),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: (isQueueOpen
                ? const Color(0xFF4ADE80)
                : const Color(0xFFFF7B7B))
                .withOpacity(0.12),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
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
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: businessId == null || isSaving
              ? null
              : toggleQueueStatus,
          style: OutlinedButton.styleFrom(
            foregroundColor: lightGold,
            side: const BorderSide(color: gold),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 15,
            ),
          ),
          child: Text(
            isSaving
                ? 'Please wait...'
                : isQueueOpen
                ? 'Close Queue'
                : 'Open Queue',
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

  Widget _summaryCards() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _summaryCard(
          title: 'WAITING NOW',
          value: '12',
          icon: Icons.groups_outlined,
          color: const Color(0xFF9BD9FF),
        ),
        _summaryCard(
          title: 'CURRENT TOKEN',
          value: 'A-034',
          icon: Icons.confirmation_number_outlined,
          color: lightGold,
        ),
        _summaryCard(
          title: 'SERVED TODAY',
          value: '48',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF4ADE80),
        ),
        _summaryCard(
          title: 'AVERAGE WAIT',
          value: '18 min',
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

  Widget _liveQueue() {
    if (businessId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: gold),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('tokens')
          .orderBy('joinedAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to load queue tokens.',
            style: TextStyle(color: Color(0xFFFF7B7B)),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: gold),
            ),
          );
        }

        final tokens = snapshot.data!.docs.where((tokenDoc) {
          final status = tokenDoc.data()['status'] ?? 'waiting';

          return status != 'completed' && status != 'skipped';
        }).toList();

        return _glassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
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
                    const Spacer(),
                    const Icon(
                      Icons.more_horiz,
                      color: subTextColor,
                    ),
                  ],
                ),
              ),

              Divider(color: Colors.white.withOpacity(0.10), height: 1),

              if (tokens.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(45),
                  child: Text(
                    'No patients are waiting in the queue.',
                    style: TextStyle(color: subTextColor),
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
                          'SERVICE',
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
                          'ACTION',
                          style: TextStyle(
                            color: subTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    rows: tokens.map((tokenDoc) {
                      final token = tokenDoc.data();

                      return _queueRow(
                        token: token['tokenNumber'] ?? 'A-000',
                        service: token['serviceName'] ?? 'Service',
                        wait: waitingTime(token['joinedAt']),
                        status: token['status'] ?? 'waiting',
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
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

  DataRow _queueRow({
    required String token,
    required String service,
    required String wait,
    required String status,
  }) {
    final bool isCalled = status == 'Called';

    return DataRow(
      cells: [
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
              token,
              style: const TextStyle(
                color: lightGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            service,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(
          Text(
            wait,
            style: const TextStyle(color: subTextColor),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: (isCalled
                  ? const Color(0xFF9BD9FF)
                  : const Color(0xFFFFB86B))
                  .withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: isCalled
                    ? const Color(0xFF9BD9FF)
                    : const Color(0xFFFFB86B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                tooltip: 'Call patient',
                onPressed: () {},
                icon: const Icon(Icons.campaign_outlined, color: lightGold),
              ),
              IconButton(
                tooltip: 'Skip token',
                onPressed: () {},
                icon: const Icon(
                  Icons.skip_next_outlined,
                  color: subTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rightCards() {
    return Column(
      children: [
        _currentPatient(),
        const SizedBox(height: 24),
        _callNext(),
      ],
    );
  }

  Widget _currentPatient() {
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
          const SizedBox(height: 30),
          const Text(
            'A-034',
            style: TextStyle(
              color: lightGold,
              fontSize: 54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Doctor Consultation',
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Waiting for 14 minutes • Counter 1',
            style: TextStyle(color: subTextColor, fontSize: 13),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Complete Service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: const Color(0xFF1A1208),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.skip_next_outlined),
              label: const Text('Skip Token'),
              style: OutlinedButton.styleFrom(
                foregroundColor: subTextColor,
                side: BorderSide(color: Colors.white.withOpacity(0.18)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _callNext() {
    return _glassCard(
      child: Column(
        children: [
          const Text(
            'UP NEXT',
            style: TextStyle(
              color: subTextColor,
              fontSize: 12,
              letterSpacing: 1.3,
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
              'A-035',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.campaign),
              label: const Text('Call Next Patient'),
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: const Color(0xFF1A1208),
                padding: const EdgeInsets.symmetric(vertical: 15),
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