import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/item.dart';
import 'item_details_screen.dart';

class InventoryScreen extends StatefulWidget {
  final String? initialCategory; // 'Audio', 'Video', or null for All
  final String? initialStatus;   // 'In Service', 'Audit Due', or null for All

  const InventoryScreen({super.key, this.initialCategory, this.initialStatus});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _databaseService = DatabaseService.instance;
  List<Item> _items = [];
  bool _isLoading = true;

  String _searchQuery = '';
  late String _selectedCategory;
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'All';
    _selectedStatus = widget.initialStatus ?? 'All';
    _loadItems();
    _databaseService.itemsStream.listen((updatedItems) {
      if (mounted) {
        setState(() {
          _items = updatedItems;
        });
      }
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

  List<Item> get _filteredItems {
    return _items.where((item) {
      // Search matches
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.brand.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.model.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.serialNumber.toLowerCase().contains(_searchQuery.toLowerCase());
          
      // Category matches
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;

      // Status matches
      bool matchesStatus = true;
      if (_selectedStatus != 'All') {
        if (_selectedStatus == 'Available') {
          matchesStatus = item.status == 'Available';
        } else if (_selectedStatus == 'In Service') {
          matchesStatus = item.status == 'In Service';
        } else if (_selectedStatus == 'Audit Due') {
          matchesStatus = item.isAuditDue && item.status != 'In Service';
        }
      }

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Equipment Inventory',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Panel
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search items by name, model, ID...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Category Selector
                Row(
                  children: [
                    const Text(
                      'Category:',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['All', 'Audio', 'Video'].map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedCategory = cat;
                                    });
                                  }
                                },
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                ),
                                selectedColor: Colors.blueAccent,
                                backgroundColor: const Color(0xFF0F172A),
                                checkmarkColor: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                
                // Status Selector
                Row(
                  children: [
                    const Text(
                      'Status:    ',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['All', 'Available', 'In Service', 'Audit Due'].map((stat) {
                            final isSelected = _selectedStatus == stat;
                            Color activeColor = Colors.blueAccent;
                            if (stat == 'In Service') activeColor = Colors.amber;
                            if (stat == 'Audit Due') activeColor = Colors.redAccent;
                            
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(stat),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedStatus = stat;
                                    });
                                  }
                                },
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                ),
                                selectedColor: activeColor,
                                backgroundColor: const Color(0xFF0F172A),
                                checkmarkColor: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // List View
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: const Color(0xFF334155)),
                        const SizedBox(height: 12),
                        const Text(
                          'No items found matching the filters.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF334155), width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ItemDetailsScreen(itemId: item.id),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: item.category == 'Audio'
                                ? Colors.teal.withOpacity(0.15)
                                : Colors.purple.withOpacity(0.15),
                            child: Icon(
                              item.category == 'Audio' ? Icons.volume_up : Icons.videocam,
                              color: item.category == 'Audio' ? Colors.tealAccent : Colors.purpleAccent,
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${item.id} • S/N: ${item.serialNumber}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${item.brand} ${item.model}',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  ),
                                  if (item.isAuditDue && item.status != 'In Service') ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'AUDIT DUE',
                                        style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildStatusBadge(item.status),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, color: Color(0xFF475569)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
}
