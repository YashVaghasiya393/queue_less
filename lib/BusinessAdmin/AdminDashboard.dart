import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:queue_less/BusinessAdmin/QRScreen.dart';
import 'package:queue_less/BusinessAdmin/StaffScreen.dart';

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
  // 0 = Dashboard
  // 1 = Services

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
    return Column(
      children: [
        if (!isDesktop) const MobileAppBar(),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 32 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HeaderSection(),
                    const SizedBox(height: 24),
                    const SummaryCardsGrid(),
                    const SizedBox(height: 24),

                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            flex: 8,
                            child: QueueSnapshotCard(),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: QuickActionsCard(
                              onServicesTap: () => changePage(1),
                              onQueueTap: () => changePage(2),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          const QueueSnapshotCard(),
                          const SizedBox(height: 24),
                          QuickActionsCard(
                            onServicesTap: () => changePage(1),
                            onQueueTap: () => changePage(2),
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),
                    const RecentActivityCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    foregroundColor: const Color(0xFF452B00),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('VIEW LIVE QUEUE'),
                ),
                const SizedBox(height: 12),
                const _NavItem(icon: Icons.help_outline, label: 'Help'),
                const _NavItem(icon: Icons.logout, label: 'Logout'),
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
  const MobileAppBar({super.key});

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
          const Text('QueueLess', style: TextStyle(color: Color(0xFFFFC880), fontSize: 20, fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.notifications_none, color: Color(0xFFFFC880)), onPressed: () {}),
              IconButton(icon: const Icon(Icons.menu, color: Color(0xFFFFC880)), onPressed: () {}),
            ],
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header Section
// ---------------------------------------------------------------------------
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 768;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                text: 'Good morning, Dr. Sharma ',
                style: TextStyle(
                  fontSize: isDesktop ? 34 : 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDAE2F8),
                ),
                children: const [
                  TextSpan(text: '👋', style: TextStyle(color: Color(0xFFFFC880))),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Here is today’s queue overview for Sunrise Care Hospital.',
              style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 16),
            ),
          ],
        ),
        if (isDesktop)
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_none, color: Color(0xFFFFC880)),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {},
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
  const SummaryCardsGrid({super.key});

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
      children: const [
        _SummaryCard(
          title: "TODAY'S TOKENS",
          value: "48",
          subValue: "+12%",
          subColor: Color(0xFF9BD9FF),
          icon: Icons.confirmation_number_outlined,
        ),
        _SummaryCard(
          title: "WAITING NOW",
          value: "12",
          subValue: "Avg 18m",
          subColor: Color(0xFFD7C3AE),
          valueColor: Color(0xFFFFC880),
          icon: Icons.group_outlined,
        ),
        _SummaryCard(
          title: "ACTIVE SERVICES",
          value: "4",
          icon: Icons.spa_outlined,
        ),
        _SummaryCard(
          title: "STAFF ON DUTY",
          value: "6",
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
  const QueueSnapshotCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Queue Snapshot', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFDAE2F8))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9BD9FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF9BD9FF).withOpacity(0.3)),
                  ),
                  child: const Text('Queue is Open', style: TextStyle(color: Color(0xFF9BD9FF), fontSize: 12, fontWeight: FontWeight.w600)),
                )
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CURRENT: A-034 | NEXT: A-035', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('12 WAITING', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 8,
                    color: const Color(0xFF2D3546),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 280,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC880),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFF5A623).withOpacity(0.5), blurRadius: 10, spreadRadius: 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _TokenItem(token: 'A-035', title: 'Doctor Consultation', subtitle: 'Joined 5 mins ago', status: 'Waiting'),
                const _TokenItem(token: 'A-036', title: 'Laboratory Test', subtitle: 'Joined 2 mins ago', status: 'Waiting'),
                const _TokenItem(
                  token: 'A-037',
                  title: 'Pharmacy',
                  subtitle: 'Called to Counter 1',
                  status: 'Called',
                  isCalled: true,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {},
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
          Row(
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCalled ? const Color(0xFF452B00) : const Color(0xFFDAE2F8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFFDAE2F8), fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFFD7C3AE), fontSize: 12)),
                ],
              ),
            ],
          ),
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

  const QuickActionsCard({
    super.key,
    required this.onServicesTap, required this.onQueueTap,
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
                  icon: Icons.add_circle_outline,
                  label: 'Add Service',
                  onTap: onServicesTap,
                ),
                _ActionButton(
                  icon: Icons.lock_open,
                  label: 'Open / Close Queue',
                  onTap: onQueueTap,
                ),
                _ActionButton(
                  icon: Icons.qr_code_2,
                  label: 'Generate QR',
                  onTap: () {},
                ),
                _ActionButton(
                  icon: Icons.person_add_outlined,
                  label: 'Add Staff',
                  onTap: () {},
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
  const RecentActivityCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFDAE2F8))),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Color(0xFFFFC880)),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(Color(0x22000000)),
              columns: const [
                DataColumn(label: Text('EVENT', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1))),
                DataColumn(label: Text('DESCRIPTION', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1))),
                DataColumn(label: Text('TIME', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1))),
              ],
              rows: const [
                DataRow(cells: [
                  DataCell(Row(children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                    SizedBox(width: 6),
                    Text('Completed', style: TextStyle(color: Color(0xFFDAE2F8))),
                  ])),
                  DataCell(Text('Token A-012 completed service', style: TextStyle(color: Color(0xFFD7C3AE)))),
                  DataCell(Text('2 min ago', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 12))),
                ]),
                DataRow(cells: [
                  DataCell(Row(children: [
                    Icon(Icons.record_voice_over, color: Color(0xFFFFC880), size: 16),
                    SizedBox(width: 6),
                    Text('Called', style: TextStyle(color: Color(0xFFDAE2F8))),
                  ])),
                  DataCell(Text('Riya called token A-015', style: TextStyle(color: Color(0xFFD7C3AE)))),
                  DataCell(Text('5 min ago', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 12))),
                ]),
                DataRow(cells: [
                  DataCell(Row(children: [
                    Icon(Icons.person_add, color: Color(0xFF9BD9FF), size: 16),
                    SizedBox(width: 6),
                    Text('Joined', style: TextStyle(color: Color(0xFFDAE2F8))),
                  ])),
                  DataCell(Text('New customer joined for Haircut (A-016)', style: TextStyle(color: Color(0xFFD7C3AE)))),
                  DataCell(Text('10 min ago', style: TextStyle(color: Color(0xFFD7C3AE), fontSize: 12))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}