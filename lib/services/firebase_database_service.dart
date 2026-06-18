import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../models/audit_record.dart';
import '../models/service_record.dart';
import 'database_service.dart';

class FirebaseDatabaseService implements DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Item> _cachedItems = [];

  FirebaseDatabaseService() {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  @override
  Stream<List<Item>> get itemsStream {
    return _firestore.collection('inventory').snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) => Item.fromMap(doc.data())).toList();
      _cachedItems = items;
      return items;
    });
  }

  @override
  Future<List<Item>> getItems() async {
    if (_cachedItems.isNotEmpty) {
      return _cachedItems;
    }
    final snapshot = await _firestore.collection('inventory').get();
    _cachedItems = snapshot.docs.map((doc) => Item.fromMap(doc.data())).toList();
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
    // Optimistic cache update
    final index = _cachedItems.indexWhere((i) => i.id == item.id);
    if (index == -1) {
      _cachedItems.add(item);
    } else {
      _cachedItems[index] = item;
    }
    await _firestore.collection('inventory').doc(item.id).set(item.toMap());
  }

  @override
  Future<void> updateItemStatus(String itemId, String newStatus) async {
    // Optimistic cache update
    final index = _cachedItems.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _cachedItems[index] = _cachedItems[index].copyWith(status: newStatus);
    }
    await _firestore.collection('inventory').doc(itemId).update({'status': newStatus});
  }

  @override
  Future<void> auditItem(String itemId, String auditorEmail, String condition, String notes) async {
    final now = DateTime.now();
    final nextDue = now.add(const Duration(days: 30));
    
    // Optimistic cache update
    final index = _cachedItems.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _cachedItems[index] = _cachedItems[index].copyWith(
        lastAudited: now,
        nextAuditDue: nextDue,
      );
    }

    final batch = _firestore.batch();
    final itemRef = _firestore.collection('inventory').doc(itemId);
    batch.update(itemRef, {
      'lastAudited': now.toIso8601String(),
      'nextAuditDue': nextDue.toIso8601String(),
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
  Future<void> sendToService(String itemId, String issueDescription, DateTime expectedReturnDate) async {
    // Optimistic cache update
    final index = _cachedItems.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _cachedItems[index] = _cachedItems[index].copyWith(status: 'In Service');
    }

    final batch = _firestore.batch();
    final itemRef = _firestore.collection('inventory').doc(itemId);
    batch.update(itemRef, {'status': 'In Service'});
    
    final serviceRef = _firestore.collection('service_history').doc();
    batch.set(serviceRef, {
      'id': serviceRef.id,
      'itemId': itemId,
      'sentDate': DateTime.now().toIso8601String(),
      'expectedReturnDate': expectedReturnDate.toIso8601String(),
      'actualReturnDate': null,
      'issueDescription': issueDescription,
      'resolutionNotes': '',
    });
    
    await batch.commit();
  }

  @override
  Future<void> returnFromService(String itemId, String serviceRecordId, String resolutionNotes) async {
    // Optimistic cache update
    final index = _cachedItems.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _cachedItems[index] = _cachedItems[index].copyWith(status: 'Available');
    }

    final batch = _firestore.batch();
    final itemRef = _firestore.collection('inventory').doc(itemId);
    batch.update(itemRef, {'status': 'Available'});
    
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
    // Optimistic cache update
    _cachedItems.removeWhere((i) => i.id == itemId);
    await _firestore.collection('inventory').doc(itemId).delete();
  }
}
