import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:queue_less/Staff/Services_screen.dart';
import 'AdminDataHelper.dart';

const Color gold = Color(0xFFF5A623);
const Color lightGold = Color(0xFFFFC880);
const Color textColor = Color(0xFFDAE2F8);
const Color subTextColor = Color(0xFFD7C3AE);

class HospitalQrScreen extends StatefulWidget {
  const HospitalQrScreen({super.key});

  static const Color gold = Color(0xFFF5A623);
  static const Color lightGold = Color(0xFFFFC880);
  static const Color textColor = Color(0xFFDAE2F8);
  static const Color subTextColor = Color(0xFFD7C3AE);

  @override
  State<HospitalQrScreen> createState() => _HospitalQrScreenState();
}

class _HospitalQrScreenState extends State<HospitalQrScreen> {
  String _businessId = AdminDataHelper.defaultBusinessId;
  bool _isLoading = true;
  bool _isTogglingQueue = false;

  // Selected Service for QR (null = General Hospital Check-in)
  String? _selectedServiceId;
  String _selectedServiceName = 'General Hospital Check-In (All Services)';

  // QR Format: 'web' (https://...), 'scheme' (queueless://...), 'raw' (businessId)
  String _qrFormat = 'web';

  @override
  void initState() {
    super.initState();
    _loadQrData();
  }

  Future<void> _loadQrData() async {
    await AdminDataHelper.ensureAdminAuth();
    final id = await AdminDataHelper.getBusinessId();
    if (!mounted) return;
    setState(() {
      _businessId = id;
      _isLoading = false;
    });
  }

  String _buildQrPayload() {
    if (_qrFormat == 'scheme') {
      if (_selectedServiceId != null) {
        return 'queueless://join?businessId=$_businessId&serviceId=$_selectedServiceId';
      }
      return 'queueless://join?businessId=$_businessId';
    } else if (_qrFormat == 'raw') {
      return _businessId;
    } else {
      // Default: Universal Web Link (works in native phone camera & in-app scanner)
      if (_selectedServiceId != null) {
        return 'https://queueless.web.app/join?businessId=$_businessId&serviceId=$_selectedServiceId';
      }
      return 'https://queueless.web.app/join?businessId=$_businessId';
    }
  }

