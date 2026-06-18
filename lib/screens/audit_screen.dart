import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/database_service.dart';
import '../models/item.dart';
import '../services/auth_service.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final _databaseService = DatabaseService.instance;
  final _authService = AuthService();
  List<Item> _dueItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDueItems();
    _databaseService.itemsStream.listen((_) {
      _loadDueItems();
    });
  }

  Future<void> _loadDueItems() async {
    final items = await _databaseService.getItems();
    final due = items.where((i) => i.isAuditDue && i.status != 'In Service').toList();
    if (mounted) {
      setState(() {
        _dueItems = due;
        _isLoading = false;
      });
    }
  }

  void _showAuditFormDialog(Item item) {
    final formKey = GlobalKey<FormState>();
    final notesController = TextEditingController();
    String condition = 'Good';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Audit: ${item.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asset ID: ${item.id}', style: const TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(height: 16),
                const Text(
                  'Item Condition:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Good'),
                        selected: condition == 'Good',
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              condition = 'Good';
                            });
                          }
                        },
                        selectedColor: Colors.green,
                        labelStyle: TextStyle(
                          color: condition == 'Good' ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Need Repair'),
                        selected: condition == 'Requires Repair',
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              condition = 'Requires Repair';
                            });
                          }
                        },
                        selectedColor: Colors.redAccent,
                        labelStyle: TextStyle(
                          color: condition == 'Requires Repair' ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Audit Notes / Observations',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                final auditor = _authService.currentUserEmail ?? 'admin@church.org';
                await _databaseService.auditItem(
                  item.id,
                  auditor,
                  condition,
                  notesController.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.name} audited successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Submit Audit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the camera QR scanner. On a successful scan, looks up the item
  /// and triggers the audit form, or shows an error if ID not found.
  void _openQrScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QrScannerSheet(
        onScanned: (String code) async {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(ctx); // close scanner sheet
          final item = await _databaseService.getItemById(code.trim());
          if (item != null) {
            if (mounted) _showAuditFormDialog(item);
          } else {
            messenger.showSnackBar(
              SnackBar(
                content: Text('No item found with ID: $code'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('Audit Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // QR Scanner Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.blueAccent, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'QR Code Scanner',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Point your camera at an equipment QR label to begin an audit instantly.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text('Scan QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _openQrScanner,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Due List Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Items Pending Audit',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _dueItems.isNotEmpty ? Colors.redAccent.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _dueItems.isNotEmpty ? Colors.redAccent.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_dueItems.length} DUE',
                    style: TextStyle(
                      color: _dueItems.isNotEmpty ? Colors.redAccent : Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _dueItems.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: [
                          Icon(Icons.done_all, color: Colors.green, size: 48),
                          SizedBox(height: 8),
                          Text('Awesome! No audits pending.', style: TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _dueItems.length,
                    itemBuilder: (context, index) {
                      final item = _dueItems[index];
                      final lastAuditedStr = '${item.lastAudited.year}-${item.lastAudited.month.toString().padLeft(2, '0')}-${item.lastAudited.day.toString().padLeft(2, '0')}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.redAccent.withOpacity(0.15),
                              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'ID: ${item.id} • Last Audit: $lastAuditedStr',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.playlist_add_check, color: Colors.green),
                              tooltip: 'Audit Item',
                              onPressed: () => _showAuditFormDialog(item),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen camera sheet for scanning QR codes.
class _QrScannerSheet extends StatefulWidget {
  final void Function(String code) onScanned;
  const _QrScannerSheet({required this.onScanned});

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  bool _scanned = false;
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF475569),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan Equipment QR',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Camera preview
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) {
                      if (_scanned) return;
                      final barcode = capture.barcodes.firstOrNull;
                      final rawValue = barcode?.rawValue;
                      if (rawValue != null && rawValue.isNotEmpty) {
                        _scanned = true;
                        widget.onScanned(rawValue);
                      }
                    },
                  ),
                  // Scan frame overlay
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent, width: 2.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Instructions
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code, color: Color(0xFF94A3B8), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Align QR code within the frame',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
