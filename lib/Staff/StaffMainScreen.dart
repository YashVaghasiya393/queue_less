import 'package:flutter/material.dart';

import '../QueueManagement.dart';
import 'StaffDashboardScreen.dart';
class StaffMainScreen extends StatefulWidget {
  const StaffMainScreen({super.key});

  @override
  State<StaffMainScreen> createState() => _StaffMainScreenState();
}

class _StaffMainScreenState extends State<StaffMainScreen> {
  int selectedPage = 0;

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
          child: Row(
            children: [
              if (isDesktop)
                StaffSideBar(
                  selectedPage: selectedPage,
                  onPageSelected: changePage,
                ),

              Expanded(
                child: selectedPage == 0
                    ? const StaffDashboardScreen()
                    : const QueueManagementScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StaffSideBar extends StatelessWidget {
  final int selectedPage;
  final Function(int) onPageSelected;

  const StaffSideBar({
    super.key,
    required this.selectedPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF17202F).withOpacity(0.45),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.confirmation_number_rounded,
                  color: Color(0xFF1A1208),
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
                    'Staff Portal',
                    style: TextStyle(
                      color: Color(0xFFD7C3AE),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 35),

          _sideItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            selected: selectedPage == 0,
            onTap: () => onPageSelected(0),
          ),

          _sideItem(
            icon: Icons.queue_outlined,
            label: 'Queue Management',
            selected: selectedPage == 1,
            onTap: () => onPageSelected(1),
          ),

          const Spacer(),

          _sideItem(
            icon: Icons.logout_outlined,
            label: 'Logout',
            selected: false,
            onTap: () {},
          ),

          const Divider(color: Color(0x33FFFFFF)),

          const Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Color(0xFF2D3546),
                child: Icon(
                  Icons.person,
                  color: Color(0xFFFFC880),
                ),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Riya Sharma',
                    style: TextStyle(
                      color: Color(0xFFDAE2F8),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Reception Staff',
                    style: TextStyle(
                      color: Color(0xFFD7C3AE),
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

  Widget _sideItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFC880).withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected
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
            leading: Icon(
              icon,
              color: selected
                  ? const Color(0xFFFFC880)
                  : const Color(0xFFD7C3AE),
            ),
            title: Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFFFC880)
                    : const Color(0xFFD7C3AE),
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}