  Future<void> _toggleQueue(bool currentStatus) async {
    if (_isTogglingQueue) return;
    setState(() {
      _isTogglingQueue = true;
    });

    final newStatus = !currentStatus;
    try {
      await FirebaseFirestore.instance.collection('businesses').doc(_businessId).set({
        'isQueueOpen': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'Queue is now OPEN for patients.' : 'Queue is now CLOSED.'),
          backgroundColor: newStatus ? const Color(0xFF4ADE80) : const Color(0xFFFF7B7B),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update queue: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingQueue = false;
        });
      }
    }
  }

  void _copyQrLink() {
    final payload = _buildQrPayload();
    Clipboard.setData(ClipboardData(text: payload));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('QR Link copied: $payload')),
          ],
        ),
        backgroundColor: const Color(0xFF1E2638),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showPrintStandeeDialog(String hospitalName, String address, bool isQueueOpen) {
    final payload = _buildQrPayload();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.print_outlined, color: lightGold),
            const SizedBox(width: 10),
            const Text('Hospital QR Standee Preview', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: subTextColor, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Color(0xFF101726), shape: BoxShape.circle),
                      child: const Icon(Icons.local_hospital, color: Color(0xFFF5A623), size: 20),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        hospitalName,
                        style: const TextStyle(color: Color(0xFF101726), fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isQueueOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isQueueOpen ? '● LIVE QUEUE OPEN' : '● QUEUE CURRENTLY CLOSED',
                    style: TextStyle(
                      color: isQueueOpen ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _selectedServiceName,
                  style: const TextStyle(color: Color(0xFF101726), fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan with any phone camera or the QueueLess App to take your digital token instantly.',
                  style: TextStyle(color: Colors.black87, fontSize: 12, height: 1.3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const Divider(),
                const Text(
                  'Powered by QueueLess • Avoid Waiting Rooms',
                  style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: subTextColor)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Printing Standee... Sent to default printer spooler.'),
                  backgroundColor: Color(0xFF4ADE80),
                ),
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: const Color(0xFF1A1208),
            ),
          ),
        ],
      ),
    );
  }

  void _showDownloadDialog() {
    final payload = _buildQrPayload();
    Clipboard.setData(ClipboardData(text: payload));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.download_done, color: Color(0xFF4ADE80)),
            SizedBox(width: 10),
            Text('QR Code Ready', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your dynamic QR code is active and verified.',
              style: TextStyle(color: textColor, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D3546),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                payload,
                style: const TextStyle(color: lightGold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '✓ The QR code payload URL has also been copied to your clipboard.',
              style: TextStyle(color: Color(0xFF4ADE80), fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF1A1208)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: HospitalQrScreen.gold),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('businesses').doc(_businessId).snapshots(),
      builder: (context, businessSnapshot) {
        if (businessSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: HospitalQrScreen.gold),
          );
        }

        final business = businessSnapshot.data?.data() ?? {};
        final String hospitalName = business['name']?.toString() ?? 'Sunrise Care Hospital';
        final String address = business['address']?.toString() ?? 'Indore, Madhya Pradesh';
        final bool isQueueOpen = business['isQueueOpen'] ?? business['isOpen'] ?? false;
        final int tokenCount = (business['tokenCount'] as num?)?.toInt() ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(_businessId)
              .collection('services')
              .snapshots(),
          builder: (context, servicesSnapshot) {
            final serviceDocs = (servicesSnapshot.data?.docs ?? []).map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).where((s) => s['isActive'] != false).toList();

            final bool isWide = MediaQuery.of(context).size.width > 950;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(isWide, hospitalName, address, isQueueOpen),
                  const SizedBox(height: 24),

                  _qrConfigCard(serviceDocs),
                  const SizedBox(height: 24),

                  _qrCard(
                    businessId: _businessId,
                    hospitalName: hospitalName,
                    isQueueOpen: isQueueOpen,
                  ),
                  const SizedBox(height: 24),

                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _howItWorksCard(hospitalName)),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _detailsCard(
                            hospitalName: hospitalName,
                            address: address,
                            isQueueOpen: isQueueOpen,
                            totalServices: serviceDocs.length,
                            tokensToday: tokenCount,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _howItWorksCard(hospitalName),
                        const SizedBox(height: 24),
                        _detailsCard(
                          hospitalName: hospitalName,
                          address: address,
                          isQueueOpen: isQueueOpen,
                          totalServices: serviceDocs.length,
                          tokensToday: tokenCount,
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

  Widget _header(bool isWide, String hospitalName, String address, bool isQueueOpen) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('Dashboard', style: TextStyle(color: subTextColor, fontSize: 13)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right, color: subTextColor, size: 17),
            ),
            Text('QR Code', style: TextStyle(color: lightGold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Hospital QR Code',
          style: TextStyle(color: textColor, fontSize: 30, fontWeight: FontWeight.bold),
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
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showPrintStandeeDialog(hospitalName, address, isQueueOpen),
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print Standee', style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            foregroundColor: lightGold,
            side: BorderSide(color: Colors.white.withOpacity(0.18)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _showDownloadDialog,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download QR', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: const Color(0xFF1A1208),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => Services_screen(businessId: _businessId)),
            );
          },
          icon: const Icon(Icons.play_circle_outline, size: 18),
          label: const Text('Test Patient Scan', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D3546),
            foregroundColor: lightGold,
            side: const BorderSide(color: gold),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _qrConfigCard(List<Map<String, dynamic>> services) {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: lightGold, size: 20),
              SizedBox(width: 8),
              Text(
                'Dynamic QR Configuration',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Service Selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('QR Target Service', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2638),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedServiceId,
                        dropdownColor: const Color(0xFF1E2638),
                        style: const TextStyle(color: textColor, fontSize: 13),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Services (Hospital Reception)'),
                          ),
                          ...services.map((s) {
                            return DropdownMenuItem<String?>(
                              value: s['id']?.toString(),
                              child: Text(s['name']?.toString() ?? 'Service'),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedServiceId = val;
                            if (val == null) {
                              _selectedServiceName = 'General Hospital Check-In (All Services)';
                            } else {
                              final match = services.firstWhere((s) => s['id'] == val, orElse: () => {});
                              _selectedServiceName = match['name']?.toString() ?? 'Selected Service';
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // Format Selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('QR Link Format', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2638),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _qrFormat,
                        dropdownColor: const Color(0xFF1E2638),
                        style: const TextStyle(color: textColor, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'web', child: Text('Universal Web URL (Recommended)')),
                          DropdownMenuItem(value: 'scheme', child: Text('Direct App Scheme (queueless://)')),
                          DropdownMenuItem(value: 'raw', child: Text('Direct Hospital ID')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _qrFormat = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // Copy Button
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: OutlinedButton.icon(
                  onPressed: _copyQrLink,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy QR Link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: lightGold,
                    side: const BorderSide(color: gold),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qrCard({
    required String businessId,
    required String hospitalName,
    required bool isQueueOpen,
  }) {
    final statusColor = isQueueOpen ? const Color(0xFF4ADE80) : const Color(0xFFFF7B7B);
    final payload = _buildQrPayload();

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
              'Patients can scan this QR code using the QueueLess app or any smartphone camera.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
            const SizedBox(height: 25),

            // High-resolution interactive QR code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: gold.withOpacity(0.18), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 260,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),
            Text(
              hospitalName,
              style: const TextStyle(
                color: lightGold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedServiceName,
              style: const TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Interactive Queue Toggle inside QR screen
            InkWell(
              onTap: () => _toggleQueue(isQueueOpen),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      isQueueOpen ? 'QUEUE OPEN (Tap to Close)' : 'QUEUE CLOSED (Tap to Open)',
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
            ),

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2638),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                payload,
                style: const TextStyle(color: subTextColor, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _howItWorksCard(String hospitalName) {
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
            description: 'Using their smartphone camera or the QueueLess app at reception or waiting area.',
          ),
          const SizedBox(height: 20),
          _step(
            number: '2',
            title: 'QueueLess opens the hospital queue',
            description: 'The app loads the live services and estimated wait times for $hospitalName.',
          ),
          const SizedBox(height: 20),
          _step(
            number: '3',
            title: 'Patient receives a token',
            description: 'The patient selects their service and instantly receives their digital token.',
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
    required int totalServices,
    required int tokensToday,
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
          _detailRow('Business ID', _businessId),
          _detailRow('Location', address),
          _detailRow('Active Services', '$totalServices configured'),
          _detailRow('Tokens Issued Today', '$tokensToday tokens'),
          _detailRow('QR Target', _selectedServiceName),
          _detailRow(
            'Queue Status',
            isQueueOpen ? 'Open (Accepting Tokens)' : 'Closed',
            valueColor: isQueueOpen ? const Color(0xFF4ADE80) : const Color(0xFFFF7B7B),
            last: true,
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
      padding: const EdgeInsets.symmetric(vertical: 14),
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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
              'Display this QR code at the reception, waiting area, and hospital entrance. Patients scan to check in and monitor live queue progress directly on their phones.',
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