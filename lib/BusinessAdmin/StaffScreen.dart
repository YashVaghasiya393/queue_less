import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          'Please login again.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, adminSnapshot) {
        if (adminSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: gold),
          );
        }

        if (adminSnapshot.hasError) {
          return _errorText(adminSnapshot.error.toString());
        }

        final admin = adminSnapshot.data?.data();
        final businessId = admin?['businessId']?.toString() ?? '';

        if (businessId.isEmpty) {
          return _errorText('Business ID not found for this admin account.');
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('businessId', isEqualTo: businessId)
              .snapshots(),
          builder: (context, staffSnapshot) {
            if (staffSnapshot.hasError) {
              return _errorText(staffSnapshot.error.toString());
            }

            if (staffSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: gold),
              );
            }

            final staffMembers = staffSnapshot.data!.docs
                .map((doc) => doc.data())
                .where((staff) => staff['role'] == 'staff')
                .toList();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(businessId)
                  .collection('services')
                  .snapshots(),
              builder: (context, serviceSnapshot) {
                final services = serviceSnapshot.data?.docs
                    .map((doc) => doc.data())
                    .toList() ??
                    [];

                final activeServices = services.where((service) {
                  return service['isActive'] == true;
                }).length;

                final onDuty = staffMembers.where((staff) {
                  return staff['isOnDuty'] != false &&
                      staff['status'] != 'Off Duty' &&
                      staff['status'] != 'On Leave';
                }).length;

                final counters = staffMembers
                    .map((staff) => staff['assignedCounter']?.toString() ?? '')
                    .where((counter) => counter.isNotEmpty)
                    .toSet()
                    .length;

                return _screenUI(
                  context,
                  businessName:
                  admin?['businessName']?.toString() ?? 'your hospital',
                  staffMembers: staffMembers,
                  totalStaff: staffMembers.length,
                  onDuty: onDuty,
                  counters: counters,
                  activeServices: activeServices,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _screenUI(
      BuildContext context, {
        required String businessName,
        required List<Map<String, dynamic>> staffMembers,
        required int totalStaff,
        required int onDuty,
        required int counters,
        required int activeServices,
      }) {
    final bool isWide = MediaQuery.of(context).size.width > 1050;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, isWide, businessName),
          const SizedBox(height: 28),

          _summaryCards(
            totalStaff: totalStaff,
            onDuty: onDuty,
            counters: counters,
            activeServices: activeServices,
          ),
          const SizedBox(height: 28),

          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _staffTable(staffMembers),
                ),
                const SizedBox(width: 24),
                Expanded(child: _accessCard()),
              ],
            )
          else
            Column(
              children: [
                _staffTable(staffMembers),
                const SizedBox(height: 24),
                _accessCard(),
              ],
            ),

          const SizedBox(height: 30),

          Center(
            child: Text(
              'Staff accounts are linked only to $businessName.',
              style: const TextStyle(
                color: subTextColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
      BuildContext context,
      bool isWide,
      String businessName,
      ) {
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
              'Staff',
              style: TextStyle(color: lightGold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Staff Management',
          style: TextStyle(
            color: textColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Manage team members and their queue responsibilities at $businessName.',
          style: const TextStyle(
            color: subTextColor,
            fontSize: 14,
          ),
        ),
      ],
    );

    final addButton = ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Create the staff account from your staff signup form.'),
          ),
        );
      },
      icon: const Icon(Icons.add, size: 19),
      label: const Text('Add Staff Member'),
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: const Color(0xFF1A1208),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          addButton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 18),
        addButton,
      ],
    );
  }

  Widget _summaryCards({
    required int totalStaff,
    required int onDuty,
    required int counters,
    required int activeServices,
  }) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _summaryCard(
          icon: Icons.groups_outlined,
          title: 'TOTAL STAFF',
          value: '$totalStaff',
          color: lightGold,
        ),
        _summaryCard(
          icon: Icons.badge_outlined,
          title: 'ON DUTY',
          value: '$onDuty',
          color: const Color(0xFF4ADE80),
        ),
        _summaryCard(
          icon: Icons.desk_outlined,
          title: 'AVAILABLE COUNTERS',
          value: '$counters',
          color: const Color(0xFF9BD9FF),
        ),
        _summaryCard(
          icon: Icons.layers_outlined,
          title: 'ACTIVE SERVICES',
          value: '$activeServices',
          color: const Color(0xFFFFB86B),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return _glassCard(
      width: 200,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: subTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _staffTable(List<Map<String, dynamic>> staffMembers) {
    return _glassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Hospital Team',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(color: Colors.white.withOpacity(0.10), height: 1),

          if (staffMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(35),
              child: Text(
                'No staff members have been added yet.',
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
                columns: [
                  DataColumn(label: _tableTitle('STAFF MEMBER')),
                  DataColumn(label: _tableTitle('ROLE')),
                  DataColumn(label: _tableTitle('ASSIGNED SERVICE')),
                  DataColumn(label: _tableTitle('COUNTER')),
                  DataColumn(label: _tableTitle('STATUS')),
                  DataColumn(label: _tableTitle('ACTIONS')),
                ],
                rows: staffMembers.map((staff) {
                  final name = staff['name']?.toString() ?? 'Staff';
                  final status = _staffStatus(staff);

                  return _staffRow(
                    initials: _initials(name),
                    name: name,
                    role: staff['designation']?.toString() ??
                        'Staff Member',
                    service: staff['assignedService']?.toString() ??
                        'Not assigned',
                    counter: staff['assignedCounter']?.toString() ??
                        'Not assigned',
                    status: status,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  static  Widget _tableTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: subTextColor,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    );
  }

  DataRow _staffRow({
    required String initials,
    required String name,
    required String role,
    required String service,
    required String counter,
    required String status,
  }) {
    Color statusColor = const Color(0xFF4ADE80);

    if (status == 'Off Duty') {
      statusColor = const Color(0xFF9BD9FF);
    }

    if (status == 'On Leave') {
      statusColor = const Color(0xFFFFB86B);
    }

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF2D3546),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: lightGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                name,
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(role, style: const TextStyle(color: subTextColor))),
        DataCell(Text(service, style: const TextStyle(color: subTextColor))),
        DataCell(Text(counter, style: const TextStyle(color: subTextColor))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.edit_outlined,
              color: lightGold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _accessCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: gold.withOpacity(0.12),
            child: const Icon(
              Icons.shield_outlined,
              color: lightGold,
              size: 26,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Staff access',
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Staff members can manage live queue operations. Only the Hospital Admin can change hospital settings and services.',
            style: TextStyle(
              color: subTextColor,
              fontSize: 14,
              height: 1.5,
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

  static String _initials(String name) {
    final words = name.trim().split(' ');

    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }

    return name.isEmpty ? 'S' : name[0].toUpperCase();
  }

  static String _staffStatus(Map<String, dynamic> staff) {
    if (staff['status'] != null) {
      return staff['status'].toString();
    }

    return staff['isOnDuty'] == false ? 'Off Duty' : 'On Duty';
  }

  static Widget _errorText(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}