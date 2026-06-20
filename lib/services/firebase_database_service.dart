import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../models/audit_record.dart';
import '../models/service_record.dart';
import '../models/event_record.dart';
import 'database_service.dart';

class FirebaseDatabaseService implements DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Item> _cachedItems = [];
  final List<EventRecord> _cachedEvents = [];
  final _itemsController = StreamController<List<Item>>.broadcast();
  final _eventsController = StreamController<List<EventRecord>>.broadcast();
  StreamSubscription? _itemsSubscription;
  StreamSubscription? _eventsSubscription;

  FirebaseDatabaseService() {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
    );

    _itemsSubscription = _firestore.collection('inventory').snapshots().listen((snapshot) {
      final items = snapshot.docs.map((doc) => Item.fromMap(doc.data())).toList();
      _cachedItems.clear();
      _cachedItems.addAll(items);
      _itemsController.add(items);
    });

    _eventsSubscription = _firestore.collection('events').snapshots().listen((snapshot) {
      final events = snapshot.docs.map((doc) => EventRecord.fromMap(doc.data())).toList();
      _cachedEvents.clear();
      _cachedEvents.addAll(events);
      _eventsController.add(events);
    });
  }

  @override
  Stream<List<Item>> get itemsStream async* {
    yield List<Item>.from(_cachedItems);
    yield* _itemsController.stream;
  }

  @override
  Stream<List<EventRecord>> get eventsStream async* {
    yield List<EventRecord>.from(_cachedEvents);
    yield* _eventsController.stream;
  }

  @override
  Future<List<Item>> getItems() async {
    if (_cachedItems.isNotEmpty) {
      return _cachedItems;
    }
    final snapshot = await _firestore.collection('inventory').get();
    final items = snapshot.docs.map((doc) => Item.fromMap(doc.data())).toList();
    _cachedItems.clear();
    _cachedItems.addAll(items);
    return _cachedItems;
  }

  @override
  Future<Item?> getItemById(String id) async {
    if (_cachedItems.isNotEmpty) {
      try {
        return _cachedItems.firstWhere((item) => item.id == id);
      } catch (_) {
        // Fallback to query from database if not found in memory cache
      }
    }
    final doc = await _firestore.collection('inventory').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return Item.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<void> addItem(Item item) async {
    await _firestore.collection('inventory').doc(item.id).set(item.toMap());
  }

  @override
  Future<void> updateItem(Item item) async {
    await _firestore.collection('inventory').doc(item.id).update(item.toMap());
  }

  @override
  Future<void> updateItemStatus(String itemId, String newStatus) async {
    await _firestore.collection('inventory').doc(itemId).update({'status': newStatus});
  }

  @override
  Future<void> incrementAuditedQuantity(String itemId) async {
    await _firestore.collection('inventory').doc(itemId).update({
      'auditedQuantity': FieldValue.increment(1)
    });
  }

  @override
  Future<void> auditItem(String itemId, String auditorEmail, String condition, String notes) async {
    final now = DateTime.now();
    final nextDue = now.add(const Duration(days: 30));

    final batch = _firestore.batch();
    final itemRef = _firestore.collection('inventory').doc(itemId);
    batch.update(itemRef, {
      'lastAudited': now.toIso8601String(),
      'nextAuditDue': nextDue.toIso8601String(),
      'auditedQuantity': 0,
    });
    
    final auditRef = _firestore.collection('audit_history').doc();
    batch.set(auditRef, {
      'id': auditRef.id,
      'itemId': itemId,
      'auditDate': now.toIso8601String(),
      'auditorEmail': auditorEmail,
      'condition': condition,
      'notes': notes,
    });
    
    await batch.commit();
  }

  @override
  Future<void> sendToService(String itemId, String issueDescription, DateTime expectedReturnDate, int quantity) async {
    final batch = _firestore.batch();
    final itemRef = _firestore.collection('inventory').doc(itemId);
    
    final index = _cachedItems.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final item = _cachedItems[index];
      final newInServiceQuantity = item.inServiceQuantity + quantity;
      final newStatus = newInServiceQuantity >= item.quantity ? 'In Service' : item.status;
      batch.update(itemRef, {
        'inServiceQuantity': newInServiceQuantity,
        'status': newStatus,
      });
    }

    final serviceRef = _firestore.collection('service_history').doc();
    batch.set(serviceRef, {
      'id': serviceRef.id,
      'itemId': itemId,
      'sentDate': DateTime.now().toIso8601String(),
      'expectedReturnDate': expectedReturnDate.toIso8601String(),
      'actualReturnDate': null,
      'issueDescription': issueDescription,
      'resolutionNotes': '',
      'quantity': quantity,
    });
    
    await batch.commit();
  }

  @override
  Future<void> returnFromService(String itemId, String serviceRecordId, String resolutionNotes) async {
    final serviceDoc = await _firestore.collection('service_history').doc(serviceRecordId).get();
    final quantity = serviceDoc.data()?['quantity'] ?? 1;

    final batch = _firestore.batch();
    final itemRef = _firestore.collection('inventory').doc(itemId);
    
    final index = _cachedItems.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final item = _cachedItems[index];
      final newInServiceQuantity = (item.inServiceQuantity - quantity as int).clamp(0, item.quantity);
      batch.update(itemRef, {
        'inServiceQuantity': newInServiceQuantity,
        'status': 'Available',
      });
    }

    final serviceRef = _firestore.collection('service_history').doc(serviceRecordId);
    batch.update(serviceRef, {
      'actualReturnDate': DateTime.now().toIso8601String(),
      'resolutionNotes': resolutionNotes,
    });
    
    await batch.commit();
  }

  @override
  Future<List<AuditRecord>> getAuditHistory(String itemId) async {
    final snapshot = await _firestore
        .collection('audit_history')
        .where('itemId', isEqualTo: itemId)
        .get();
        
    final audits = snapshot.docs.map((doc) => AuditRecord.fromMap(doc.data())).toList();
    audits.sort((a, b) => b.auditDate.compareTo(a.auditDate));
    return audits;
  }

  @override
  Future<List<ServiceRecord>> getServiceHistory(String itemId) async {
    final snapshot = await _firestore
        .collection('service_history')
        .where('itemId', isEqualTo: itemId)
        .get();
        
    final services = snapshot.docs.map((doc) => ServiceRecord.fromMap(doc.data())).toList();
    services.sort((a, b) => b.sentDate.compareTo(a.sentDate));
    return services;
  }

  @override
  Future<List<ServiceRecord>> getAllActiveServiceRecords() async {
    final snapshot = await _firestore
        .collection('service_history')
        .where('actualReturnDate', isNull: true)
        .get();
    return snapshot.docs.map((doc) => ServiceRecord.fromMap(doc.data())).toList();
  }

  @override
  Future<void> deleteItem(String itemId) async {
    final batch = _firestore.batch();
    
    // Delete the item from inventory
    batch.delete(_firestore.collection('inventory').doc(itemId));
    
    // Query and delete all audit history records for this item
    final auditsSnapshot = await _firestore
        .collection('audit_history')
        .where('itemId', isEqualTo: itemId)
        .get();
    for (var doc in auditsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // Query and delete all service history records for this item
    final servicesSnapshot = await _firestore
        .collection('service_history')
        .where('itemId', isEqualTo: itemId)
        .get();
    for (var doc in servicesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  @override
  Future<void> createEvent(String eventName, DateTime date, List<EventItem> items) async {
    final batch = _firestore.batch();
    final eventRef = _firestore.collection('events').doc();

    batch.set(eventRef, {
      'id': eventRef.id,
      'eventName': eventName,
      'eventDate': date.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
    });

    for (var evItem in items) {
      final itemRef = _firestore.collection('inventory').doc(evItem.itemId);
      final index = _cachedItems.indexWhere((i) => i.id == evItem.itemId);
      if (index != -1) {
        final newOutQty = _cachedItems[index].outForEventQuantity + evItem.quantityTaken;
        batch.update(itemRef, {'outForEventQuantity': newOutQty});
      }
    }

    await batch.commit();
  }

  @override
  Future<void> returnEventItem(String eventId, String itemId, int quantityToReturn) async {
    final eventRef = _firestore.collection('events').doc(eventId);
    final eventDoc = await eventRef.get();
    
    if (eventDoc.exists) {
      final event = EventRecord.fromMap(eventDoc.data()!);
      final newItems = event.items.map((i) {
        if (i.itemId == itemId) {
          final newRetQty = (i.quantityReturned + quantityToReturn).clamp(0, i.quantityTaken);
          return EventItem(
            itemId: i.itemId,
            quantityTaken: i.quantityTaken,
            quantityReturned: newRetQty,
          );
        }
        return i;
      }).toList();

      final batch = _firestore.batch();
      batch.update(eventRef, {
        'items': newItems.map((i) => i.toMap()).toList(),
      });

      final itemRef = _firestore.collection('inventory').doc(itemId);
      final itemIndex = _cachedItems.indexWhere((i) => i.id == itemId);
      if (itemIndex != -1) {
        final newOutQty = (_cachedItems[itemIndex].outForEventQuantity - quantityToReturn).clamp(0, _cachedItems[itemIndex].quantity);
        batch.update(itemRef, {'outForEventQuantity': newOutQty});
      }

      await batch.commit();
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection('events').doc(eventId).delete();
  }

  @override
  Future<void> updateEvent(String eventId, String newEventName, DateTime newDate, List<EventItem> newItems) async {
    final eventRef = _firestore.collection('events').doc(eventId);
    final eventDoc = await eventRef.get();
    if (!eventDoc.exists) {
      throw Exception('Event not found');
    }
    
    final oldEvent = EventRecord.fromMap(eventDoc.data()!);
    final batch = _firestore.batch();

    final oldItemsMap = {for (var item in oldEvent.items) item.itemId: item};
    final newItemsMap = {for (var item in newItems) item.itemId: item};

    final allItemIds = {...oldItemsMap.keys, ...newItemsMap.keys};
    for (var itemId in allItemIds) {
      final oldItem = oldItemsMap[itemId];
      final newItem = newItemsMap[itemId];
      
      int change = 0;
      int quantityReturned = 0;

      if (oldItem == null && newItem != null) {
        change = newItem.quantityTaken;
      } else if (oldItem != null && newItem == null) {
        change = -(oldItem.quantityTaken - oldItem.quantityReturned);
      } else if (oldItem != null && newItem != null) {
        change = newItem.quantityTaken - oldItem.quantityTaken;
        quantityReturned = oldItem.quantityReturned;
        
        final index = newItems.indexWhere((i) => i.itemId == itemId);
        if (index != -1) {
          newItems[index] = EventItem(
            itemId: itemId,
            quantityTaken: newItem.quantityTaken,
            quantityReturned: quantityReturned,
          );
        }
      }

      if (change != 0) {
        final itemRef = _firestore.collection('inventory').doc(itemId);
        final itemIdx = _cachedItems.indexWhere((i) => i.id == itemId);
        if (itemIdx != -1) {
          final newOutQty = (_cachedItems[itemIdx].outForEventQuantity + change).clamp(0, _cachedItems[itemIdx].quantity);
          batch.update(itemRef, {'outForEventQuantity': newOutQty});
        }
      }
    }

    batch.update(eventRef, {
      'eventName': newEventName,
      'eventDate': newDate.toIso8601String(),
      'items': newItems.map((i) => i.toMap()).toList(),
    });

    await batch.commit();
  }
}
