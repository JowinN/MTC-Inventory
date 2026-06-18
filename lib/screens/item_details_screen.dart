import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/database_service.dart';
import '../models/item.dart';
import '../models/audit_record.dart';
import '../models/service_record.dart';
import '../services/auth_service.dart';
import '../utils/qr_downloader.dart';

class ItemDetailsScreen extends StatefulWidget {
  final String itemId;
  const ItemDetailsScreen({super.key, required this.itemId});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  final _databaseService = DatabaseService.instance;
  final _authService = AuthService();
  Item? _item;
  List<AuditRecord> _auditHistory = [];
  List<ServiceRecord> _serviceHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _databaseService.itemsStream.listen((_) {
      _loadDetails();
    });
  }

  Future<void> _loadDetails() async {
    final item = await _databaseService.getItemById(widget.itemId);
    if (item != null) {
      final audits = await _databaseService.getAuditHistory(widget.itemId);
      final services = await _databaseService.getServiceHistory(widget.itemId);
      if (mounted) {
        setState(() {
          _item = item;
          _auditHistory = audits;
          _serviceHistory = services;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleDownloadQR() async {
    try {
      final path = await saveAndDownloadQr(widget.itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR Code saved at:\n$path'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAuditDialog() {
    final formKey = GlobalKey<FormState>();
    final notesController = TextEditingController();
    String condition = 'Good'; // Good or Requires Repair

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Audit Equipment', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Item Condition:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                    labelText: 'Audit Notes',
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
                  widget.itemId,
                  auditor,
                  condition,
                  notesController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Audit recorded successfully!'),
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

  void _showSendToServiceDialog() {
    final formKey = GlobalKey<FormState>();
    final issueController = TextEditingController();
    DateTime expectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Send to Service', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    if (val == null || val.isEmpty) return 'Issue description is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expected Return:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16, color: Colors.blueAccent),
                      label: Text(
                        '${expectedDate.year}-${expectedDate.month.toString().padLeft(2, '0')}-${expectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: expectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
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
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await _databaseService.sendToService(
                  widget.itemId,
                  issueController.text.trim(),
                  expectedDate,
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item marked as In Service!'),
                      backgroundColor: Colors.amber,
                    ),
                  );
                }
              },
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReturnFromServiceDialog(ServiceRecord record) {
    final formKey = GlobalKey<FormState>();
    final resolutionController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Return from Service', style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: TextFormField(
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
              if (val == null || val.isEmpty) return 'Please describe the resolution';
              return null;
            },
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
              if (!formKey.currentState!.validate()) return;
              await _databaseService.returnFromService(
                widget.itemId,
                record.id,
                resolutionController.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Item returned to Inventory!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Submit Return', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirm Delete', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${_item?.name}"? This action is permanent and cannot be undone.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              setState(() {
                _isLoading = true;
              });
              try {
                await _databaseService.deleteItem(widget.itemId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${_item?.name}" has been deleted.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  Navigator.pop(context); // Go back to previous screen
                }
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Delete failed: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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

    if (_item == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: Text('Item not found.', style: TextStyle(color: Colors.white))),
      );
    }

    final item = _item!;
    final nextAuditText = '${item.nextAuditDue.year}-${item.nextAuditDue.month.toString().padLeft(2, '0')}-${item.nextAuditDue.day.toString().padLeft(2, '0')}';
    final lastAuditText = '${item.lastAudited.year}-${item.lastAudited.month.toString().padLeft(2, '0')}-${item.lastAudited.day.toString().padLeft(2, '0')}';
    final addedDateText = '${item.addedDate.year}-${item.addedDate.month.toString().padLeft(2, '0')}-${item.addedDate.day.toString().padLeft(2, '0')}';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Color(0xFF94A3B8),
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(icon: Icon(Icons.info), text: 'Info & QR'),
              Tab(icon: Icon(Icons.check_circle), text: 'Audits'),
              Tab(icon: Icon(Icons.history), text: 'Services'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Info & QR
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // QR and State Block
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // QR Code container
                      GestureDetector(
                        onTap: _handleDownloadQR,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF334155), width: 1),
                          ),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              QrImageView(
                                data: item.id,
                                version: QrVersions.auto,
                                size: 120.0,
                              ),
                              const Icon(Icons.download, color: Color(0xFF334155), size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Meta Information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.category.toUpperCase(),
                              style: TextStyle(
                                color: item.category == 'Audio' ? Colors.tealAccent : Colors.purpleAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.name,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _buildStatusBadge(item.status),
                            const SizedBox(height: 12),
                            if (item.isAuditDue && item.status != 'In Service')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning, color: Colors.redAccent, size: 16),
                                    SizedBox(width: 6),
                                    Text('Audit Overdue!', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code, color: Colors.white),
                          label: const Text('Audit Now', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: item.status == 'In Service' ? null : _showAuditDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: item.status == 'In Service'
                            ? ElevatedButton.icon(
                                icon: const Icon(Icons.assignment_turned_in, color: Colors.white),
                                label: const Text('Return', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  final activeRecord = _serviceHistory.firstWhere((rec) => !rec.isReturned);
                                  _showReturnFromServiceDialog(activeRecord);
                                },
                              )
                            : ElevatedButton.icon(
                                icon: const Icon(Icons.build, color: Colors.white),
                                label: const Text('Send Service', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _showSendToServiceDialog,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Spec Card details
                  const Text('Specifications', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildSpecTable([
                    {'Label': 'Unique Asset ID', 'Value': item.id},
                    {'Label': 'Brand', 'Value': item.brand},
                    {'Label': 'Model', 'Value': item.model},
                    {'Label': 'Serial Number', 'Value': item.serialNumber},
                    {'Label': 'Added Date', 'Value': addedDateText},
                    {'Label': 'Last Audited', 'Value': lastAuditText},
                    {'Label': 'Next Audit Due', 'Value': nextAuditText},
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDeleteItem(context),
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      label: const Text('Delete Asset', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.redAccent.withOpacity(0.05),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Tab 2: Audit History
            _auditHistory.isEmpty
                ? const Center(child: Text('No audit history recorded.', style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _auditHistory.length,
                    itemBuilder: (context, index) {
                      final aud = _auditHistory[index];
                      final dateStr = '${aud.auditDate.year}-${aud.auditDate.month.toString().padLeft(2, '0')}-${aud.auditDate.day.toString().padLeft(2, '0')}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateStr,
                                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: aud.condition == 'Good' ? Colors.green.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    aud.condition.toUpperCase(),
                                    style: TextStyle(
                                      color: aud.condition == 'Good' ? Colors.green : Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Auditor: ${aud.auditorEmail}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                              aud.notes.isEmpty ? 'No comments left.' : 'Notes: ${aud.notes}',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            
            // Tab 3: Service History
            _serviceHistory.isEmpty
                ? const Center(child: Text('No service history recorded.', style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _serviceHistory.length,
                    itemBuilder: (context, index) {
                      final serv = _serviceHistory[index];
                      final sentStr = '${serv.sentDate.year}-${serv.sentDate.month.toString().padLeft(2, '0')}-${serv.sentDate.day.toString().padLeft(2, '0')}';
                      final expStr = '${serv.expectedReturnDate.year}-${serv.expectedReturnDate.month.toString().padLeft(2, '0')}-${serv.expectedReturnDate.day.toString().padLeft(2, '0')}';
                      final retStr = serv.actualReturnDate != null
                          ? '${serv.actualReturnDate!.year}-${serv.actualReturnDate!.month.toString().padLeft(2, '0')}-${serv.actualReturnDate!.day.toString().padLeft(2, '0')}'
                          : 'In Service';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  sentStr,
                                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: serv.isReturned ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    serv.isReturned ? 'RETURNED' : 'IN SERVICE',
                                    style: TextStyle(
                                      color: serv.isReturned ? Colors.green : Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Issue: ${serv.issueDescription}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text('Expected Return: $expStr', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            if (serv.isReturned) ...[
                              Text('Returned: $retStr', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              const SizedBox(height: 6),
                              Text('Resolution: ${serv.resolutionNotes}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                            ],
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

  Widget _buildStatusBadge(String status) {
    Color color = Colors.green;
    if (status == 'In Service') {
      color = Colors.amber;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSpecTable(List<Map<String, String>> specs) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: specs.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155), height: 1),
        itemBuilder: (ctx, idx) {
          final spec = specs[idx];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(spec['Label']!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ),
                Expanded(
                  flex: 4,
                  child: Text(spec['Value']!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
