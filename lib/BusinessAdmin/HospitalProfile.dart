import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'AdminDataHelper.dart';

class HospitalProfileScreen extends StatefulWidget {
  const HospitalProfileScreen({super.key});

  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  @override
  State<HospitalProfileScreen> createState() => _HospitalProfileScreenState();
}

class _HospitalProfileScreenState extends State<HospitalProfileScreen> {
  String _businessId = AdminDataHelper.defaultBusinessId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHospital();
  }

  Future<void> _loadHospital() async {
    await AdminDataHelper.ensureAdminAuth();
    final id = await AdminDataHelper.getBusinessId();
    if (!mounted) return;
    setState(() {
      _businessId = id;
      _isLoading = false;
    });
  }

  void _showEditProfileDialog(BuildContext context, Map<String, dynamic> business) {
    final nameController = TextEditingController(text: business['name'] ?? 'Sunrise Care Hospital');
    final categoryController = TextEditingController(text: business['category'] ?? 'General Hospital');
    final addressController = TextEditingController(text: business['address'] ?? 'Indore, Madhya Pradesh');
    final phoneController = TextEditingController(text: business['phone'] ?? '+91 98765 43210');
    final emailController = TextEditingController(text: business['email'] ?? 'contact@sunrisecare.com');
    final hoursController = TextEditingController(text: business['operatingHours'] ?? 'Mon - Sat, 9:00 AM - 8:00 PM');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF141F39),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Hospital Profile',
          style: TextStyle(color: HospitalProfileScreen.textColor, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField('Hospital Name', nameController),
                const SizedBox(height: 12),
                _buildDialogField('Category', categoryController),
                const SizedBox(height: 12),
                _buildDialogField('Address', addressController),
                const SizedBox(height: 12),
                _buildDialogField('Phone Number', phoneController),
                const SizedBox(height: 12),
                _buildDialogField('Email Address', emailController),
                const SizedBox(height: 12),
                _buildDialogField('Operating Hours', hoursController),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: HospitalProfileScreen.subTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HospitalProfileScreen.gold,
              foregroundColor: const Color(0xFF1A1208),
            ),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('businesses')
                    .doc(_businessId)
                    .set({
                  'name': nameController.text.trim(),
                  'category': categoryController.text.trim(),
                  'address': addressController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'email': emailController.text.trim(),
                  'operatingHours': hoursController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hospital profile saved to Firebase!'),
                    backgroundColor: Color(0xFF1B2540),
                  ),
                );
              } catch (e) {
                if (!dialogCtx.mounted) return;
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  SnackBar(content: Text('Failed to update: $e')),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: HospitalProfileScreen.textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: HospitalProfileScreen.subTextColor, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: HospitalProfileScreen.gold),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: HospitalProfileScreen.gold),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId)
          .snapshots(),
      builder: (context, businessSnapshot) {
        if (businessSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: HospitalProfileScreen.gold),
          );
        }

        final business = businessSnapshot.data?.data() ?? {};
        final bool isQueueOpen =
            business['isQueueOpen'] ?? business['isOpen'] ?? false;

        final bool isWide = MediaQuery.of(context).size.width > 1050;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(isWide, business),
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
  }

  Widget _header(bool isWide, Map<String, dynamic> business) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Dashboard',
              style: TextStyle(color: HospitalProfileScreen.subTextColor, fontSize: 13),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.chevron_right,
                size: 17,
                color: HospitalProfileScreen.subTextColor,
              ),
            ),
            Text(
              'Hospital Profile',
              style: TextStyle(color: HospitalProfileScreen.lightGold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Hospital Profile',
          style: TextStyle(
            color: HospitalProfileScreen.textColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Live data synchronized from Firebase Firestore for ${business['name'] ?? 'Sunrise Care Hospital'}.',
          style: const TextStyle(color: HospitalProfileScreen.subTextColor, fontSize: 14),
        ),
      ],
    );

    final editButton = ElevatedButton.icon(
      onPressed: () => _showEditProfileDialog(context, business),
      icon: const Icon(Icons.edit, size: 18),
      label: const Text('Edit Profile'),
      style: ElevatedButton.styleFrom(
        backgroundColor: HospitalProfileScreen.gold,
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
              color: HospitalProfileScreen.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: const Icon(
              Icons.local_hospital,
              color: HospitalProfileScreen.lightGold,
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
                        color: HospitalProfileScreen.textColor,
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
                            'Verified Facility',
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
                    color: HospitalProfileScreen.subTextColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Providing trusted, comprehensive healthcare and efficient patient queue management services for the community.',
                  style: TextStyle(
                    color: HospitalProfileScreen.textColor,
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
    required bool isQueueOpen,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONTACT & LOCATION',
            style: TextStyle(
              color: HospitalProfileScreen.textColor,
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
                    value: business['email']?.toString() ?? 'contact@sunrisecare.com',
                  ),
                  const SizedBox(height: 18),
                  _infoBox(
                    label: 'Phone Number',
                    icon: Icons.call_outlined,
                    value: business['phone']?.toString() ?? '+91 98765 43210',
                  ),
                  const SizedBox(height: 18),
                  _infoBox(
                    label: 'Facility Category',
                    icon: Icons.domain_outlined,
                    value: business['category']?.toString() ?? 'General Hospital',
                  ),
                ],
              );

              final rightItems = Column(
                children: [
                  _infoBox(
                    label: 'Address',
                    icon: Icons.map_outlined,
                    value: business['address']?.toString() ?? 'Indore, Madhya Pradesh',
                  ),
                  const SizedBox(height: 18),
                  _infoBox(
                    label: 'Operating Hours',
                    icon: Icons.schedule_outlined,
                    value: business['operatingHours']?.toString() ??
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
            color: HospitalProfileScreen.subTextColor,
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
              Icon(icon, color: HospitalProfileScreen.subTextColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: HospitalProfileScreen.textColor,
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
            color: HospitalProfileScreen.subTextColor,
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
                color: HospitalProfileScreen.subTextColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Queue Status',
                  style: TextStyle(color: HospitalProfileScreen.textColor, fontSize: 13),
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
                  color: HospitalProfileScreen.lightGold,
                  size: 20,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Public Visibility',
                style: TextStyle(
                  color: HospitalProfileScreen.textColor,
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
              color: HospitalProfileScreen.subTextColor,
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
                          color: HospitalProfileScreen.textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Patients will see a trust badge for your hospital.',
                        style: TextStyle(
                          color: HospitalProfileScreen.subTextColor,
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
              color: HospitalProfileScreen.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _Guideline(
            text: 'Arrive 15 minutes before your estimated queue turn.',
            icon: Icons.check_circle_outline,
            color: HospitalProfileScreen.lightGold,
          ),
          SizedBox(height: 12),
          _Guideline(
            text: 'Valid Government ID is required for new registrations.',
            icon: Icons.check_circle_outline,
            color: HospitalProfileScreen.lightGold,
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