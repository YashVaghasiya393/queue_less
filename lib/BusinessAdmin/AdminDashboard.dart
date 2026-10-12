import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:queue_less/BusinessAdmin/QRScreen.dart';
import 'package:queue_less/BusinessAdmin/StaffScreen.dart';
import 'AdminDataHelper.dart';

import '../QueueManagement.dart';
import 'HospitalProfile.dart';
import 'ServiceScreen.dart';
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedPage = 0;
  String _businessId = AdminDataHelper.defaultBusinessId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await AdminDataHelper.ensureAdminAuth();
    final id = await AdminDataHelper.getBusinessId();
    if (!mounted) return;
    setState(() {
      _businessId = id;
      _isLoading = false;
    });
  }

  void changePage(int page) {
    setState(() {
      selectedPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B2540),
              Color(0xFF060810),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop)
                SideNavBar(
                  selectedPage: selectedPage,
                  onPageSelected: changePage,
                ),

              Expanded(
                child: selectedPage == 0
                    ? _buildDashboardContent(isDesktop)
                    : selectedPage == 1
                    ? const ServicesScreen()
                    : selectedPage == 2
                    ? const QueueManagementScreen()
                    : selectedPage == 3
                    ? const HospitalProfileScreen()
                    : selectedPage == 4
                    ? const StaffManagementScreen()
                    : const HospitalQrScreen()
              )

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(bool isDesktop) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF5A623)),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessId)
          .snapshots(),
      builder: (context, hospitalSnapshot) {
        final hospitalData = hospitalSnapshot.data?.data() ?? {};
        final hospitalName = hospitalData['name']?.toString() ?? 'Sunrise Care Hospital';
        final isQueueOpen = hospitalData['isQueueOpen'] == true;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(_businessId)
              .collection('services')
              .snapshots(),
          builder: (context, servicesSnapshot) {
            final services = (servicesSnapshot.data?.docs ?? []).map((d) => d.data()).toList();
            final activeServicesCount = services.where((s) => s['isActive'] != false).length;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(_businessId)
                  .collection('tokens')
                  .snapshots(),
              builder: (context, tokensSnapshot) {
                final tokenDocs = (tokensSnapshot.data?.docs ?? []).map((d) {
                  final data = Map<String, dynamic>.from(d.data());
                  data['id'] = d.id;
                  return data;
                }).toList();

                // Sort tokens by joinedAt descending for activity
                tokenDocs.sort((a, b) {
                  final tA = a['joinedAt'];
                  final tB = b['joinedAt'];
                  if (tA is Timestamp && tB is Timestamp) {
                    return tB.compareTo(tA);
                  }
                  return 0;
                });

                final totalTokens = tokenDocs.length;
                final waitingTokens = tokenDocs.where((t) => (t['status'] ?? 'waiting').toString().toLowerCase() == 'waiting').toList();
                final calledTokens = tokenDocs.where((t) {
                  final st = (t['status'] ?? '').toString().toLowerCase();
                  return st == 'called' || st == 'serving';
                }).toList();
                final completedCount = tokenDocs.where((t) => (t['status'] ?? '').toString().toLowerCase() == 'completed').length;

                final avgWaitTimeMinutes = waitingTokens.isEmpty ? 0 : (waitingTokens.length * 8);
                final avgWaitTime = '${avgWaitTimeMinutes}m';

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('businesses')
                      .doc(_businessId)
                      .collection('staff')
                      .snapshots(),
                  builder: (context, hospitalStaffSnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .snapshots(),
                      builder: (context, usersSnap) {
                        final userStaff = (usersSnap.data?.docs ?? []).map((d) => d.data()).where((u) {
                          final role = u['role']?.toString().toLowerCase();
                          final biz = u['businessId']?.toString().trim();
                          return (role == 'staff' || role == 'doctor') && (biz == null || biz == _businessId);
                        }).toList();

                        final hospitalStaff = (hospitalStaffSnap.data?.docs ?? []).map((d) => d.data()).toList();
                        final allStaff = [...userStaff, ...hospitalStaff];
                        final staffOnDutyCount = allStaff.where((s) => s['isOnDuty'] != false && s['status'] != 'Off Duty' && s['status'] != 'On Leave').length;

                        return Column(
                          children: [
                            if (!isDesktop) MobileAppBar(onPageSelected: changePage),

                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(isDesktop ? 32 : 16),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 1440),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        HeaderSection(
                                          hospitalName: hospitalName,
                                          adminName: 'Dr. Sharma',
                                          isQueueOpen: isQueueOpen,
                                          onQueueTap: () => changePage(2),
                                        ),
                                        const SizedBox(height: 24),
                                        SummaryCardsGrid(
                                          totalTokens: totalTokens,
                                          waitingCount: waitingTokens.length,
                                          activeServicesCount: activeServicesCount,
                                          staffOnDutyCount: staffOnDutyCount,
                                          avgWaitTime: avgWaitTime,
                                        ),
                                        const SizedBox(height: 24),

                                        if (isDesktop)
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 8,
                                                child: QueueSnapshotCard(
                                                  isQueueOpen: isQueueOpen,
                                                  waitingTokens: waitingTokens,
                                                  calledTokens: calledTokens,
                                                  totalTokensCount: totalTokens,
                                                  completedCount: completedCount,
                                                  onManageQueueTap: () => changePage(2),
                                                ),
                                              ),
                                              const SizedBox(width: 24),
                                              Expanded(
                                                flex: 4,
                                                child: QuickActionsCard(
                                                  onServicesTap: () => changePage(1),
                                                  onQueueTap: () => changePage(2),
                                                  onQRTap: () => changePage(5),
                                                  onStaffTap: () => changePage(4),
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Column(
                                            children: [
                                              QueueSnapshotCard(
                                                isQueueOpen: isQueueOpen,
                                                waitingTokens: waitingTokens,
                                                calledTokens: calledTokens,
                                                totalTokensCount: totalTokens,
                                                completedCount: completedCount,
                                                onManageQueueTap: () => changePage(2),
                                              ),
                                              const SizedBox(height: 24),
                                              QuickActionsCard(
                                                onServicesTap: () => changePage(1),
                                                onQueueTap: () => changePage(2),
                                                onQRTap: () => changePage(5),
                                                onStaffTap: () => changePage(4),
                                              ),
                                            ],
                                          ),

                                        const SizedBox(height: 24),
                                        RecentActivityCard(
                                          recentTokens: tokenDocs.take(6).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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
}

// ---------------------------------------------------------------------------
// Reusable Glassmorphism Container
// ---------------------------------------------------------------------------
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double opacity;
  final double borderRadius;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.blur = 16.0,
    this.opacity = 0.4,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF2D3546).withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Side Navigation Bar (Desktop)
// ---------------------------------------------------------------------------
class SideNavBar extends StatelessWidget {
  final int selectedPage;
  final Function(int) onPageSelected;

  const SideNavBar({
    super.key,
    required this.selectedPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF17202F).withOpacity(0.4),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Q',
                    style: TextStyle(
                      color: Color(0xFF644000),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QueueLess',
                      style: TextStyle(
                        color: Color(0xFFFFC880),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Hospital Admin',
                      style: TextStyle(
                        color: Color(0xFFD7C3AE),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(color: Colors.white.withOpacity(0.1), height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 12,
              ),
              children: [
                _NavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  isActive: selectedPage == 0,
                  onTap: () => onPageSelected(0),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: 'Hospital Profile',
                  isActive: selectedPage == 3,
                  onTap: () => onPageSelected(3),
                ),
                _NavItem(
                  icon: Icons.layers_outlined,
                  label: 'Services',
                  isActive: selectedPage == 1,
                  onTap: () => onPageSelected(1),
                ),
                _NavItem(
                  icon: Icons.queue,
                  label: 'Queue Management',
                  isActive: selectedPage == 2,
                  onTap: () => onPageSelected(2),
                ),
                _NavItem(
                  icon: Icons.groups_outlined,
                  label: 'Staff',
                  isActive: selectedPage == 4,
                  onTap: () => onPageSelected(4),
                ),
                 _NavItem(
                  icon: Icons.qr_code,
                  label: 'QR',
                   isActive: selectedPage == 5,
                   onTap:() => onPageSelected(5),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () => onPageSelected(2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    foregroundColor: const Color(0xFF452B00),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('VIEW LIVE QUEUE'),
                ),
                const SizedBox(height: 12),
                _NavItem(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Firebase Health',
                  onTap: () => showFirebaseIntegrityDialog(context),
                ),
                _NavItem(
                  icon: Icons.logout,
                  label: 'Logout',
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFFC880).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? const Border(
              right: BorderSide(
                color: Color(0xFFFFC880),
                width: 3,
              ),
            )
                : null,
          ),
          child: ListTile(
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            leading: Icon(
              icon,
              color: isActive
                  ? const Color(0xFFFFC880)
                  : const Color(0xFFD7C3AE),
              size: 22,
            ),
            title: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isActive
                    ? const Color(0xFFFFC880)
                    : const Color(0xFFD7C3AE),
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile Top Bar
// ---------------------------------------------------------------------------
class MobileAppBar extends StatelessWidget {
  final Function(int)? onPageSelected;

  const MobileAppBar({super.key, this.onPageSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1323).withOpacity(0.6),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'QueueLess',
            style: TextStyle(
              color: Color(0xFFFFC880),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.health_and_safety_outlined, color: Color(0xFFFFC880)),
                tooltip: 'Firebase Health',
                onPressed: () => showFirebaseIntegrityDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFFFFC880)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1B2540),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (modalCtx) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            ListTile(
                              leading: const Icon(Icons.dashboard, color: Color(0xFFFFC880)),
                              title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(modalCtx);
                                onPageSelected?.call(0);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.person_outline, color: Color(0xFFFFC880)),
                              title: const Text('Hospital Profile', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(modalCtx);
                                onPageSelected?.call(3);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.layers_outlined, color: Color(0xFFFFC880)),
                              title: const Text('Services', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(modalCtx);
                                onPageSelected?.call(1);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.queue, color: Color(0xFFFFC880)),
                              title: const Text('Queue Management', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(modalCtx);
                                onPageSelected?.call(2);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.groups_outlined, color: Color(0xFFFFC880)),
                              title: const Text('Staff', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(modalCtx);
                                onPageSelected?.call(4);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.qr_code, color: Color(0xFFFFC880)),
                              title: const Text('QR Code', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(modalCtx);
                                onPageSelected?.call(5);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.health_and_safety_outlined, color: Color(0xFFFFC880)),
                              title: const Text('Firebase Health', style: TextStyle(color: Colors.white)),
                              onTap: () {
                                Navigator.pop(modalCtx);
                                showFirebaseIntegrityDialog(context);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.logout, color: Colors.redAccent),
                              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                              onTap: () async {
                                Navigator.pop(modalCtx);
                                await FirebaseAuth.instance.signOut();
                                if (context.mounted) {
                                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Firebase Integrity Health Dialog
// ---------------------------------------------------------------------------
void showFirebaseIntegrityDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogCtx) => FutureBuilder<FirebaseIntegrityReport>(
      future: AdminDataHelper.measureFirebaseIntegrity(),
      builder: (context, snapshot) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2540),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.health_and_safety,
                  color: Color(0xFFF5A623),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Firebase System Health',
                  style: TextStyle(
                    color: Color(0xFFFFC880),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: snapshot.connectionState == ConnectionState.waiting
              ? const SizedBox(
                  height: 180,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5A623)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Measuring Firebase integrity & latency...',
                          style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : snapshot.hasError
                  ? SizedBox(
                      height: 140,
                      child: Center(
                        child: Text(
                          'Integrity check error:\n${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : () {
                      final report = snapshot.data!;
                      final isHealthy = report.isFirestoreConnected && report.isHospitalDataFound;
                      return SizedBox(
                        width: 420,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isHealthy
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isHealthy
                                      ? Colors.greenAccent.withOpacity(0.3)
                                      : Colors.orangeAccent.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isHealthy
                                        ? Icons.check_circle_outline
                                        : Icons.warning_amber_rounded,
                                    color: isHealthy ? Colors.greenAccent : Colors.orangeAccent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isHealthy
                                          ? 'All Firebase Integrations Operational'
                                          : 'Partial Connection / Degraded',
                                      style: TextStyle(
                                        color: isHealthy ? Colors.greenAccent : Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildHealthRow(
                              icon: Icons.vpn_key_outlined,
                              title: 'Firebase Auth Session',
                              value: report.isAuthConnected
                                  ? 'Active (${report.authEmail ?? "admin"})'
                                  : 'Not authenticated',
                              isSuccess: report.isAuthConnected,
                            ),
                            const SizedBox(height: 10),
                            _buildHealthRow(
                              icon: Icons.timer_outlined,
                              title: 'Firestore Ping Latency',
                              value: report.isFirestoreConnected
                                  ? '${report.firestoreLatencyMs} ms'
                                  : 'Failed',
                              isSuccess: report.isFirestoreConnected,
                            ),
                            const SizedBox(height: 10),
                            _buildHealthRow(
                              icon: Icons.local_hospital_outlined,
                              title: 'Hospital Profile Record',
                              value: report.isHospitalDataFound
                                  ? '${report.hospitalName} (ID: ${report.businessId.substring(0, 8)}...)'
                                  : 'Missing in Firestore',
                              isSuccess: report.isHospitalDataFound,
                            ),
                            const SizedBox(height: 10),
                            _buildHealthRow(
                              icon: Icons.medical_services_outlined,
                              title: 'Active Hospital Services',
                              value: '${report.servicesCount} service(s) configured',
                              isSuccess: report.servicesCount > 0,
                            ),
                            if (report.errorMessage != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Note: ${report.errorMessage}',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      );
                    }(),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close', style: TextStyle(color: Color(0xFFF5A623))),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildHealthRow({
  required IconData icon,
  required String title,
  required String value,
  required bool isSuccess,
}) {
  return Row(
    children: [
      Icon(
        icon,
        size: 18,
        color: isSuccess ? const Color(0xFFFFC880) : Colors.grey,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFD7C3AE),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: isSuccess ? Colors.white : Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      Icon(
        isSuccess ? Icons.check : Icons.close,
        color: isSuccess ? Colors.greenAccent : Colors.redAccent,
        size: 16,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Header Section
// ---------------------------------------------------------------------------
class HeaderSection extends StatelessWidget {
  final String hospitalName;
  final String adminName;
  final bool isQueueOpen;
  final VoidCallback? onQueueTap;

  const HeaderSection({
    super.key,
    required this.hospitalName,
    required this.adminName,
    required this.isQueueOpen,
    this.onQueueTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 768;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Welcome, $adminName 👋',
                      style: TextStyle(
                        fontSize: isDesktop ? 32 : 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDAE2F8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isQueueOpen
                          ? const Color(0xFF4CAF50).withOpacity(0.18)
                          : const Color(0xFFE57373).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isQueueOpen
                            ? const Color(0xFF4CAF50).withOpacity(0.5)
                            : const Color(0xFFE57373).withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isQueueOpen ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isQueueOpen ? 'Queue Open' : 'Queue Closed',
                          style: TextStyle(
                            color: isQueueOpen ? const Color(0xFF81C784) : const Color(0xFFEF9A9A),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Live queue management and operational overview for $hospitalName.',
                style: const TextStyle(color: Color(0xFFD7C3AE), fontSize: 15),
              ),
            ],
          ),
        ),
        if (isDesktop)
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onQueueTap ?? () {},
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('VIEW LIVE QUEUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5A623),
                  foregroundColor: const Color(0xFF452B00),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Cards Grid
// ---------------------------------------------------------------------------
class SummaryCardsGrid extends StatelessWidget {
  final int totalTokens;
  final int waitingCount;
  final int activeServicesCount;
  final int staffOnDutyCount;
  final String avgWaitTime;

  const SummaryCardsGrid({
    super.key,
    required this.totalTokens,
    required this.waitingCount,
    required this.activeServicesCount,
    required this.staffOnDutyCount,
    required this.avgWaitTime,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 4;
    if (width < 600) {
      crossAxisCount = 1;
    } else if (width < 1100) {
      crossAxisCount = 2;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SummaryCard(
          title: "TODAY'S TOKENS",
          value: "$totalTokens",
          subValue: "Total generated",
          subColor: const Color(0xFF9BD9FF),
          icon: Icons.confirmation_number_outlined,
        ),
        _SummaryCard(
          title: "WAITING NOW",
          value: "$waitingCount",
          subValue: "Avg wait $avgWaitTime",
          subColor: const Color(0xFFD7C3AE),
          valueColor: const Color(0xFFFFC880),
          icon: Icons.group_outlined,
        ),
        _SummaryCard(
          title: "ACTIVE SERVICES",
          value: "$activeServicesCount",
          subValue: "Operational",
          subColor: const Color(0xFF81C784),
          icon: Icons.medical_services_outlined,
        ),
        _SummaryCard(
          title: "STAFF ON DUTY",
          value: "$staffOnDutyCount",
          subValue: "Active now",
          subColor: const Color(0xFF9BD9FF),
          icon: Icons.badge_outlined,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subValue;
  final Color? subColor;
  final Color? valueColor;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    this.subValue,
    this.subColor,
    this.valueColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Icon(icon, size: 44, color: const Color(0xFFFFC880).withOpacity(0.2)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFFD7C3AE), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.1),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? const Color(0xFFDAE2F8),
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  if (subValue != null) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        subValue!,
                        style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Queue Snapshot Card
// ---------------------------------------------------------------------------
class QueueSnapshotCard extends StatelessWidget {
  final bool isQueueOpen;
  final List<Map<String, dynamic>> waitingTokens;
  final List<Map<String, dynamic>> calledTokens;
  final int totalTokensCount;
  final int completedCount;
  final VoidCallback onManageQueueTap;

  const QueueSnapshotCard({
    super.key,
    required this.isQueueOpen,
    required this.waitingTokens,
    required this.calledTokens,
    required this.totalTokensCount,
    required this.completedCount,
    required this.onManageQueueTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentToken = calledTokens.isNotEmpty
        ? (calledTokens.first['tokenNumber']?.toString() ?? '-')
        : (waitingTokens.isNotEmpty ? '-' : 'None');

    final nextToken = waitingTokens.isNotEmpty
        ? (waitingTokens.first['tokenNumber']?.toString() ?? '-')
        : '-';

    final double progressFraction = totalTokensCount > 0
        ? (completedCount / totalTokensCount).clamp(0.0, 1.0)
        : 0.0;

    // Combine called and top waiting tokens for snapshot preview
    final displayTokens = <Map<String, dynamic>>[];
    for (final t in calledTokens) {
      if (displayTokens.length < 4) displayTokens.add(t);
    }
    for (final t in waitingTokens) {
      if (displayTokens.length < 4) displayTokens.add(t);
    }

    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Queue Snapshot',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDAE2F8),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isQueueOpen
                        ? const Color(0xFF4CAF50).withOpacity(0.15)
                        : const Color(0xFFE57373).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isQueueOpen
                          ? const Color(0xFF4CAF50).withOpacity(0.4)
                          : const Color(0xFFE57373).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isQueueOpen ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isQueueOpen ? 'Queue is Open' : 'Queue Closed',
                        style: TextStyle(
                          color: isQueueOpen ? const Color(0xFF81C784) : const Color(0xFFEF9A9A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CURRENT: $currentToken | NEXT: $nextToken',
                      style: const TextStyle(
                        color: Color(0xFFD7C3AE),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${waitingTokens.length} WAITING',
                      style: const TextStyle(
                        color: Color(0xFFFFC880),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final progressWidth = constraints.maxWidth * progressFraction;
                    return Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D3546),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: progressWidth.clamp(0.0, constraints.maxWidth),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC880),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF5A623).withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (displayTokens.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.white.withOpacity(0.3), size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'No patients currently in queue',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ...displayTokens.map((t) {
                    final status = (t['status'] ?? 'Waiting').toString();
                    final isCalled = status.toLowerCase() == 'called' || status.toLowerCase() == 'serving';
                    final tokenNum = t['tokenNumber']?.toString() ?? 'T-00';
                    final sName = t['serviceName']?.toString() ?? 'Hospital Service';
                    final userName = t['userName']?.toString() ?? t['customerName']?.toString() ?? '';
                    final timeStr = _formatTimeAgo(t['joinedAt'] ?? t['createdAt']);
                    final sub = userName.isNotEmpty ? '$userName • $timeStr' : 'Joined $timeStr';

                    return _TokenItem(
                      token: tokenNum,
                      title: sName,
                      subtitle: sub,
                      status: status.toUpperCase(),
                      isCalled: isCalled,
                    );
                  }),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onManageQueueTap,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    foregroundColor: const Color(0xFFFFC880),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('MANAGE QUEUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenItem extends StatelessWidget {
  final String token;
  final String title;
  final String subtitle;
  final String status;
  final bool isCalled;

  const _TokenItem({
    required this.token,
    required this.title,
    required this.subtitle,
    required this.status,
    this.isCalled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCalled ? const Color(0xFFFFC880).withOpacity(0.06) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCalled ? const Color(0xFFF5A623) : const Color(0xFF2D3546),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    token,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isCalled ? const Color(0xFF452B00) : const Color(0xFFDAE2F8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Color(0xFFDAE2F8), fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFFD7C3AE), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCalled ? const Color(0xFFF5A623).withOpacity(0.2) : const Color(0xFF3AC2FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCalled ? const Color(0xFFF5A623).withOpacity(0.4) : const Color(0xFF3AC2FF).withOpacity(0.3),
              ),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: isCalled ? const Color(0xFFFFC880) : const Color(0xFF9BD9FF),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Actions Card
// ---------------------------------------------------------------------------
class QuickActionsCard extends StatelessWidget {
  final VoidCallback onServicesTap;
  final VoidCallback onQueueTap;
  final VoidCallback onQRTap;
  final VoidCallback onStaffTap;

  const QuickActionsCard({
    super.key,
    required this.onServicesTap,
    required this.onQueueTap,
    required this.onQRTap,
    required this.onStaffTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDAE2F8),
              ),
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionButton(
                  icon: Icons.medical_services_outlined,
                  label: 'Manage Services',
                  onTap: onServicesTap,
                ),
                _ActionButton(
                  icon: Icons.queue_play_next_outlined,
                  label: 'Live Queue',
                  onTap: onQueueTap,
                ),
                _ActionButton(
                  icon: Icons.qr_code_2,
                  label: 'Display QR',
                  onTap: onQRTap,
                ),
                _ActionButton(
                  icon: Icons.badge_outlined,
                  label: 'Manage Staff',
                  onTap: onStaffTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      opacity: 0.6,
      blur: 24,
      borderRadius: 8,
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFFC880), size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD7C3AE),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Activity Card
// ---------------------------------------------------------------------------
class RecentActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> recentTokens;

  const RecentActivityCard({
    super.key,
    required this.recentTokens,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDAE2F8),
                  ),
                ),
                Text(
                  '${recentTokens.length} active events',
                  style: const TextStyle(color: Color(0xFFD7C3AE), fontSize: 13),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          if (recentTokens.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No recent queue activity recorded yet today.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll(Color(0x22000000)),
                columns: const [
                  DataColumn(label: Text('EVENT', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1))),
                  DataColumn(label: Text('DESCRIPTION', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1))),
                  DataColumn(label: Text('TIME', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1))),
                ],
                rows: recentTokens.map((t) {
                  final status = (t['status'] ?? 'Waiting').toString().toLowerCase();
                  final tokenNum = t['tokenNumber']?.toString() ?? '-';
                  final serviceName = t['serviceName']?.toString() ?? 'Service';
                  final userName = t['userName']?.toString() ?? t['customerName']?.toString();
                  final timeAgo = _formatTimeAgo(t['joinedAt'] ?? t['createdAt'] ?? t['timestamp']);

                  IconData eventIcon;
                  Color eventColor;
                  String eventLabel;
                  String description;

                  if (status == 'completed') {
                    eventIcon = Icons.check_circle;
                    eventColor = Colors.greenAccent;
                    eventLabel = 'Completed';
                    description = 'Token $tokenNum completed $serviceName';
                  } else if (status == 'called' || status == 'serving') {
                    eventIcon = Icons.record_voice_over;
                    eventColor = const Color(0xFFFFC880);
                    eventLabel = 'Called';
                    description = 'Token $tokenNum called for $serviceName';
                  } else if (status == 'cancelled') {
                    eventIcon = Icons.cancel_outlined;
                    eventColor = Colors.redAccent;
                    eventLabel = 'Cancelled';
                    description = 'Token $tokenNum was cancelled';
                  } else {
                    eventIcon = Icons.person_add;
                    eventColor = const Color(0xFF9BD9FF);
                    eventLabel = 'Joined';
                    description = userName != null && userName.isNotEmpty
                        ? '$userName joined queue for $serviceName ($tokenNum)'
                        : 'New token generated for $serviceName ($tokenNum)';
                  }

                  return DataRow(cells: [
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(eventIcon, color: eventColor, size: 16),
                        const SizedBox(width: 8),
                        Text(eventLabel, style: const TextStyle(color: Color(0xFFDAE2F8), fontWeight: FontWeight.w600)),
                      ],
                    )),
                    DataCell(Text(description, style: const TextStyle(color: Color(0xFFD7C3AE)))),
                    DataCell(Text(timeAgo, style: const TextStyle(color: Color(0xFFD7C3AE), fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatTimeAgo(dynamic time) {
  if (time == null) return 'Just now';
  DateTime dt;
  if (time is Timestamp) {
    dt = time.toDate();
  } else if (time is DateTime) {
    dt = time;
  } else if (time is String) {
    dt = DateTime.tryParse(time) ?? DateTime.now();
  } else if (time is int) {
    dt = DateTime.fromMillisecondsSinceEpoch(time);
  } else {
    return 'Just now';
  }

  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}