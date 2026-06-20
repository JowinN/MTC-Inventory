import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/item.dart';
import '../models/event_record.dart';

class CreateEventScreen extends StatefulWidget {
  final EventRecord? event;
  const CreateEventScreen({super.key, this.event});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime _eventDate = DateTime.now();

  List<Item> _allItems = [];
  final List<EventItem> _selectedEventItems = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
    if (widget.event != null) {
      _eventNameController.text = widget.event!.eventName;
      _eventDate = widget.event!.eventDate;
      _selectedEventItems.addAll(widget.event!.items.map((i) => EventItem(
        itemId: i.itemId,
        quantityTaken: i.quantityTaken,
        quantityReturned: i.quantityReturned,
      )));
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseService.instance.getItems();
    if (mounted) {
      setState(() {
        _allItems = items;
        _isLoading = false;
      });
    }
  }

  int _getAvailableQtyForEvent(Item item) {
    final databaseAvailable = item.quantity - item.inServiceQuantity - item.outForEventQuantity;
    if (widget.event == null) {
      return databaseAvailable;
    }
    final oldItem = widget.event!.items.firstWhere(
      (i) => i.itemId == item.id,
      orElse: () => EventItem(itemId: item.id, quantityTaken: 0, quantityReturned: 0),
    );
    return databaseAvailable + oldItem.quantityTaken;
  }

