import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HospitalProfileScreen extends StatelessWidget {
  const HospitalProfileScreen({super.key});

  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  @override
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(
        child: Text(
          'Please log in again.',
          style: TextStyle(color: textColor),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: gold),
          );
        }

        final user = userSnapshot.data!.data() ?? {};
        final businessId = user['businessId'];

        if (businessId == null) {
          return const Center(
            child: Text(
              'Business profile was not found.',
              style: TextStyle(color: Color(0xFFFF7B7B)),
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .snapshots(),
          builder: (context, businessSnapshot) {
            if (!businessSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: gold),
              );
            }

            final business = businessSnapshot.data!.data() ?? {};
            final bool isQueueOpen =
                business['isQueueOpen'] ?? business['isOpen'] ?? false;

            final bool isWide =
                MediaQuery.of(context).size.width > 1050;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(isWide),
                  const SizedBox(height: 28),

                  _identityCard(
                    name: business['name'] ?? 'Sunrise Care Hospital',
                    category: business['category'] ?? 'General Hospital',
                    address: business['address'] ?? 'Indore, MP',
                  ),
                  const SizedBox(height: 24),

                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _contactCard(
                            business: business,
                            user: user,
                            isQueueOpen: isQueueOpen,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: _sideCards()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _contactCard(
                          business: business,
                          user: user,
                          isQueueOpen: isQueueOpen,
                        ),
                        const SizedBox(height: 24),
                        _sideCards(),
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

  Widget _header(bool isWide) {
    final heading = Column(
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
                size: 17,
                color: subTextColor,
              ),
            ),
            Text(
              'Hospital Profile',
              style: TextStyle(color: lightGold, fontSize: 13),
            ),
          ],
        ),
        SizedBox(height: 12),
        Text(
          'Hospital Profile',
          style: TextStyle(
            color: textColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Manage the public information and operational details for Sunrise Care Hospital.',
          style: TextStyle(color: subTextColor, fontSize: 14),
        ),
      ],
    );

    final editButton = ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.edit, size: 18),
      label: const Text('Edit Profile'),
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: const Color(0xFF1A1208),
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          editButton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        const SizedBox(height: 18),
        editButton,
      ],
    );
  }

  Widget _identityCard({
    required String name,
    required String category,
    required String address,
  }) {
    return _glassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: const Icon(
              Icons.local_hospital,
              color: lightGold,
              size: 48,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9BD9FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 15,
                            color: Color(0xFF9BD9FF),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Profile Complete',
                            style: TextStyle(
                              color: Color(0xFF9BD9FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$category • $address',
                  style: const TextStyle(
                    color: subTextColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Providing trusted, comprehensive healthcare and efficient patient queue management services for the community.',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard({
    required Map<String, dynamic> business,
    required Map<String, dynamic> user,
    required bool isQueueOpen,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONTACT & LOCATION',
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.10)),
          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (context, constraints) {
              final leftItems = Column(
                children: [
                  _infoBox(
                    label: 'Email Address',
                    icon: Icons.mail_outline,
                    value: user['email'] ?? 'Not added',
                  ),
                  const SizedBox(height: 18),
                  _infoBox(
                    label: 'Phone Number',
                    icon: Icons.call_outlined,
                    value: user['phone'] ?? 'Not added',
                  ),
                  const SizedBox(height: 18),
                  _infoBox(
                    label: 'Facility Category',
                    icon: Icons.domain_outlined,
                    value: business['category'] ?? 'Not added',
                  ),
                ],
              );

              final rightItems = Column(
                children: [
                  _infoBox(
                    label: 'Address',
                    icon: Icons.map_outlined,
                    value: business['address'] ?? 'Not added',
                  ),
                  const SizedBox(height: 18),
                  _infoBox(
                    label: 'Operating Hours',
                    icon: Icons.schedule_outlined,
                    value: business['operatingHours'] ??
                        'Mon - Sat, 9:00 AM - 8:00 PM',
                  ),
                  const SizedBox(height: 18),
                  _queueStatusBox(isQueueOpen),
                ],
              );

              if (constraints.maxWidth > 600) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftItems),
                    const SizedBox(width: 20),
                    Expanded(child: rightItems),
                  ],
                );
              }

              return Column(
                children: [
                  leftItems,
                  const SizedBox(height: 18),
                  rightItems,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoBox({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: subTextColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFF2D3546).withOpacity(0.45),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: subTextColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _queueStatusBox(bool isQueueOpen) {
    final statusColor = isQueueOpen
        ? const Color(0xFF4ADE80)
        : const Color(0xFFFF7B7B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Status',
          style: TextStyle(
            color: subTextColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFF2D3546).withOpacity(0.45),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.door_front_door_outlined,
                color: subTextColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Queue Status',
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
              ),
              Text(
                isQueueOpen ? '● Accepting Patients' : '● Queue Closed',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sideCards() {
    return Column(
      children: [
        _visibilityCard(),
        const SizedBox(height: 24),
        _guidelinesCard(),
      ],
    );
  }

  Widget _visibilityCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(0x332D3546),
                child: Icon(
                  Icons.qr_code_scanner,
                  color: lightGold,
                  size: 20,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Public Visibility',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'This profile information is visible to patients when they scan your hospital QueueLess QR code.',
            style: TextStyle(
              color: subTextColor,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D3546).withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF9BD9FF)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified Facility',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Patients will see a trust badge for your hospital.',
                        style: TextStyle(
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
        ],
      ),
    );
  }

  Widget _guidelinesCard() {
    return _glassCard(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patient Guidelines',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _Guideline(
            text: 'Arrive 15 minutes before your estimated queue turn.',
            icon: Icons.check_circle_outline,
            color: lightGold,
          ),
          SizedBox(height: 12),
          _Guideline(
            text: 'Valid Government ID is required for new registrations.',
            icon: Icons.check_circle_outline,
            color: lightGold,
          ),
          SizedBox(height: 12),
          _Guideline(
            text: 'Emergencies bypass standard queue priority.',
            icon: Icons.emergency_outlined,
            color: Color(0xFFFF7B7B),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(22),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
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

class _Guideline extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _Guideline({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: HospitalProfileScreen.subTextColor,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}