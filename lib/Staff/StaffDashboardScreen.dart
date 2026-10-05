import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login again'),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, staffSnapshot) {
        if (staffSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: gold),
            ),
          );
        }

        if (staffSnapshot.hasError) {
          return _errorScreen(staffSnapshot.error.toString());
        }

        final staff = staffSnapshot.data?.data();

        if (staff == null) {
          return _errorScreen('Staff profile not found.');
        }

        final businessId = staff['businessId']?.toString() ?? '';

        if (businessId.isEmpty) {
          return _errorScreen(
            'Business ID not found for this staff account.',
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .snapshots(),
          builder: (context, businessSnapshot) {
            if (businessSnapshot.hasError) {
              return _errorScreen(businessSnapshot.error.toString());
            }

            final business = businessSnapshot.data?.data() ?? {};

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(businessId)
                  .collection('tokens')
                  .orderBy('joinedAt', descending: false)
                  .snapshots(),
              builder: (context, tokenSnapshot) {
                if (tokenSnapshot.hasError) {
                  return _errorScreen(tokenSnapshot.error.toString());
                }

                final allTokens = tokenSnapshot.data?.docs
                    .map((doc) => doc.data())
                    .toList() ??
                    [];

                final assignedService =
                    staff['assignedService']?.toString() ?? 'Registration';

                // Staff sees tokens for assigned service only.
                final tokens = assignedService == 'All services'
                    ? allTokens
                    : allTokens.where((token) {
                  return token['serviceName'] == assignedService;
                }).toList();

                final waitingTokens = tokens.where((token) {
                  return token['status'] == 'waiting';
                }).toList();

                final calledTokens = tokens.where((token) {
                  return token['status'] == 'called' ||
                      token['status'] == 'serving';
                }).toList();

                final completedTokens = tokens.where((token) {
                  return token['status'] == 'completed';
                }).toList();

                final currentToken =
                calledTokens.isNotEmpty ? calledTokens.first : null;

                final nextToken =
                waitingTokens.isNotEmpty ? waitingTokens.first : null;

                final recentActivity = tokens.where((token) {
                  return token['status'] == 'called' ||
                      token['status'] == 'completed';
                }).toList().reversed.take(3).toList();

                return _dashboardUI(
                  context,
                  staffName: staff['name']?.toString() ?? 'Staff',
                  businessName: business['name']?.toString() ?? 'Hospital',
                  service: assignedService,
                  counter:
                  staff['assignedCounter']?.toString() ?? 'Counter 1',
                  waitingCount: waitingTokens.length,
                  servedCount: completedTokens.length,
                  currentToken: currentToken?['tokenNumber']?.toString() ??
                      '--',
                  nextToken: nextToken?['tokenNumber']?.toString() ?? '--',
                  currentWaitingText: _waitingText(currentToken),
                  nextJoinedText: _joinedText(nextToken),
                  queueOpen:
                  business['isQueueOpen'] ?? business['isOpen'] ?? false,
                  activity: recentActivity,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _dashboardUI(
      BuildContext context, {
        required String staffName,
        required String businessName,
        required String service,
        required String counter,
        required int waitingCount,
        required int servedCount,
        required String currentToken,
        required String nextToken,
        required String currentWaitingText,
        required String nextJoinedText,
        required bool queueOpen,
        required List<Map<String, dynamic>> activity,
      }) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1B2540),
              Color(0xFF0A0F1E),
              Color(0xFF060810),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(
                      isWide,
                      staffName,
                      businessName,
                      service,
                      counter,
                    ),
                    const SizedBox(height: 28),

                    _summaryCards(
                      waitingCount,
                      currentToken,
                      servedCount,
                    ),
                    const SizedBox(height: 22),

                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _currentServiceCard(
                              service,
                              counter,
                              currentToken,
                              currentWaitingText,
                              queueOpen,
                            ),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            flex: 2,
                            child: _upNextCard(
                              service,
                              nextToken,
                              nextJoinedText,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _currentServiceCard(
                            service,
                            counter,
                            currentToken,
                            currentWaitingText,
                            queueOpen,
                          ),
                          const SizedBox(height: 22),
                          _upNextCard(
                            service,
                            nextToken,
                            nextJoinedText,
                          ),
                        ],
                      ),

                    const SizedBox(height: 22),
                    _activityCard(activity),
                    const SizedBox(height: 22),
                    _informationNote(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
      bool isWide,
      String staffName,
      String businessName,
      String service,
      String counter,
      ) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STAFF / DASHBOARD',
          style: TextStyle(
            color: lightGold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Good morning, $staffName',
          style: const TextStyle(
            color: textColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Here is your queue overview for $businessName.',
          style: const TextStyle(
            color: subTextColor,
            fontSize: 14,
          ),
        ),
      ],
    );

    final staffBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0x662D3546),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.badge_outlined, color: lightGold, size: 19),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                counter,
                style: const TextStyle(
                  color: subTextColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          staffBadge,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        const SizedBox(height: 18),
        staffBadge,
      ],
    );
  }

  Widget _summaryCards(
      int waitingCount,
      String currentToken,
      int servedCount,
      ) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _summaryCard(
          title: 'WAITING PATIENTS',
          value: '$waitingCount',
          icon: Icons.groups_outlined,
          color: lightGold,
        ),
        _summaryCard(
          title: 'CURRENT TOKEN',
          value: currentToken,
          icon: Icons.confirmation_number_outlined,
          color: const Color(0xFF9BD9FF),
        ),
        _summaryCard(
          title: 'SERVED TODAY',
          value: '$servedCount',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF4ADE80),
        ),
        _summaryCard(
          title: 'AVERAGE SERVICE TIME',
          value: '9 min',
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: subTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            value,
            style: TextStyle(
              color: color == const Color(0xFF9BD9FF) ? lightGold : textColor,
              fontSize: 31,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentServiceCard(
      String service,
      String counter,
      String currentToken,
      String waitingText,
      bool queueOpen,
      ) {
    final statusColor = queueOpen ? const Color(0xFF4ADE80) : Colors.redAccent;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Current Service',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: statusColor),
                    const SizedBox(width: 7),
                    Text(
                      queueOpen ? 'ON DUTY' : 'QUEUE CLOSED',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withOpacity(0.10)),
          const SizedBox(height: 24),
          Text(
            service,
            style: const TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            counter,
            style: const TextStyle(
              color: subTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'CURRENT TOKEN',
            style: TextStyle(
              color: subTextColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentToken,
            style: const TextStyle(
              color: lightGold,
              fontSize: 60,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: Color(0xFFFF7B7B),
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                waitingText,
                style: const TextStyle(
                  color: Color(0xFFFF7B7B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.queue_play_next),
                label: const Text('Manage Queue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: const Color(0xFF1A1208),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Mark Off Duty'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: lightGold,
                  side: BorderSide(color: Colors.white.withOpacity(0.20)),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _upNextCard(
      String service,
      String nextToken,
      String joinedText,
      ) {
    return _glassCard(
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Up Next',
              style: TextStyle(
                color: textColor,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 35),
          const Text(
            'NEXT TOKEN',
            style: TextStyle(
              color: subTextColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            nextToken,
            style: const TextStyle(
              color: textColor,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            service,
            style: const TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            joinedText,
            style: const TextStyle(
              color: subTextColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View Queue'),
              style: OutlinedButton.styleFrom(
                foregroundColor: lightGold,
                side: const BorderSide(color: gold),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityCard(List<Map<String, dynamic>> activity) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Activity",
            style: TextStyle(
              color: textColor,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),

          if (activity.isEmpty)
            const Text(
              'No queue activity yet.',
              style: TextStyle(color: subTextColor),
            ),

          ...activity.map((token) {
            final status = token['status']?.toString() ?? '';
            final isCompleted = status == 'completed';

            return _activityRow(
              token: token['tokenNumber']?.toString() ?? '--',
              text: isCompleted ? 'Completed' : 'Called to counter',
              time: _tokenTime(token),
              icon: isCompleted
                  ? Icons.check_circle_outline
                  : Icons.campaign_outlined,
              color: isCompleted ? const Color(0xFF4ADE80) : lightGold,
            );
          }),
        ],
      ),
    );
  }

  Widget _activityRow({
    required String token,
    required String text,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              token,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: textColor, fontSize: 14),
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: subTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _informationNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: gold.withOpacity(0.20)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: lightGold),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'You can manage queue operations only for your assigned counter and service.',
              style: TextStyle(color: lightGold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    double? width,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(22),
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

  static Widget _errorScreen(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  static String _waitingText(Map<String, dynamic>? token) {
    if (token == null) return 'No patient is currently called';

    final time = token['joinedAt'];

    if (time is Timestamp) {
      final minutes = DateTime.now().difference(time.toDate()).inMinutes;
      return 'Patient waiting for $minutes minutes';
    }

    return 'Patient is waiting';
  }

  static String _joinedText(Map<String, dynamic>? token) {
    if (token == null) return 'No waiting patient';

    final time = token['joinedAt'];

    if (time is Timestamp) {
      final minutes = DateTime.now().difference(time.toDate()).inMinutes;
      return 'Joined $minutes minutes ago';
    }

    return 'Waiting in queue';
  }

  static String _tokenTime(Map<String, dynamic> token) {
    final time = token['updatedAt'] ?? token['joinedAt'];

    if (time is Timestamp) {
      final date = time.toDate();
      final hour = date.hour > 12 ? date.hour - 12 : date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    return '';
  }
}