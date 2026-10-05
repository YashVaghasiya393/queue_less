import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  String? businessId;

  @override
  void initState() {
    super.initState();
    loadBusinessId();
  }

  Future<void> loadBusinessId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!mounted) return;

    setState(() {
      businessId = userDoc.data()?['businessId'];
    });
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          _buildSummaryCards(context),
          const SizedBox(height: 28),
          _buildServicesTable(context),
        ],
      ),
    );
  }
  Widget _buildSidebar() {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x99101728),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [lightGold, gold],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.confirmation_number_rounded,
                  color: Color(0xFF17100A),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QueueLess',
                    style: TextStyle(
                      color: lightGold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Sunrise Care Hospital',
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 42),

          _navItem(Icons.dashboard_outlined, 'Dashboard'),
          _navItem(Icons.domain_outlined, 'Hospital Profile'),
          _navItem(Icons.layers_outlined, 'Services', selected: true),
          _navItem(Icons.queue_outlined, 'Queue Management'),
          _navItem(Icons.groups_outlined, 'Staff'),
          _navItem(Icons.qr_code_outlined, 'QR Code'),

          const Spacer(),

          _navItem(Icons.help_outline, 'Help'),
          _navItem(Icons.logout_outlined, 'Logout'),

          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.10)),
          const SizedBox(height: 12),

          const Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: gold,
                child: Icon(Icons.person, color: Color(0xFF17100A)),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. Sharma',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Hospital Admin',
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(
      IconData icon,
      String text, {
        bool selected = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? gold.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? const Border(
              right: BorderSide(color: gold, width: 3),
            )
                : null,
          ),
          child: ListTile(
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: Icon(
              icon,
              color: selected ? lightGold : subTextColor,
            ),
            title: Text(
              text,
              style: TextStyle(
                color: selected ? lightGold : subTextColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            onTap: () {},
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 28),
      child: Row(
        children: [
          Icon(Icons.confirmation_number_rounded, color: lightGold),
          SizedBox(width: 10),
          Text(
            'QueueLess',
            style: TextStyle(
              color: lightGold,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          Icon(Icons.menu, color: lightGold),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    'Services',
                    style: TextStyle(color: textColor, fontSize: 13),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Hospital Services',
                style: TextStyle(
                  color: textColor,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Manage the services available for patients at Sunrise Care Hospital.',
                style: TextStyle(color: subTextColor, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: businessId == null ? null : openAddServiceDialog,
          icon: const Icon(Icons.add, color: Color(0xFF1A1208)),
          label: const Text(
            'Add Service',
            style: TextStyle(
              color: Color(0xFF1A1208),
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    if (businessId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: gold),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('services')
          .snapshots(),
      builder: (context, serviceSnapshot) {
        final services = serviceSnapshot.data?.docs ?? [];

        final totalServices = services.length;

        final activeServices = services.where((serviceDoc) {
          return serviceDoc.data()['isActive'] == true;
        }).length;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .snapshots(),
          builder: (context, businessSnapshot) {
            final businessData = businessSnapshot.data?.data();

            // If this field does not exist yet, queue stays Closed.
            final bool isQueueOpen =
                businessData?['isQueueOpen'] ?? false;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _summaryCard(
                  title: 'TOTAL SERVICES',
                  value: totalServices.toString(),
                  icon: Icons.layers_outlined,
                  iconColor: lightGold,
                ),
                _summaryCard(
                  title: 'ACTIVE SERVICES',
                  value: activeServices.toString(),
                  icon: Icons.check_circle_outline,
                  iconColor: const Color(0xFF4ADE80),
                ),
                _summaryCard(
                  title: 'QUEUE STATUS',
                  value: isQueueOpen ? 'Open' : 'Closed',
                  icon: isQueueOpen
                      ? Icons.lock_open_outlined
                      : Icons.lock_outline,
                  iconColor: isQueueOpen
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFFF7B7B),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return _glassPanel(
      width: 230,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: subTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Future<void> openAddServiceDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final timeController = TextEditingController();
    bool isActive = true;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF17202F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Add Service',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(
                      controller: nameController,
                      label: 'Service Name',
                      hint: 'Example: Doctor Consultation',
                    ),
                    const SizedBox(height: 14),
                    _dialogField(
                      controller: descriptionController,
                      label: 'Description',
                      hint: 'Example: Consultation with a doctor',
                    ),
                    const SizedBox(height: 14),
                    _dialogField(
                      controller: timeController,
                      label: 'Estimated Time (minutes)',
                      hint: 'Example: 20',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Service is active',
                        style: TextStyle(color: textColor),
                      ),
                      value: isActive,
                      activeColor: gold,
                      onChanged: (value) {
                        setDialogState(() {
                          isActive = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: subTextColor),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: const Color(0xFF1A1208),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final description = descriptionController.text.trim();
                    final minutes = int.tryParse(timeController.text.trim());

                    if (name.isEmpty || description.isEmpty || minutes == null) {
                      showMessage('Enter all service details correctly.');
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('businesses')
                        .doc(businessId)
                        .collection('services')
                        .add({
                      'name': name,
                      'description': description,
                      'estimatedMinutes': minutes,
                      'isActive': isActive,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (!mounted) return;

                    Navigator.pop(dialogContext);
                    showMessage('Service added successfully.');
                  },
                  child: const Text('Save Service'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    timeController.dispose();
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: subTextColor, fontSize: 13),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: subTextColor),
            filled: true,
            fillColor: Colors.black.withOpacity(0.20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesTable(BuildContext context) {
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
          .collection('services')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to load services.',
            style: TextStyle(color: Colors.redAccent),
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

        final services = snapshot.data!.docs;

        return _glassPanel(
          width: double.infinity,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Active Services List',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Divider(color: Colors.white.withOpacity(0.10), height: 1),

              if (services.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'No services added yet. Click Add Service.',
                      style: TextStyle(color: subTextColor),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        columnSpacing: 42,
                        headingRowColor: WidgetStatePropertyAll(
                          Colors.black.withOpacity(0.18),
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'SERVICE NAME',
                              style: TextStyle(
                                color: Color(0xFFD7C3AE),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'DESCRIPTION',
                              style: TextStyle(
                                color: Color(0xFFD7C3AE),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'EST. TIME',
                              style: TextStyle(
                                color: Color(0xFFD7C3AE),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'STATUS',
                              style: TextStyle(
                                color: Color(0xFFD7C3AE),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'ACTIONS',
                              style: TextStyle(
                             color: Color(0xFFD7C3AE),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        rows: services.map((serviceDoc) {
                          final service = serviceDoc.data();

                          return _serviceRow(
                            serviceDoc.id,
                            service['name'] ?? '',
                            service['description'] ?? '',
                            ((service['estimatedMinutes'] as num?)?.toInt() ?? 0) as int,
                            service['isActive'] ?? true,
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
  Future<void> openEditServiceDialog(
      String serviceId,
      String oldName,
      String oldDescription,
      int oldMinutes,
      bool oldIsActive,
      ) async {
    final nameController = TextEditingController(text: oldName);
    final descriptionController = TextEditingController(
      text: oldDescription,
    );
    final timeController = TextEditingController(
      text: oldMinutes.toString(),
    );

    bool isActive = oldIsActive;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF17202F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit Service',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(
                      controller: nameController,
                      label: 'Service Name',
                      hint: 'Service name',
                    ),
                    const SizedBox(height: 14),
                    _dialogField(
                      controller: descriptionController,
                      label: 'Description',
                      hint: 'Service description',
                    ),
                    const SizedBox(height: 14),
                    _dialogField(
                      controller: timeController,
                      label: 'Estimated Time (minutes)',
                      hint: 'Example: 20',
                      keyboardType: TextInputType.number,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Service is active',
                        style: TextStyle(color: textColor),
                      ),
                      value: isActive,
                      activeColor: gold,
                      onChanged: (value) {
                        setDialogState(() {
                          isActive = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: subTextColor),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: const Color(0xFF1A1208),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final description = descriptionController.text.trim();
                    final minutes = int.tryParse(timeController.text.trim());

                    if (name.isEmpty || description.isEmpty || minutes == null) {
                      showMessage('Enter all service details correctly.');
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('businesses')
                        .doc(businessId)
                        .collection('services')
                        .doc(serviceId)
                        .update({
                      'name': name,
                      'description': description,
                      'estimatedMinutes': minutes,
                      'isActive': isActive,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    if (!mounted) return;

                    Navigator.pop(dialogContext);
                    showMessage('Service updated successfully.');
                  },
                  child: const Text('Update Service'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    timeController.dispose();
  }

  Future<void> deleteService(String serviceId, String serviceName) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF17202F),
          title: const Text(
            'Delete Service?',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Do you want to delete "$serviceName"?',
            style: const TextStyle(color: subTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: subTextColor),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7B7B),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('services')
        .doc(serviceId)
        .delete();

    if (!mounted) return;

    showMessage('Service deleted successfully.');
  }
  DataRow _serviceRow(
      String serviceId,
      String name,
      String description,
      int minutes,
      bool isActive,
      ) {
    final Color statusColor =
    isActive ? const Color(0xFF4ADE80) : const Color(0xFFFF7B7B);

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: lightGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
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
        DataCell(
          SizedBox(
            width: 250,
            child: Text(
              description,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: subTextColor),
            ),
          ),
        ),
        DataCell(
          Text(
            '$minutes min',
            style: const TextStyle(color: textColor),
          ),
        ),
        DataCell(
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                tooltip: 'Edit service',
                onPressed: () {
                  openEditServiceDialog(
                    serviceId,
                    name,
                    description,
                    minutes,
                    isActive,
                  );
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  color: lightGold,
                ),
              ),
              IconButton(
                tooltip: 'Delete service',
                onPressed: () {
                  deleteService(serviceId, name);
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFFF7B7B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _glassPanel({
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