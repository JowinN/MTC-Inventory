import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/event_record.dart';
import '../models/item.dart';
import 'create_event_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventRecord event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late EventRecord _event;
  List<Item> _items = [];
  bool _isLoading = true;
  final Set<String> _selectedItemIds = {};
  final Map<String, int> _itemsToReturnQty = {};

  Future<void> _handleBatchReturn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      for (final itemId in _selectedItemIds) {
        final qtyToReturn = _itemsToReturnQty[itemId] ?? 0;
        if (qtyToReturn > 0) {
          await DatabaseService.instance.returnEventItem(_event.id, itemId, qtyToReturn);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected items returned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to return items: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectedItemIds.clear();
          _itemsToReturnQty.clear();
          _isLoading = false;
        });
      }
    }
  }

  Future<int?> _showReturnQuantityDialog(String itemName, int maxQty) async {
    final qtyController = TextEditingController(text: maxQty.toString());
    final formKey = GlobalKey<FormState>();

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Return $itemName', style: const TextStyle(color: Colors.white)),
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
                  labelText: 'Quantity to Return (Max: $maxQty)',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
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
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final qty = int.parse(qtyController.text);
                Navigator.pop(ctx, qty);
              }
            },
            child: const Text('Return', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteEvent() async {
    final canDelete = _event.items.every((item) => item.isFullyReturned);
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete active event. All checked-out items must be returned first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Event?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to delete this event? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await DatabaseService.instance.deleteEvent(_event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Go back to event list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete event: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadData();
    DatabaseService.instance.eventsStream.listen((events) {
      if (mounted) {
        final updatedEvent = events.firstWhere(
          (e) => e.id == _event.id,
          orElse: () => _event,
        );
        setState(() {
          _event = updatedEvent;
        });
      }
    });
  }

  Future<void> _loadData() async {
    final items = await DatabaseService.instance.getItems();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Event Details', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blueAccent),
            tooltip: 'Edit Event',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEventScreen(event: _event),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete Event',
            onPressed: _handleDeleteEvent,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _event.eventName,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: ${_event.eventDate.year}-${_event.eventDate.month.toString().padLeft(2, '0')}-${_event.eventDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Items Checked Out',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _event.items.length,
                      itemBuilder: (context, index) {
                        final eventItem = _event.items[index];
                        final item = _items.firstWhere(
                          (i) => i.id == eventItem.itemId,
                          orElse: () => Item(
                            id: eventItem.itemId,
                            name: 'Unknown Item',
                            category: '',
                            brand: '',
                            model: '',
                            serialNumber: '',
                            status: '',
                            lastAudited: DateTime.now(),
                            nextAuditDue: DateTime.now(),
                            addedDate: DateTime.now(),
                          ),
                        );

                        final isFullyReturned = eventItem.isFullyReturned;
                        final remaining = eventItem.quantityTaken - eventItem.quantityReturned;
                        final isSelected = _selectedItemIds.contains(item.id);

                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isFullyReturned ? Colors.green.withOpacity(0.5) : const Color(0xFF334155), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Brand: ${item.brand}  Model: ${item.model}',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Quantity: ${eventItem.quantityReturned} / ${eventItem.quantityTaken} Returned' +
                                            (isSelected && remaining > 1 ? ' | Returning: ${_itemsToReturnQty[item.id]}' : ''),
                                        style: TextStyle(color: isFullyReturned ? Colors.greenAccent : Colors.amberAccent),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isFullyReturned)
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: Colors.blueAccent,
                                    checkColor: Colors.white,
                                    onChanged: (bool? checked) async {
                                      if (checked == true) {
                                        if (remaining > 1) {
                                          final qty = await _showReturnQuantityDialog(item.name, remaining);
                                          if (qty != null && qty > 0) {
                                            setState(() {
                                              _selectedItemIds.add(item.id);
                                              _itemsToReturnQty[item.id] = qty;
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            _selectedItemIds.add(item.id);
                                            _itemsToReturnQty[item.id] = 1;
                                          });
                                        }
                                      } else {
                                        setState(() {
                                          _selectedItemIds.remove(item.id);
                                          _itemsToReturnQty.remove(item.id);
                                        });
                                      }
                                    },
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(Icons.check_box, color: Colors.greenAccent),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _selectedItemIds.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.assignment_returned, color: Colors.white),
                    label: Text(
                      'Return Selected Items (${_selectedItemIds.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _handleBatchReturn,
                  ),
                ),
              ),
            ),
    );
  }
}
