import 'dart:async';
import '../models/item.dart';
import '../models/audit_record.dart';
import '../models/service_record.dart';
import '../firebase_config.dart';
import 'firebase_database_service.dart';

abstract class DatabaseService {
  Future<List<Item>> getItems();
  Future<Item?> getItemById(String id);
  Future<void> addItem(Item item);
  Future<void> updateItemStatus(String itemId, String newStatus);
  Future<void> auditItem(String itemId, String auditorEmail, String condition, String notes);
  Future<void> sendToService(String itemId, String issueDescription, DateTime expectedReturnDate);
  Future<void> returnFromService(String itemId, String serviceRecordId, String resolutionNotes);
  Future<List<AuditRecord>> getAuditHistory(String itemId);
  Future<List<ServiceRecord>> getServiceHistory(String itemId);
  Future<List<ServiceRecord>> getAllActiveServiceRecords();
  Future<void> deleteItem(String itemId);
  
  // Stream updates to listener screens
  Stream<List<Item>> get itemsStream;

  static DatabaseService? _instance;
  static DatabaseService get instance {
    if (_instance == null) {
      if (FirebaseConfig.useFirebase) {
        _instance = FirebaseDatabaseService();
      } else {
        _instance = MockDatabaseService();
      }
    }
    return _instance!;
  }
}

class MockDatabaseService implements DatabaseService {
  // Singleton instance
  static final MockDatabaseService _instance = MockDatabaseService._internal();
  factory MockDatabaseService() => _instance;
  
  final List<Item> _items = [];
  final List<AuditRecord> _auditHistory = [];
  final List<ServiceRecord> _serviceHistory = [];
  
  final _itemsController = StreamController<List<Item>>.broadcast();

  MockDatabaseService._internal() {
    _populateInitialMockData();
  }

  @override
  Stream<List<Item>> get itemsStream async* {
    yield _items;
    yield* _itemsController.stream;
  }

  void _triggerUpdate() {
    _itemsController.add(List<Item>.from(_items));
  }

  void _populateInitialMockData() {
    final now = DateTime.now();
    
    // Add audio items
    _items.addAll([
      Item(
        id: "AUD-001",
        name: "Shure SM58 Vocal Microphone",
        category: "Audio",
        brand: "Shure",
        model: "SM58",
        serialNumber: "SH-589201",
        status: "Available",
        lastAudited: now.subtract(const Duration(days: 15)),
        nextAuditDue: now.add(const Duration(days: 15)),
        addedDate: now.subtract(const Duration(days: 180)),
      ),
      Item(
        id: "AUD-002",
        name: "Behringer X32 Digital Mixer",
        category: "Audio",
        brand: "Behringer",
        model: "X32",
        serialNumber: "BH-329841",
        status: "Available",
        lastAudited: now.subtract(const Duration(days: 40)), // Overdue
        nextAuditDue: now.subtract(const Duration(days: 10)),
        addedDate: now.subtract(const Duration(days: 360)),
      ),
      Item(
        id: "AUD-003",
        name: "Sennheiser EW 100 G4 Wireless Mic",
        category: "Audio",
        brand: "Sennheiser",
        model: "EW 100 G4",
        serialNumber: "SN-402941",
        status: "In Service",
        lastAudited: now.subtract(const Duration(days: 25)),
        nextAuditDue: now.add(const Duration(days: 5)),
        addedDate: now.subtract(const Duration(days: 120)),
      ),
      Item(
        id: "AUD-004",
        name: "K&M Boom Mic Stand Black",
        category: "Audio",
        brand: "K&M",
        model: "210/9",
        serialNumber: "KM-10023",
        status: "Available",
        lastAudited: now.subtract(const Duration(days: 5)),
        nextAuditDue: now.add(const Duration(days: 25)),
        addedDate: now.subtract(const Duration(days: 200)),
      ),
      Item(
        id: "AUD-005",
        name: "Heavy Duty XLR Cable (50ft)",
        category: "Audio",
        brand: "Mogami",
        model: "Gold Studio",
        serialNumber: "XLR-50-01",
        status: "Available",
        lastAudited: now.subtract(const Duration(days: 45)), // Overdue
        nextAuditDue: now.subtract(const Duration(days: 15)),
        addedDate: now.subtract(const Duration(days: 90)),
      ),
    ]);

    // Add video items
    _items.addAll([
      Item(
        id: "VID-001",
        name: "Sony FX3 Cinema Camera",
        category: "Video",
        brand: "Sony",
        model: "FX3",
        serialNumber: "SO-3920194",
        status: "Available",
        lastAudited: now.subtract(const Duration(days: 12)),
        nextAuditDue: now.add(const Duration(days: 18)),
        addedDate: now.subtract(const Duration(days: 150)),
      ),
      Item(
        id: "VID-002",
        name: "Blackmagic ATEM Mini Pro Switcher",
        category: "Video",
        brand: "Blackmagic",
        model: "ATEM Mini Pro",
        serialNumber: "BM-892401",
        status: "Available",
        lastAudited: now.subtract(const Duration(days: 8)),
        nextAuditDue: now.add(const Duration(days: 22)),
        addedDate: now.subtract(const Duration(days: 300)),
      ),
      Item(
        id: "VID-003",
        name: "Epson Pro EX9240 Projector",
        category: "Video",
        brand: "Epson",
        model: "EX9240",
        serialNumber: "EP-902481",
        status: "Available",
        lastAudited: now.subtract(const Duration(days: 35)), // Overdue
        nextAuditDue: now.subtract(const Duration(days: 5)),
        addedDate: now.subtract(const Duration(days: 220)),
      ),
      Item(
        id: "VID-004",
        name: "Samsung 65-inch 4K Smart TV",
        category: "Video",
        brand: "Samsung",
        model: "TU7000",
        serialNumber: "SS-7000-65",
        status: "Available",
        lastAudited: now.subtract(const Duration(days: 2)),
        nextAuditDue: now.add(const Duration(days: 28)),
        addedDate: now.subtract(const Duration(days: 400)),
      ),
      Item(
        id: "VID-005",
        name: "Decimator MD-HX HDMI/SDI Converter",
        category: "Video",
        brand: "Decimator",
        model: "MD-HX",
        serialNumber: "DC-902341",
        status: "Available",
        lastAudited: now.subtract(const Duration(days: 50)), // Overdue
        nextAuditDue: now.subtract(const Duration(days: 20)),
        addedDate: now.subtract(const Duration(days: 180)),
      ),
    ]);

    // Initial Histories
    _auditHistory.addAll([
      AuditRecord(
        id: "AUDIT-001",
        itemId: "AUD-001",
        auditDate: now.subtract(const Duration(days: 15)),
        auditorEmail: "admin@church.org",
        condition: "Good",
        notes: "Excellent working condition. Audio is clear.",
      ),
      AuditRecord(
        id: "AUDIT-002",
        itemId: "AUD-002",
        auditDate: now.subtract(const Duration(days: 40)),
        auditorEmail: "audit@church.org",
        condition: "Good",
        notes: "Faders are a bit dusty, but functioning well.",
      ),
      AuditRecord(
        id: "AUDIT-003",
        itemId: "AUD-003",
        auditDate: now.subtract(const Duration(days: 25)),
        auditorEmail: "admin@church.org",
        condition: "Requires Repair",
        notes: "Wireless receiver has intermittent signal issues.",
      ),
    ]);

    _serviceHistory.addAll([
      ServiceRecord(
        id: "SERV-001",
        itemId: "AUD-003",
        sentDate: now.subtract(const Duration(days: 24)),
        expectedReturnDate: now.add(const Duration(days: 5)),
        issueDescription: "Intermittent signal issues and static interference on channel 4.",
        resolutionNotes: "",
      ),
      ServiceRecord(
        id: "SERV-002",
        itemId: "VID-001",
        sentDate: now.subtract(const Duration(days: 100)),
        expectedReturnDate: now.subtract(const Duration(days: 85)),
        actualReturnDate: now.subtract(const Duration(days: 86)),
        issueDescription: "Lens mount lock loose.",
        resolutionNotes: "Replaced internal mount bracket under warranty. Back in action.",
      )
    ]);
  }

