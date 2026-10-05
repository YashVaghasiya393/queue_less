import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class HospitalQrScreen extends StatelessWidget {
  const HospitalQrScreen({super.key});

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
              'Business information was not found.',
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

            final String hospitalName =
                business['name'] ?? 'Sunrise Care Hospital';

            final String address =
                business['address'] ?? 'Indore, Madhya Pradesh';

            final bool isQueueOpen =
                business['isQueueOpen'] ?? business['isOpen'] ?? false;

            final bool isWide =
                MediaQuery.of(context).size.width > 950;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(isWide, hospitalName),
                  const SizedBox(height: 28),

                  _qrCard(
                    businessId: businessId,
                    hospitalName: hospitalName,
                    isQueueOpen: isQueueOpen,
                  ),
                  const SizedBox(height: 24),

                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _howItWorksCard()),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _detailsCard(
                            hospitalName: hospitalName,
                            address: address,
                            isQueueOpen: isQueueOpen,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _howItWorksCard(),
                        const SizedBox(height: 24),
                        _detailsCard(
                          hospitalName: hospitalName,
                          address: address,
                          isQueueOpen: isQueueOpen,
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),
                  _informationBanner(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _header(bool isWide , String hospitalName) {
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
              'QR Code',
              style: TextStyle(color: lightGold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Hospital QR Code',
          style: TextStyle(
            color: textColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        Text(
            'Let patients join the $hospitalName queue instantly by scanning this QR code.',
          style: const TextStyle(color: subTextColor, fontSize: 14),
        ),
      ],
    );

    final buttons = Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print QR Code'),
          style: OutlinedButton.styleFrom(
            foregroundColor: lightGold,
            side: BorderSide(color: Colors.white.withOpacity(0.18)),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download QR Code'),
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: const Color(0xFF1A1208),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
          ),
        ),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          buttons,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 18),
        buttons,
      ],
    );
  }

  Widget _qrCard({
    required String businessId,
    required String hospitalName,
    required bool isQueueOpen,
  }) {
    final statusColor = isQueueOpen
        ? const Color(0xFF4ADE80)
        : const Color(0xFFFF7B7B);

    return _glassCard(
      child: Center(
        child: Column(
          children: [
            const Text(
              'Scan to Join the Queue',
              style: TextStyle(
                color: textColor,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Patients can scan this QR code using the QueueLess app or their phone camera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 25),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: 'queueless://join?businessId=$businessId',
                version: QrVersions.auto,
                size: 260,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 22),
            Text(
              hospitalName,
              style: const TextStyle(
                color: lightGold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 4,
                    backgroundColor: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isQueueOpen ? 'QUEUE OPEN' : 'QUEUE CLOSED',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            const Text(
              'QR code is active and ready to scan.',
              style: TextStyle(
                color: subTextColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _howItWorksCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_scanner, color: lightGold),
              SizedBox(width: 10),
              Text(
                'How it works',
                style: TextStyle(
                  color: textColor,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          _step(
            number: '1',
            title: 'Patient scans the code',
            description:
            'Using their smartphone camera or the QueueLess app at reception.',
          ),
          const SizedBox(height: 20),
          _step(
            number: '2',
            title: 'QueueLess opens the hospital queue',
            description:
            'The app loads the live queue for Sunrise Care Hospital.',
          ),
          const SizedBox(height: 20),
          _step(
            number: '3',
            title: 'Patient receives a token',
            description:
            'The patient selects a service and receives their queue token.',
          ),
        ],
      ),
    );
  }

  Widget _step({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: gold.withOpacity(0.15),
          child: Text(
            number,
            style: const TextStyle(
              color: lightGold,
              fontWeight: FontWeight.bold,
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
                style: const TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: subTextColor,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailsCard({
    required String hospitalName,
    required String address,
    required bool isQueueOpen,
}) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: lightGold),
              SizedBox(width: 10),
              Text(
                'QR Code Details',
                style: TextStyle(
                  color: textColor,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _detailRow('Hospital', hospitalName),
          _detailRow('Location', address),
          _detailRow(
            'Queue status',
            isQueueOpen ? 'Open' : 'Closed',
            valueColor: isQueueOpen
                ? const Color(0xFF4ADE80)
                : const Color(0xFFFF7B7B),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
      String label,
      String value, {
        Color? valueColor,
        bool last = false,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: subTextColor,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withOpacity(0.20)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: lightGold),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Display this QR code at the reception, waiting area, and hospital entrance for faster patient check-in.',
              style: TextStyle(
                color: lightGold,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
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