  void _showAddItemModal() {
    _searchController.clear();
    _searchQuery = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                final filteredItems = _allItems.where((item) {
                  final isSelected = _selectedEventItems.any((e) => e.itemId == item.id);
                  final availableQty = _getAvailableQtyForEvent(item);
                  final isAvailable = availableQty > 0 || isSelected;
                  if (!isAvailable) return false;

                  if (_searchQuery.trim().isEmpty) return true;
                  final query = _searchQuery.trim().toLowerCase();
                  return item.name.toLowerCase().contains(query) ||
                      item.brand.toLowerCase().contains(query) ||
                      item.model.toLowerCase().contains(query);
                }).toList();

                filteredItems.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Items',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(ctx),
                          )
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by name, brand, or model...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blueAccent),
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? const Center(
                              child: Text('No available items match search.', style: TextStyle(color: Color(0xFF94A3B8))),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final isSelected = _selectedEventItems.any((e) => e.itemId == item.id);
                                final currentSelectedQty = isSelected
                                    ? _selectedEventItems.firstWhere((e) => e.itemId == item.id).quantityTaken
                                    : 0;
                                final availableQty = _getAvailableQtyForEvent(item);

                                return ListTile(
                                  isThreeLine: true,
                                  title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    'Brand: ${item.brand}  Model: ${item.model}\nAvailable: $availableQty' +
                                        (isSelected ? ' | Selected: $currentSelectedQty' : ''),
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                  trailing: isSelected
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (availableQty > 1) ...[
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
                                                onPressed: () {
                                                  final oldItem = widget.event?.items.firstWhere(
                                                    (i) => i.itemId == item.id,
                                                    orElse: () => EventItem(itemId: item.id, quantityTaken: 0, quantityReturned: 0),
                                                  );
                                                  final minQty = oldItem != null && oldItem.quantityReturned > 0 ? oldItem.quantityReturned : 1;
                                                  _showModifyQuantityDialog(item, currentSelectedQty, availableQty, minQty, setModalState);
                                                },
                                                child: const Text('Modify', style: TextStyle(color: Colors.white)),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                              onPressed: () {
                                                final oldItem = widget.event?.items.firstWhere(
                                                  (i) => i.itemId == item.id,
                                                  orElse: () => EventItem(itemId: item.id, quantityTaken: 0, quantityReturned: 0),
                                                );
                                                if (oldItem != null && oldItem.quantityReturned > 0) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Cannot remove "${item.name}" because some quantities have already been returned.'),
                                                      backgroundColor: Colors.redAccent,
                                                    ),
                                                  );
                                                  return;
                                                }
                                                setState(() {
                                                  _selectedEventItems.removeWhere((e) => e.itemId == item.id);
                                                });
                                                setModalState(() {});
                                              },
                                              child: const Text('Remove', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        )
                                      : ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                          onPressed: () {
                                            if (availableQty == 1) {
                                              setState(() {
                                                _selectedEventItems.add(EventItem(itemId: item.id, quantityTaken: 1));
                                              });
                                              setModalState(() {});
                                            } else {
                                              _showQuantityDialog(item, availableQty, setModalState);
                                            }
                                          },
                                          child: const Text('Add', style: TextStyle(color: Colors.white)),
                                        ),
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
  }

  void _showQuantityDialog(Item item, int maxQty, void Function(void Function()) setModalState) {
    final qtyController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Add ${item.name}', style: const TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: qtyController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity to Check-out (Max: $maxQty)',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF334155))),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blueAccent)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  final q = int.tryParse(val);
                  if (q == null || q < 1) return 'Must be >= 1';
                  if (q > maxQty) return 'Cannot exceed $maxQty';
                  return null;
                },
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final qty = int.parse(qtyController.text);
                setState(() {
                  _selectedEventItems.add(EventItem(itemId: item.id, quantityTaken: qty));
                });
                setModalState(() {});
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showModifyQuantityDialog(Item item, int currentQty, int maxQty, int minQty, void Function(void Function()) setModalState) {
    final qtyController = TextEditingController(text: currentQty.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Modify ${item.name}', style: const TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: qtyController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity to Check-out (Min: $minQty, Max: $maxQty)',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF334155))),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blueAccent)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  final q = int.tryParse(val);
                  if (q == null || q < minQty) return 'Must be >= $minQty';
                  if (q > maxQty) return 'Cannot exceed $maxQty';
                  return null;
                },
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final qty = int.parse(qtyController.text);
                setState(() {
                  final index = _selectedEventItems.indexWhere((e) => e.itemId == item.id);
                  if (index != -1) {
                    _selectedEventItems[index] = EventItem(itemId: item.id, quantityTaken: qty);
                  }
                });
                setModalState(() {});
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEventItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      if (widget.event != null) {
        await DatabaseService.instance.updateEvent(
          widget.event!.id,
          _eventNameController.text.trim(),
          _eventDate,
          _selectedEventItems,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event updated successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        await DatabaseService.instance.createEvent(
          _eventNameController.text.trim(),
          _eventDate,
          _selectedEventItems,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save event: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(widget.event != null ? 'Edit Event' : 'Create Event', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _eventNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Event Name',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF334155))),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blueAccent)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter an event name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Event Date', style: TextStyle(color: Color(0xFF94A3B8))),
                      subtitle: Text(
                        '${_eventDate.year}-${_eventDate.month.toString().padLeft(2, '0')}-${_eventDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      trailing: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _eventDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _eventDate = picked;
                          });
                        }
                      },
                    ),
                    const Divider(color: Color(0xFF334155), height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Items to Take',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddItemModal,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedEventItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155), width: 1, style: BorderStyle.solid),
                        ),
                        child: const Text(
                          'No items selected yet.',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _selectedEventItems.length,
                        itemBuilder: (context, index) {
                          final eventItem = _selectedEventItems[index];
                          final item = _allItems.firstWhere((i) => i.id == eventItem.itemId);
                          return Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(item.name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text('Quantity: ${eventItem.quantityTaken}', style: const TextStyle(color: Color(0xFF94A3B8))),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                onPressed: () {
                                  final oldItem = widget.event?.items.firstWhere(
                                    (i) => i.itemId == eventItem.itemId,
                                    orElse: () => EventItem(itemId: eventItem.itemId, quantityTaken: 0, quantityReturned: 0),
                                  );
                                  if (oldItem != null && oldItem.quantityReturned > 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Cannot remove "${item.name}" because some quantities have already been returned.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _selectedEventItems.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submit,
                        child: Text(
                          widget.event != null ? 'Save Changes' : 'Create Event Check-out',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
