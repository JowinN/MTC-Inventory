import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/database_service.dart';
import '../models/item.dart';
import '../services/notification_service.dart';
class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  final _databaseService = DatabaseService.instance;
  List<Item> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _databaseService.itemsStream.listen((_) {
      _loadItems();
    });
  }

  Future<void> _loadItems() async {
    final items = await _databaseService.getItems();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  List<Item> get _itemsInService =>
      _items.where((i) => i.inServiceQuantity > 0).toList();

  void _showSendToServiceForm(Item item) {
    final formKey = GlobalKey<FormState>();
    final issueController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    DateTime expectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Dispatch: ${item.name}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asset ID: ${item.id}',
                    style: const TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(height: 16),
                TextFormField(
                  controller: issueController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Describe Issue',
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
                  maxLines: 2,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Issue description is required';
                    }
                    return null;
                  },
                ),
                if (item.quantity > 1) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity to Send (Max: ${item.quantity - item.inServiceQuantity})',
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
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Quantity is required';
                      final q = int.tryParse(val);
                      if (q == null || q < 1) return 'Must be >= 1';
                      if (q > (item.quantity - item.inServiceQuantity)) {
                        return 'Cannot exceed available quantity';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expected Return:',
                        style: TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13)),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today,
                          size: 16, color: Colors.blueAccent),
                      label: Text(
                        '${expectedDate.year}-${expectedDate.month.toString().padLeft(2, '0')}-${expectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: expectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            expectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await _databaseService.sendToService(
                    item.id,
                    issueController.text.trim(),
                    expectedDate,
                    int.tryParse(quantityController.text.trim()) ?? 1,
                  );
                  await NotificationService().scheduleServiceReturnNotification(
                    itemId: item.id,
                    itemName: item.name,
                    expectedDate: expectedDate,
                  );
                  if (ctx.mounted && mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item.name} sent to service log.'),
                        backgroundColor: Colors.amber,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to dispatch item: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: const Text('Submit Dispatch',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReturnFromServiceForm(Item item) async {
    final history = await _databaseService.getServiceHistory(item.id);
    final openRecords = history.where((rec) => !rec.isReturned).toList();
    if (openRecords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No open service record found for ${item.name}.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    final activeRecord = openRecords.first;
    final formKey = GlobalKey<FormState>();
    final resolutionController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Receive: ${item.name}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reported Issue: ${activeRecord.issueDescription}',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(height: 16),
              TextFormField(
                controller: resolutionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Resolution / Repair Notes',
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
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please describe the resolution';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await _databaseService.returnFromService(
                  item.id,
                  activeRecord.id,
                  resolutionController.text.trim(),
                );
                await NotificationService().cancelScheduledNotification(item.id);
                if (ctx.mounted && mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.name} is back in inventory!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to return item from service: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Submit Return',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Opens the QR scanner. [mode] is either 'send' or 'receive'.
  void _openQrScanner(String mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QrScannerSheet(
        title: mode == 'send' ? 'Scan to Send to Service' : 'Scan to Receive Item',
        onScanned: (String code) async {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(ctx);
          final item = await _databaseService.getItemById(code.trim());
          if (item == null) {
            messenger.showSnackBar(SnackBar(
              content: Text('No item found with ID: $code'),
              backgroundColor: Colors.redAccent,
            ));
            return;
          }
          if (mode == 'send') {
            if (item.availableQty <= 0) {
              messenger.showSnackBar(SnackBar(
                content: Text('${item.name} is not available (all units checked out).'),
                backgroundColor: Colors.orange,
              ));
              return;
            }
            if (mounted) _showSendToServiceForm(item);
          } else {
            if (item.inServiceQuantity <= 0) {
              messenger.showSnackBar(SnackBar(
                content: Text('${item.name} is not currently in service.'),
                backgroundColor: Colors.orange,
              ));
              return;
            }
            if (mounted) _showReturnFromServiceForm(item);
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
        body: Center(
            child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    final inService = _itemsInService;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: const Text('Service Manager',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Color(0xFF94A3B8),
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'QR Scanner'),
              Tab(icon: Icon(Icons.engineering), text: 'Currently In Service'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: QR Scanner
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Send to Service
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.output_rounded,
                                color: Colors.amber, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Send Item to Service',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Scan an item\'s QR code to dispatch it for repair or servicing.',
                          style: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.white),
                            label: const Text('Scan QR — Send to Service',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _openQrScanner('send'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Receive from Service
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.input_rounded,
                                color: Colors.green, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Receive Item from Service',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Scan a returned item\'s QR code to log it back into inventory.',
                          style: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.white),
                            label: const Text('Scan QR — Receive Item',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _openQrScanner('receive'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab 2: Currently in Service list
            inService.isEmpty
                ? const Center(
                    child: Text(
                        'No items are currently undergoing servicing.',
                        style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: inService.length,
                    itemBuilder: (context, index) {
                      final item = inService[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  Colors.amber.withOpacity(0.15),
                              child: const Icon(Icons.engineering,
                                  color: Colors.amber),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'ID: ${item.id} • Model: ${item.model}',
                                    style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12),
                                  ),
                                  if (item.quantity > 1)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'In Service: ${item.inServiceQuantity} / ${item.quantity}',
                                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.assignment_turned_in,
                                  color: Colors.blueAccent),
                              tooltip: 'Receive Item',
                              onPressed: () =>
                                  _showReturnFromServiceForm(item),
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

/// Reusable camera QR scanner bottom sheet.
class _QrScannerSheet extends StatefulWidget {
  final String title;
  final void Function(String code) onScanned;

  const _QrScannerSheet({required this.title, required this.onScanned});

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
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF475569),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
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
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.blueAccent, width: 2.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.qr_code, color: Color(0xFF94A3B8), size: 18),
                SizedBox(width: 8),
                Text(
                  'Align QR code within the frame',
                  style:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
