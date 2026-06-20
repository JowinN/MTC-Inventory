import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../models/item.dart';
import '../models/service_record.dart';
import 'login_screen.dart';
import 'inventory_screen.dart';
import 'add_item_screen.dart';
import 'audit_screen.dart';
import 'service_screen.dart';
import 'item_details_screen.dart';
import 'events_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _databaseService = DatabaseService.instance;
  final _authService = AuthService();
  List<Item> _items = [];
  List<ServiceRecord> _activeServiceRecords = [];
  bool _isLoading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    // Request notification permissions
    NotificationService().requestPermissions();

    // Subscribe to state changes in real-time
    _databaseService.itemsStream.listen((updatedItems) {
      if (mounted) {
        setState(() {
          _items = updatedItems;
          _isLoading = false;
        });
        _loadActiveServiceRecords();
      }
    });

    // Subscribe to connectivity changes
    ConnectivityService().isConnected.then((connected) {
      if (mounted) {
        setState(() {
          _isOnline = connected;
        });
      }
    });
    ConnectivityService().connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isOnline = connected;
        });
      }
    });
  }

  Future<void> _loadActiveServiceRecords() async {
    final records = await _databaseService.getAllActiveServiceRecords();
    if (mounted) {
      setState(() {
        _activeServiceRecords = records;
      });
    }
  }

  Widget _buildNotificationBell() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdueOrDueRecords = _activeServiceRecords.where((rec) {
      final expectedDate = rec.expectedReturnDate;
      final expectedDay = DateTime(expectedDate.year, expectedDate.month, expectedDate.day);
      return expectedDay.isBefore(today) || expectedDay.isAtSameMomentAs(today);
    }).toList();
    final count = overdueOrDueRecords.length;

    return Badge(
      isLabelVisible: count > 0,
      label: Text(count.toString()),
      backgroundColor: Colors.redAccent,
      child: IconButton(
        icon: Icon(
          count > 0 ? Icons.notifications_active : Icons.notifications_none,
          color: count > 0 ? Colors.amberAccent : Colors.white,
        ),
        tooltip: 'Service Return Alerts',
        onPressed: () => _showNotificationsBottomSheet(overdueOrDueRecords),
      ),
    );
  }

  void _showNotificationsBottomSheet(List<ServiceRecord> records) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Service Return Alerts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  records.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              'No pending service returns due today or overdue.',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        )
                      : Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: records.length,
                            itemBuilder: (ctx, index) {
                              final record = records[index];
                              final item = _items.firstWhere(
                                (i) => i.id == record.itemId,
                                orElse: () => Item(
                                  id: record.itemId,
                                  name: 'Unknown Item',
                                  category: 'Audio',
                                  brand: '',
                                  model: '',
                                  serialNumber: '',
                                  status: 'In Service',
                                  lastAudited: DateTime.now(),
                                  nextAuditDue: DateTime.now(),
                                  addedDate: DateTime.now(),
                                ),
                              );

                              final now = DateTime.now();
                              final today = DateTime(now.year, now.month, now.day);
                              final expectedDay = DateTime(
                                record.expectedReturnDate.year,
                                record.expectedReturnDate.month,
                                record.expectedReturnDate.day,
                              );
                              final isOverdue = expectedDay.isBefore(today);
                              final daysDiff = today.difference(expectedDay).inDays;

                              String subtitle = 'Expected return: ${record.expectedReturnDate.year}-${record.expectedReturnDate.month.toString().padLeft(2, '0')}-${record.expectedReturnDate.day.toString().padLeft(2, '0')}';
                              if (isOverdue) {
                                subtitle += ' ($daysDiff days overdue)';
                              } else {
                                subtitle += ' (Due Today)';
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isOverdue
                                        ? Colors.redAccent.withOpacity(0.3)
                                        : Colors.amberAccent.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: (isOverdue
                                              ? Colors.redAccent
                                              : Colors.amberAccent)
                                          .withOpacity(0.15),
                                      child: Icon(
                                        isOverdue ? Icons.warning : Icons.alarm,
                                        color: isOverdue
                                            ? Colors.redAccent
                                            : Colors.amberAccent,
                                      ),
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
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            subtitle,
                                            style: TextStyle(
                                              color: isOverdue
                                                  ? Colors.redAccent.shade100
                                                  : Colors.amberAccent.shade100,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.assignment_returned,
                                        color: Colors.greenAccent,
                                      ),
                                      tooltip: 'Receive Item',
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showReturnFromServiceForm(item, record);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReturnFromServiceForm(Item item, ServiceRecord activeRecord) {
    final formKey = GlobalKey<FormState>();
    final resolutionController = TextEditingController();

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

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    final totalItems = _items.length;
    final audioItems = _items.where((i) => i.category == 'Audio').length;
    final videoItems = _items.where((i) => i.category == 'Video').length;
    final itemsInService = _items.where((i) => i.inServiceQuantity > 0).length;
    final overdueAudits = _items.where((i) => i.isAuditDue && i.inServiceQuantity < i.quantity).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
        title: const Text(
          'MTC Inventory',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          _buildNotificationBell(),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Sign Out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                    Text(
                      _authService.currentUserName ?? _authService.currentUserEmail ?? 'Admin User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_isOnline ? Colors.green : Colors.redAccent).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (_isOnline ? Colors.green : Colors.redAccent).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(_isOnline ? Icons.wifi : Icons.wifi_off, color: _isOnline ? Colors.green : Colors.redAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: TextStyle(color: _isOnline ? Colors.green : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statistics Section
            const Text(
              'Overview Stats',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Stat Cards Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              children: [
                _buildStatCard(
                  title: 'Total Items',
                  value: totalItems.toString(),
                  icon: Icons.inventory_2_outlined,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InventoryScreen()),
                  ),
                ),
                _buildStatCard(
                  title: 'In Service',
                  value: itemsInService.toString(),
                  icon: Icons.build_circle_outlined,
                  color: Colors.amber,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InventoryScreen(initialStatus: 'In Service')),
                  ),
                ),
                _buildStatCard(
                  title: 'Audio Items',
                  value: audioItems.toString(),
                  icon: Icons.volume_up_outlined,
                  color: Colors.teal,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InventoryScreen(initialCategory: 'Audio')),
                  ),
                ),
                _buildStatCard(
                  title: 'Video Items',
                  value: videoItems.toString(),
                  icon: Icons.videocam_outlined,
                  color: Colors.purpleAccent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InventoryScreen(initialCategory: 'Video')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Overdue Alert Banner (if any)
            if (overdueAudits > 0)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuditScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7F1D1D), Color(0xFF991B1B)], // Deep Red Gradients
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Audit Required',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '$overdueAudits items are due for their monthly audit.',
                              style: TextStyle(color: Colors.red.shade100, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // Quick Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Add Item',
                    icon: Icons.add,
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddItemScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: 'Inventory',
                    icon: Icons.list_alt,
                    color: const Color(0xFF334155),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const InventoryScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Audit Center',
                    icon: Icons.qr_code_scanner,
                    color: overdueAudits > 0 ? Colors.redAccent : const Color(0xFF334155),
                    badgeCount: overdueAudits > 0 ? overdueAudits : null,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuditScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: 'Service Log',
                    icon: Icons.build,
                    color: itemsInService > 0 ? Colors.amber : const Color(0xFF334155),
                    badgeCount: itemsInService > 0 ? itemsInService : null,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ServiceScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'External Events',
                    icon: Icons.event,
                    color: const Color(0xFF334155),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EventsListScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: const SizedBox.shrink()),
              ],
            ),
            
            const SizedBox(height: 28),
            
            // Recent Items list preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Assets',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const InventoryScreen()),
                    );
                  },
                  child: const Text('View All', style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length > 3 ? 3 : _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ItemDetailsScreen(itemId: item.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: item.category == 'Audio'
                                ? Colors.teal.withOpacity(0.2)
                                : Colors.purple.withOpacity(0.2),
                            child: Icon(
                              item.category == 'Audio' ? Icons.volume_up : Icons.videocam,
                              color: item.category == 'Audio' ? Colors.tealAccent : Colors.purpleAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'ID: ${item.id} • ${item.brand} ${item.model}',
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(item),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF334155), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Icon(icon, color: color, size: 22),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color == Colors.blueAccent ? color : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color == Colors.blueAccent ? Colors.transparent : const Color(0xFF334155),
              width: 1,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (badgeCount != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Item item) {
    final status = item.computedStatus;
    Color color = Colors.green;
    if (status.contains('Service') && status.contains('Event')) {
      color = Colors.purpleAccent;
    } else if (status.contains('Service')) {
      color = Colors.amber;
    } else if (status.contains('Event')) {
      color = Colors.indigoAccent;
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
}