  @override
  Future<List<Item>> getItems() async {
    return List<Item>.from(_items);
  }

  @override
  Future<Item?> getItemById(String id) async {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addItem(Item item) async {
    _items.add(item);
    _triggerUpdate();
  }

  @override
  Future<void> updateItemStatus(String itemId, String newStatus) async {
    int index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(status: newStatus);
      _triggerUpdate();
    }
  }

  @override
  Future<void> auditItem(String itemId, String auditorEmail, String condition, String notes) async {
    int index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      final now = DateTime.now();
      _items[index] = _items[index].copyWith(
        lastAudited: now,
        nextAuditDue: now.add(const Duration(days: 30)),
        status: condition == "Requires Repair" ? "Available" : _items[index].status, // Keep status but log it
      );
      
      _auditHistory.add(AuditRecord(
        id: "AUDIT-${DateTime.now().millisecondsSinceEpoch}",
        itemId: itemId,
        auditDate: now,
        auditorEmail: auditorEmail,
        condition: condition,
        notes: notes,
      ));
      
      _triggerUpdate();
    }
  }

  @override
  Future<void> sendToService(String itemId, String issueDescription, DateTime expectedReturnDate) async {
    int index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(status: "In Service");
      
      _serviceHistory.add(ServiceRecord(
        id: "SERV-${DateTime.now().millisecondsSinceEpoch}",
        itemId: itemId,
        sentDate: DateTime.now(),
        expectedReturnDate: expectedReturnDate,
        issueDescription: issueDescription,
        resolutionNotes: "",
      ));
      
      _triggerUpdate();
    }
  }

  @override
  Future<void> returnFromService(String itemId, String serviceRecordId, String resolutionNotes) async {
    int itemIdx = _items.indexWhere((item) => item.id == itemId);
    int recordIdx = _serviceHistory.indexWhere((rec) => rec.id == serviceRecordId);
    
    if (itemIdx != -1) {
      _items[itemIdx] = _items[itemIdx].copyWith(status: "Available");
    }
    
    if (recordIdx != -1) {
      final rec = _serviceHistory[recordIdx];
      _serviceHistory[recordIdx] = ServiceRecord(
        id: rec.id,
        itemId: rec.itemId,
        sentDate: rec.sentDate,
        expectedReturnDate: rec.expectedReturnDate,
        actualReturnDate: DateTime.now(),
        issueDescription: rec.issueDescription,
        resolutionNotes: resolutionNotes,
      );
    }
    _triggerUpdate();
  }

  @override
  Future<List<AuditRecord>> getAuditHistory(String itemId) async {
    return _auditHistory.where((rec) => rec.itemId == itemId).toList()
      ..sort((a, b) => b.auditDate.compareTo(a.auditDate));
  }

  @override
  Future<List<ServiceRecord>> getServiceHistory(String itemId) async {
    return _serviceHistory.where((rec) => rec.itemId == itemId).toList()
      ..sort((a, b) => b.sentDate.compareTo(a.sentDate));
  }

  @override
  Future<List<ServiceRecord>> getAllActiveServiceRecords() async {
    return _serviceHistory.where((rec) => !rec.isReturned).toList();
  }

  @override
  Future<void> deleteItem(String itemId) async {
    _items.removeWhere((item) => item.id == itemId);
    _triggerUpdate();
  }
}
