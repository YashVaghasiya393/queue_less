import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'AdminDataHelper.dart';

const Color gold = Color(0xFFF5A623);
const Color lightGold = Color(0xFFFFC880);
const Color textColor = Color(0xFFDAE2F8);
const Color subTextColor = Color(0xFFD7C3AE);

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  String _businessId = AdminDataHelper.defaultBusinessId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    await AdminDataHelper.ensureAdminAuth();
    final id = await AdminDataHelper.getBusinessId();
    if (!mounted) return;
    setState(() {
      _businessId = id;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: StaffManagementScreen.gold),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId)
          .snapshots(),
      builder: (context, hospitalSnapshot) {
        final hospitalData = hospitalSnapshot.data?.data();
        final businessName = hospitalData?['name']?.toString() ?? 'Sunrise Care Hospital';

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(_businessId)
              .collection('services')
              .snapshots(),
          builder: (context, serviceSnapshot) {
            final services = (serviceSnapshot.data?.docs ?? []).map((doc) {
              final d = Map<String, dynamic>.from(doc.data());
              d['id'] = doc.id;
              return d;
            }).toList();

            final activeServices = services.where((service) {
              return service['isActive'] == true;
            }).length;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(_businessId)
                  .collection('staff')
                  .snapshots(),
              builder: (context, hospitalStaffSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, usersSnapshot) {
                    if (hospitalStaffSnapshot.connectionState == ConnectionState.waiting &&
                        usersSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: StaffManagementScreen.gold),
                      );
                    }

                    // 1. Staff from users collection (registered via app)
                    final userStaff = (usersSnapshot.data?.docs ?? []).map((doc) {
                      final data = Map<String, dynamic>.from(doc.data());
                      data['id'] = doc.id;
                      data['source'] = 'users';
                      return data;
                    }).where((u) {
                      final role = u['role']?.toString().toLowerCase();
                      final biz = u['businessId']?.toString().trim();
                      final isStaff = role == 'staff' || role == 'doctor' || role == 'nurse';
                      final matchesBiz = biz == null || biz.isEmpty || biz == _businessId || _businessId.isEmpty;
                      return isStaff && matchesBiz;
                    }).toList();

                    // 2. Staff from businesses/{businessId}/staff subcollection
                    final hospitalStaff = (hospitalStaffSnapshot.data?.docs ?? []).map((doc) {
                      final data = Map<String, dynamic>.from(doc.data());
                      data['id'] = doc.id;
                      data['source'] = 'hospital';
                      return data;
                    }).toList();

                    // Merge staff avoiding duplicates
                    final Map<String, Map<String, dynamic>> mergedMap = {};
                    for (var s in userStaff) {
                      final key = (s['email'] != null && s['email'].toString().isNotEmpty)
                          ? s['email'].toString().toLowerCase()
                          : s['id'].toString();
                      mergedMap[key] = s;
                    }
                    for (var s in hospitalStaff) {
                      final key = (s['email'] != null && s['email'].toString().isNotEmpty)
                          ? s['email'].toString().toLowerCase()
                          : s['id'].toString();
                      mergedMap[key] = s;
                    }
                    final staffMembers = mergedMap.values.toList();

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
                      businessName: businessName,
                      staffMembers: staffMembers,
                      services: services,
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
      },
    );
  }

  Widget _screenUI(
      BuildContext context, {
        required String businessName,
        required List<Map<String, dynamic>> staffMembers,
        required List<Map<String, dynamic>> services,
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
          _header(context, isWide, businessName, services),
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
                  child: _staffTable(staffMembers, services),
                ),
                const SizedBox(width: 24),
                Expanded(child: _accessCard()),
              ],
            )
          else
            Column(
              children: [
                _staffTable(staffMembers, services),
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
      List<Map<String, dynamic>> services,
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
      onPressed: () => _showAddStaffDialog(context, services),
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

  void _showAddStaffDialog(BuildContext context, List<Map<String, dynamic>> services) {
    final nameCtrl = TextEditingController();
    final designationCtrl = TextEditingController(text: 'Staff Member');
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final counterCtrl = TextEditingController();
    String? selectedService = services.isNotEmpty ? services.first['name']?.toString() : null;
    String selectedStatus = 'On Duty';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B2540),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1_outlined, color: gold),
                  SizedBox(width: 10),
                  Text('Add Staff Member', style: TextStyle(color: lightGold, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogField(controller: nameCtrl, label: 'Full Name', hint: 'e.g. Dr. Rajesh Kumar'),
                      const SizedBox(height: 12),
                      _dialogField(controller: designationCtrl, label: 'Role / Designation', hint: 'e.g. Doctor, Nurse, Receptionist'),
                      const SizedBox(height: 12),
                      _dialogField(controller: emailCtrl, label: 'Email Address', hint: 'e.g. rajesh@hospital.com', keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      _dialogField(controller: phoneCtrl, label: 'Phone Number', hint: 'e.g. +91 98765 43210', keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      _dialogField(controller: counterCtrl, label: 'Assigned Counter / Room', hint: 'e.g. Counter 1, Room 102'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedService,
                        dropdownColor: const Color(0xFF1B2540),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Assigned Service',
                          labelStyle: const TextStyle(color: subTextColor, fontSize: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: gold),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No Service Assigned')),
                          ...services.map((s) => DropdownMenuItem(
                            value: s['name']?.toString() ?? '',
                            child: Text(s['name']?.toString() ?? 'Service'),
                          )),
                        ],
                        onChanged: (val) => setModalState(() => selectedService = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        dropdownColor: const Color(0xFF1B2540),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Duty Status',
                          labelStyle: const TextStyle(color: subTextColor, fontSize: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: gold),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'On Duty', child: Text('On Duty')),
                          DropdownMenuItem(value: 'Off Duty', child: Text('Off Duty')),
                          DropdownMenuItem(value: 'On Leave', child: Text('On Leave')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedStatus = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: subTextColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF1A1208)),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter staff name.')),
                      );
                      return;
                    }

                    try {
                      await FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(_businessId)
                          .collection('staff')
                          .add({
                        'name': nameCtrl.text.trim(),
                        'designation': designationCtrl.text.trim().isEmpty ? 'Staff Member' : designationCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'role': 'staff',
                        'businessId': _businessId,
                        'assignedService': selectedService ?? 'Not assigned',
                        'assignedCounter': counterCtrl.text.trim().isEmpty ? 'Not assigned' : counterCtrl.text.trim(),
                        'status': selectedStatus,
                        'isOnDuty': selectedStatus == 'On Duty',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${nameCtrl.text.trim()} added successfully!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding staff: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Add Staff'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditStaffDialog(BuildContext context, Map<String, dynamic> staff, List<Map<String, dynamic>> services) {
    final designationCtrl = TextEditingController(text: staff['designation']?.toString() ?? 'Staff Member');
    final counterCtrl = TextEditingController(text: staff['assignedCounter']?.toString() ?? '');
    String? selectedService = staff['assignedService']?.toString();
    String selectedStatus = _staffStatus(staff);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B2540),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.edit_note, color: gold),
                  const SizedBox(width: 10),
                  Text('Edit ${staff["name"] ?? "Staff"}', style: const TextStyle(color: lightGold, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogField(controller: designationCtrl, label: 'Role / Designation', hint: 'e.g. Doctor, Nurse'),
                      const SizedBox(height: 12),
                      _dialogField(controller: counterCtrl, label: 'Assigned Counter / Room', hint: 'e.g. Counter 1, Room 102'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: (selectedService != null && services.any((s) => s['name'] == selectedService))
                            ? selectedService
                            : null,
                        dropdownColor: const Color(0xFF1B2540),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Assigned Service',
                          labelStyle: const TextStyle(color: subTextColor, fontSize: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: gold),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Not assigned')),
                          ...services.map((s) => DropdownMenuItem(
                            value: s['name']?.toString() ?? '',
                            child: Text(s['name']?.toString() ?? 'Service'),
                          )),
                        ],
                        onChanged: (val) => setModalState(() => selectedService = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: ['On Duty', 'Off Duty', 'On Leave'].contains(selectedStatus) ? selectedStatus : 'On Duty',
                        dropdownColor: const Color(0xFF1B2540),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Duty Status',
                          labelStyle: const TextStyle(color: subTextColor, fontSize: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: gold),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'On Duty', child: Text('On Duty')),
                          DropdownMenuItem(value: 'Off Duty', child: Text('Off Duty')),
                          DropdownMenuItem(value: 'On Leave', child: Text('On Leave')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedStatus = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: subTextColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF1A1208)),
                  onPressed: () async {
                    try {
                      final updateData = {
                        'designation': designationCtrl.text.trim(),
                        'assignedCounter': counterCtrl.text.trim(),
                        'assignedService': selectedService ?? 'Not assigned',
                        'status': selectedStatus,
                        'isOnDuty': selectedStatus == 'On Duty',
                      };

                      if (staff['source'] == 'hospital') {
                        await FirebaseFirestore.instance
                            .collection('businesses')
                            .doc(_businessId)
                            .collection('staff')
                            .doc(staff['id'])
                            .update(updateData);
                      } else {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(staff['id'])
                            .update(updateData);
                      }

                      if (context.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${staff["name"]} updated successfully!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating staff: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStaff(BuildContext context, Map<String, dynamic> staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2540),
        title: const Text('Remove Staff Member', style: TextStyle(color: Color(0xFFFFC880))),
        content: Text('Are you sure you want to remove ${staff["name"]} from staff?', style: const TextStyle(color: Color(0xFFD7C3AE))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (staff['source'] == 'hospital') {
          await FirebaseFirestore.instance
              .collection('businesses')
              .doc(_businessId)
              .collection('staff')
              .doc(staff['id'])
              .delete();
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(staff['id'])
              .delete();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${staff["name"]} removed successfully.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing staff: $e')),
          );
        }
      }
    }
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: subTextColor, fontSize: 13),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: gold),
        ),
      ),
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

  Widget _staffTable(List<Map<String, dynamic>> staffMembers, List<Map<String, dynamic>> services) {
    return _glassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hospital Team',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${staffMembers.length} Members',
                  style: const TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
                    context: context,
                    staff: staff,
                    services: services,
                    initials: _initials(name),
                    name: name,
                    role: staff['designation']?.toString() ??
                        (staff['role']?.toString().toUpperCase() == 'STAFF' ? 'Staff Member' : staff['role']?.toString() ?? 'Staff Member'),
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

  static Widget _tableTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: subTextColor,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    );
  }

  DataRow _staffRow({
    required BuildContext context,
    required Map<String, dynamic> staff,
    required List<Map<String, dynamic>> services,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showEditStaffDialog(context, staff, services),
                tooltip: 'Edit Staff',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: lightGold,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: () => _deleteStaff(context, staff),
                tooltip: 'Remove Staff',
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ],
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
}