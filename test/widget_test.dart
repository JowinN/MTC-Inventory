// Comprehensive test suite for MTC Inventory app.
// Covers: models, database service, and widget tests for all screens.
// Particular focus on the newly added specification quantity feature.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church_inventory/main.dart';
import 'package:church_inventory/screens/create_event_screen.dart';
import 'package:church_inventory/screens/event_details_screen.dart';
import 'package:church_inventory/screens/inventory_screen.dart';
import 'package:church_inventory/services/database_service.dart';
import 'package:church_inventory/models/item.dart';
import 'package:church_inventory/models/event_record.dart';
import 'package:church_inventory/models/audit_record.dart';
import 'package:church_inventory/models/service_record.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Setup: Reset mock database before every test
  // ─────────────────────────────────────────────────────────────────────────
  setUp(() {
    final mockDb = MockDatabaseService();
    mockDb.reset();
    DatabaseService.instance = mockDb;
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 1: Item Model Unit Tests — Specification Quantity
  // ═══════════════════════════════════════════════════════════════════════════
  group('Item Model — specification quantity', () {
    final now = DateTime.now();

    Item makeItem({
      int quantity = 1,
      int inServiceQuantity = 0,
      int outForEventQuantity = 0,
      int auditedQuantity = 0,
    }) {
      return Item(
        id: 'TEST-001',
        name: 'Test Item',
        category: 'Audio',
        brand: 'TestBrand',
        model: 'TestModel',
        serialNumber: 'SN-TEST',
        status: 'Available',
        lastAudited: now,
        nextAuditDue: now.add(const Duration(days: 30)),
        addedDate: now,
        quantity: quantity,
        inServiceQuantity: inServiceQuantity,
        outForEventQuantity: outForEventQuantity,
        auditedQuantity: auditedQuantity,
      );
    }

    test('default quantity is 1', () {
      final item = Item(
        id: 'X',
        name: 'X',
        category: 'Audio',
        brand: 'B',
        model: 'M',
        serialNumber: 'S',
        status: 'Available',
        lastAudited: now,
        nextAuditDue: now.add(const Duration(days: 30)),
        addedDate: now,
      );
      expect(item.quantity, 1);
      expect(item.auditedQuantity, 0);
      expect(item.inServiceQuantity, 0);
      expect(item.outForEventQuantity, 0);
    });

    test('availableQty = quantity - inService - outForEvent, clamped to 0', () {
      expect(makeItem(quantity: 10, inServiceQuantity: 3, outForEventQuantity: 2).availableQty, 5);
      expect(makeItem(quantity: 1, inServiceQuantity: 1, outForEventQuantity: 0).availableQty, 0);
      expect(makeItem(quantity: 5, inServiceQuantity: 3, outForEventQuantity: 3).availableQty, 0); // clamped
      expect(makeItem(quantity: 5).availableQty, 5);
    });

    test('computedStatus returns Available when nothing is checked out', () {
      expect(makeItem(quantity: 5).computedStatus, 'Available');
    });

    test('computedStatus returns In Service when all units in service', () {
      expect(makeItem(quantity: 3, inServiceQuantity: 3).computedStatus, 'In Service');
    });

    test('computedStatus returns In Event when all units in event', () {
      expect(makeItem(quantity: 2, outForEventQuantity: 2).computedStatus, 'In Event');
    });

    test('computedStatus returns Part. Service when some in service', () {
      expect(makeItem(quantity: 5, inServiceQuantity: 2).computedStatus, 'Part. Service');
    });

    test('computedStatus returns Part. Event when some in event', () {
      expect(makeItem(quantity: 5, outForEventQuantity: 1).computedStatus, 'Part. Event');
    });

    test('computedStatus returns Service & Event when both partially active', () {
      expect(makeItem(quantity: 10, inServiceQuantity: 2, outForEventQuantity: 3).computedStatus, 'Service & Event');
    });

    test('computedStatus returns Service & Event when combined equals quantity', () {
      expect(makeItem(quantity: 4, inServiceQuantity: 2, outForEventQuantity: 2).computedStatus, 'Service & Event');
    });

    test('copyWith preserves and overrides quantity fields correctly', () {
      final original = makeItem(quantity: 10, inServiceQuantity: 2, outForEventQuantity: 3, auditedQuantity: 4);
      final copy = original.copyWith(quantity: 20, auditedQuantity: 0);
      expect(copy.quantity, 20);
      expect(copy.auditedQuantity, 0);
      expect(copy.inServiceQuantity, 2); // preserved
      expect(copy.outForEventQuantity, 3); // preserved
      expect(copy.id, 'TEST-001'); // id always preserved
    });

    test('toMap includes quantity fields', () {
      final item = makeItem(quantity: 7, inServiceQuantity: 1, outForEventQuantity: 2, auditedQuantity: 3);
      final map = item.toMap();
      expect(map['quantity'], 7);
      expect(map['inServiceQuantity'], 1);
      expect(map['outForEventQuantity'], 2);
      expect(map['auditedQuantity'], 3);
    });

    test('fromMap parses quantity fields with defaults', () {
      final item = Item.fromMap({
        'id': 'MAP-001',
        'name': 'Mapped Item',
        'category': 'Video',
        'brand': 'B',
        'model': 'M',
        'serialNumber': 'SN',
        'status': 'Available',
        'lastAudited': now.toIso8601String(),
        'nextAuditDue': now.add(const Duration(days: 30)).toIso8601String(),
        'addedDate': now.toIso8601String(),
        // quantity fields omitted — should use defaults
      });
      expect(item.quantity, 1);
      expect(item.auditedQuantity, 0);
      expect(item.inServiceQuantity, 0);
      expect(item.outForEventQuantity, 0);
    });

    test('fromMap parses explicit quantity fields', () {
      final item = Item.fromMap({
        'id': 'MAP-002',
        'name': 'Big Item',
        'category': 'Audio',
        'brand': 'B',
        'model': 'M',
        'serialNumber': 'SN',
        'status': 'Available',
        'lastAudited': now.toIso8601String(),
        'nextAuditDue': now.add(const Duration(days: 30)).toIso8601String(),
        'addedDate': now.toIso8601String(),
        'quantity': 15,
        'auditedQuantity': 5,
        'inServiceQuantity': 3,
        'outForEventQuantity': 2,
      });
      expect(item.quantity, 15);
      expect(item.auditedQuantity, 5);
      expect(item.inServiceQuantity, 3);
      expect(item.outForEventQuantity, 2);
      expect(item.availableQty, 10);
    });

    test('toMap and fromMap round-trip preserves all fields', () {
      final original = makeItem(quantity: 12, inServiceQuantity: 3, outForEventQuantity: 4, auditedQuantity: 5);
      final map = original.toMap();
      final restored = Item.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.quantity, original.quantity);
      expect(restored.inServiceQuantity, original.inServiceQuantity);
      expect(restored.outForEventQuantity, original.outForEventQuantity);
      expect(restored.auditedQuantity, original.auditedQuantity);
      expect(restored.availableQty, original.availableQty);
    });

    test('isAuditDue returns true when nextAuditDue is in the past', () {
      final item = Item(
        id: 'OVERDUE',
        name: 'Overdue Item',
        category: 'Audio',
        brand: 'B',
        model: 'M',
        serialNumber: 'SN',
        status: 'Available',
        lastAudited: now.subtract(const Duration(days: 60)),
        nextAuditDue: now.subtract(const Duration(days: 1)),
        addedDate: now,
        quantity: 5,
      );
      expect(item.isAuditDue, true);
    });

    test('isAuditDue returns false when nextAuditDue is in the future', () {
      final item = makeItem(quantity: 5);
      expect(item.isAuditDue, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 2: EventItem and EventRecord Model Tests
  // ═══════════════════════════════════════════════════════════════════════════
  group('EventItem & EventRecord model tests', () {
    test('EventItem isFullyReturned is correct', () {
      expect(EventItem(itemId: 'A', quantityTaken: 3, quantityReturned: 3).isFullyReturned, true);
      expect(EventItem(itemId: 'A', quantityTaken: 3, quantityReturned: 2).isFullyReturned, false);
      expect(EventItem(itemId: 'A', quantityTaken: 1, quantityReturned: 0).isFullyReturned, false);
      expect(EventItem(itemId: 'A', quantityTaken: 1, quantityReturned: 1).isFullyReturned, true);
    });

    test('EventRecord isCompleted is true only when all items are fully returned', () {
      final completed = EventRecord(
        id: 'E1',
        eventName: 'Done',
        eventDate: DateTime.now(),
        items: [
          EventItem(itemId: 'A', quantityTaken: 2, quantityReturned: 2),
          EventItem(itemId: 'B', quantityTaken: 1, quantityReturned: 1),
        ],
      );
      expect(completed.isCompleted, true);

      final active = EventRecord(
        id: 'E2',
        eventName: 'Active',
        eventDate: DateTime.now(),
        items: [
          EventItem(itemId: 'A', quantityTaken: 2, quantityReturned: 2),
          EventItem(itemId: 'B', quantityTaken: 3, quantityReturned: 1), // not fully returned
        ],
      );
      expect(active.isCompleted, false);
    });

    test('EventItem toMap/fromMap round-trip', () {
      final original = EventItem(itemId: 'X', quantityTaken: 5, quantityReturned: 2);
      final restored = EventItem.fromMap(original.toMap());
      expect(restored.itemId, 'X');
      expect(restored.quantityTaken, 5);
      expect(restored.quantityReturned, 2);
    });

    test('EventRecord toMap/fromMap round-trip', () {
      final original = EventRecord(
        id: 'EVT-1',
        eventName: 'Test Event',
        eventDate: DateTime(2026, 1, 15),
        items: [
          EventItem(itemId: 'A', quantityTaken: 3, quantityReturned: 1),
        ],
      );
      final restored = EventRecord.fromMap(original.toMap());
      expect(restored.id, 'EVT-1');
      expect(restored.eventName, 'Test Event');
      expect(restored.items.length, 1);
      expect(restored.items.first.quantityTaken, 3);
      expect(restored.items.first.quantityReturned, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 3: ServiceRecord & AuditRecord Model Tests
  // ═══════════════════════════════════════════════════════════════════════════
  group('ServiceRecord & AuditRecord model tests', () {
    test('ServiceRecord includes quantity in toMap/fromMap', () {
      final record = ServiceRecord(
        id: 'S1',
        itemId: 'ITEM-1',
        sentDate: DateTime.now(),
        expectedReturnDate: DateTime.now().add(const Duration(days: 7)),
        issueDescription: 'Broken',
        resolutionNotes: '',
        quantity: 3,
      );
      final map = record.toMap();
      expect(map['quantity'], 3);

      final restored = ServiceRecord.fromMap(map);
      expect(restored.quantity, 3);
      expect(restored.isReturned, false);
    });

    test('ServiceRecord isReturned and isOverdue', () {
      final returned = ServiceRecord(
        id: 'S2',
        itemId: 'ITEM-1',
        sentDate: DateTime.now().subtract(const Duration(days: 10)),
        expectedReturnDate: DateTime.now().subtract(const Duration(days: 3)),
        actualReturnDate: DateTime.now().subtract(const Duration(days: 4)),
        issueDescription: 'Issue',
        resolutionNotes: 'Fixed',
        quantity: 1,
      );
      expect(returned.isReturned, true);
      expect(returned.isOverdue, false); // returned, so not overdue

      final overdue = ServiceRecord(
        id: 'S3',
        itemId: 'ITEM-1',
        sentDate: DateTime.now().subtract(const Duration(days: 10)),
        expectedReturnDate: DateTime.now().subtract(const Duration(days: 3)),
        issueDescription: 'Issue',
        resolutionNotes: '',
        quantity: 2,
      );
      expect(overdue.isReturned, false);
      expect(overdue.isOverdue, true);
    });

    test('AuditRecord toMap/fromMap round-trip', () {
      final now = DateTime(2026, 6, 15, 10, 30);
      final record = AuditRecord(
        id: 'A1',
        itemId: 'ITEM-1',
        auditDate: now,
        auditorEmail: 'test@example.com',
        condition: 'Good',
        notes: 'Looks good',
      );
      final restored = AuditRecord.fromMap(record.toMap());
      expect(restored.id, 'A1');
      expect(restored.itemId, 'ITEM-1');
      expect(restored.auditorEmail, 'test@example.com');
      expect(restored.condition, 'Good');
      expect(restored.notes, 'Looks good');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 4: MockDatabaseService — Quantity Operations
  // ═══════════════════════════════════════════════════════════════════════════
  group('MockDatabaseService — quantity operations', () {
    test('addItem stores item with correct quantity', () async {
      final mockDb = MockDatabaseService();
      final now = DateTime.now();
      await mockDb.addItem(Item(
        id: 'QTY-001',
        name: 'Bulk Cable',
        category: 'Audio',
        brand: 'Brand',
        model: 'Model',
        serialNumber: 'SN',
        status: 'Available',
        lastAudited: now,
        nextAuditDue: now.add(const Duration(days: 30)),
        addedDate: now,
        quantity: 25,
      ));

      final item = await mockDb.getItemById('QTY-001');
      expect(item, isNotNull);
      expect(item!.quantity, 25);
      expect(item.availableQty, 25);
    });

    test('updateItem preserves quantity on update', () async {
      final mockDb = MockDatabaseService();
      final item = await mockDb.getItemById('AUD-001');
      expect(item, isNotNull);

      final updated = item!.copyWith(quantity: 10, name: 'Updated Shure');
      await mockDb.updateItem(updated);

      final fetched = await mockDb.getItemById('AUD-001');
      expect(fetched!.quantity, 10);
      expect(fetched.name, 'Updated Shure');
    });

    test('sendToService increments inServiceQuantity by specified amount', () async {
      final mockDb = MockDatabaseService();
      // First, update AUD-001 to have quantity > 1
      final item = await mockDb.getItemById('AUD-001');
      await mockDb.updateItem(item!.copyWith(quantity: 5));

      await mockDb.sendToService('AUD-001', 'Test issue', DateTime.now().add(const Duration(days: 7)), 3);

      final updated = await mockDb.getItemById('AUD-001');
      expect(updated!.inServiceQuantity, 3);
      expect(updated.availableQty, 2);
    });

    test('returnFromService decrements inServiceQuantity', () async {
      final mockDb = MockDatabaseService();
      final item = await mockDb.getItemById('AUD-001');
      await mockDb.updateItem(item!.copyWith(quantity: 5));

      await mockDb.sendToService('AUD-001', 'Issue', DateTime.now().add(const Duration(days: 7)), 3);
      final history = await mockDb.getServiceHistory('AUD-001');
      final activeRecord = history.firstWhere((r) => !r.isReturned);

      await mockDb.returnFromService('AUD-001', activeRecord.id, 'Fixed');

      final updated = await mockDb.getItemById('AUD-001');
      expect(updated!.inServiceQuantity, 0);
      expect(updated.availableQty, 5);
    });

    test('incrementAuditedQuantity increments by 1 each call', () async {
      final mockDb = MockDatabaseService();
      var item = await mockDb.getItemById('AUD-001');
      expect(item!.auditedQuantity, 0);

      await mockDb.incrementAuditedQuantity('AUD-001');
      item = await mockDb.getItemById('AUD-001');
      expect(item!.auditedQuantity, 1);

      await mockDb.incrementAuditedQuantity('AUD-001');
      item = await mockDb.getItemById('AUD-001');
      expect(item!.auditedQuantity, 2);
    });

    test('auditItem resets auditedQuantity to 0 and updates dates', () async {
      final mockDb = MockDatabaseService();
      await mockDb.incrementAuditedQuantity('AUD-001');
      await mockDb.incrementAuditedQuantity('AUD-001');

      var item = await mockDb.getItemById('AUD-001');
      expect(item!.auditedQuantity, 2);

      await mockDb.auditItem('AUD-001', 'admin@test.com', 'Good', 'All good');

      item = await mockDb.getItemById('AUD-001');
      expect(item!.auditedQuantity, 0); // reset after full audit
    });

    test('createEvent increments outForEventQuantity on items', () async {
      final mockDb = MockDatabaseService();

      await mockDb.createEvent('Test Event', DateTime.now(), [
        EventItem(itemId: 'AUD-001', quantityTaken: 1, quantityReturned: 0),
      ]);

      final item = await mockDb.getItemById('AUD-001');
      expect(item!.outForEventQuantity, 1);
      expect(item.availableQty, 0); // quantity=1, outForEvent=1
    });

    test('returnEventItem decrements outForEventQuantity', () async {
      final mockDb = MockDatabaseService();

      await mockDb.createEvent('Test Event', DateTime.now(), [
        EventItem(itemId: 'VID-001', quantityTaken: 2, quantityReturned: 0),
      ]);

      final item = await mockDb.getItemById('VID-001');
      expect(item!.outForEventQuantity, 2);

      final events = await mockDb.eventsStream.first;
      final event = events.first;

      await mockDb.returnEventItem(event.id, 'VID-001', 1);

      final updated = await mockDb.getItemById('VID-001');
      expect(updated!.outForEventQuantity, 1);
    });

    test('deleteItem removes audit and service history', () async {
      final mockDb = MockDatabaseService();
      mockDb.reset();

      final now = DateTime.now();
      await mockDb.addItem(Item(
        id: 'DEL-001',
        name: 'Item to Delete',
        category: 'Audio',
        brand: 'Test',
        model: 'Model',
        serialNumber: 'SN-DEL',
        status: 'Available',
        lastAudited: now,
        nextAuditDue: now.add(const Duration(days: 30)),
        addedDate: now,
        quantity: 3,
      ));

      await mockDb.auditItem('DEL-001', 'test@example.com', 'Good', 'Audit check');
      await mockDb.sendToService('DEL-001', 'Broken jack', now.add(const Duration(days: 5)), 2);

      final initialAudits = await mockDb.getAuditHistory('DEL-001');
      final initialServices = await mockDb.getServiceHistory('DEL-001');
      expect(initialAudits.length, 1);
      expect(initialServices.length, 1);

      await mockDb.deleteItem('DEL-001');

      final items = await mockDb.getItems();
      expect(items.any((i) => i.id == 'DEL-001'), isFalse);

      final postAudits = await mockDb.getAuditHistory('DEL-001');
      final postServices = await mockDb.getServiceHistory('DEL-001');
      expect(postAudits, isEmpty);
      expect(postServices, isEmpty);
    });

    test('updateEvent adjusts outForEventQuantity correctly when adding/removing items', () async {
      final mockDb = MockDatabaseService();

      // VID-001 has default quantity=1 in mock data, increase it so we can allocate 2
      final vid = await mockDb.getItemById('VID-001');
      await mockDb.updateItem(vid!.copyWith(quantity: 5));

      // Create event with AUD-001 qty 1
      await mockDb.createEvent('Original', DateTime.now(), [
        EventItem(itemId: 'AUD-001', quantityTaken: 1, quantityReturned: 0),
      ]);

      final events = await mockDb.eventsStream.first;
      final event = events.firstWhere((e) => e.eventName == 'Original');

      // Update: remove AUD-001, add VID-001 qty 2
      await mockDb.updateEvent(event.id, 'Updated Event', DateTime.now(), [
        EventItem(itemId: 'VID-001', quantityTaken: 2, quantityReturned: 0),
      ]);

      final aud001 = await mockDb.getItemById('AUD-001');
      final vid001 = await mockDb.getItemById('VID-001');
      expect(aud001!.outForEventQuantity, 0); // released
      expect(vid001!.outForEventQuantity, 2); // newly checked out
    });

    test('sendToService with quantity creates service record with correct quantity', () async {
      final mockDb = MockDatabaseService();

      final item = await mockDb.getItemById('AUD-002');
      await mockDb.updateItem(item!.copyWith(quantity: 10));

      await mockDb.sendToService('AUD-002', 'Faders stuck', DateTime.now().add(const Duration(days: 14)), 4);

      final history = await mockDb.getServiceHistory('AUD-002');
      final activeRecords = history.where((r) => !r.isReturned).toList();
      expect(activeRecords.length, 1);
      expect(activeRecords.first.quantity, 4);
    });

    test('getAllActiveServiceRecords returns only non-returned records', () async {
      final mockDb = MockDatabaseService();

      // From mock data, AUD-003 already has an active service record (SERV-001)
      // and VID-001 has a returned record (SERV-002)
      final activeRecords = await mockDb.getAllActiveServiceRecords();
      expect(activeRecords.every((r) => !r.isReturned), true);
      expect(activeRecords.any((r) => r.itemId == 'AUD-003'), true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 5: Widget Tests — App Smoke Test
  // ═══════════════════════════════════════════════════════════════════════════
  group('App smoke tests', () {
    testWidgets('App login screen smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      expect(find.text('MTC Inventory'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 6: Widget Tests — InventoryScreen & Specification Quantity Display
  // ═══════════════════════════════════════════════════════════════════════════
  group('InventoryScreen — filters and quantity display', () {
    testWidgets('InventoryScreen supports In Event status filter', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      DatabaseService.instance = mockDb;

      await mockDb.createEvent('Youth Retreat', DateTime.now(), [
        EventItem(itemId: 'AUD-001', quantityTaken: 1, quantityReturned: 0),
      ]);

      await tester.pumpWidget(const MaterialApp(home: InventoryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Behringer X32 Digital Mixer'), findsOneWidget);

      final inEventChip = find.widgetWithText(ChoiceChip, 'In Event');
      expect(inEventChip, findsOneWidget);
      await tester.tap(inEventChip);
      await tester.pumpAndSettle();

      expect(find.text('Shure SM58 Vocal Microphone'), findsOneWidget);
      expect(find.text('Behringer X32 Digital Mixer'), findsNothing);

      final availableChip = find.widgetWithText(ChoiceChip, 'Available');
      await tester.tap(availableChip);
      await tester.pumpAndSettle();

      expect(find.text('Shure SM58 Vocal Microphone'), findsNothing);
      expect(find.text('Behringer X32 Digital Mixer'), findsOneWidget);
    });

    testWidgets('InventoryScreen supports In Service status filter', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      DatabaseService.instance = mockDb;

      // AUD-003 (Sennheiser) is already 'In Service' in mock data with inServiceQuantity via status
      // but let's explicitly put one in service via the service flow
      await mockDb.sendToService('AUD-001', 'Broken', DateTime.now().add(const Duration(days: 7)), 1);

      await tester.pumpWidget(const MaterialApp(home: InventoryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final inServiceChip = find.widgetWithText(ChoiceChip, 'In Service');
      await tester.tap(inServiceChip);
      await tester.pumpAndSettle();

      // Shure SM58 should now appear under In Service
      expect(find.text('Shure SM58 Vocal Microphone'), findsOneWidget);
    });

    testWidgets('InventoryScreen sorts items alphabetically', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      mockDb.reset();
      DatabaseService.instance = mockDb;

      await tester.pumpWidget(const MaterialApp(home: InventoryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final itemNames = tester.widgetList<Text>(find.descendant(
        of: find.byType(Card),
        matching: find.byType(Text),
      )).map((t) => t.data).where((data) => data != null && (data.contains('Mixer') || data.contains('Camera') || data.contains('Microphone') || data.contains('Stand') || data.contains('Gimbal'))).toList();

      final sortedItemNames = List<String>.from(itemNames)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      expect(itemNames, equals(sortedItemNames));
    });

    testWidgets('InventoryScreen search works by name, brand, model, ID, serialNumber', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      mockDb.reset();
      DatabaseService.instance = mockDb;

      await tester.pumpWidget(const MaterialApp(home: InventoryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Search by serial number
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'SH-589201');
      await tester.pumpAndSettle();
      expect(find.text('Shure SM58 Vocal Microphone'), findsOneWidget);
      expect(find.text('Behringer X32 Digital Mixer'), findsNothing);

      // Search by ID
      await tester.enterText(searchField, 'VID-001');
      await tester.pumpAndSettle();
      expect(find.text('Sony FX3 Cinema Camera'), findsOneWidget);
      expect(find.text('Shure SM58 Vocal Microphone'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 7: Widget Tests — CreateEventScreen Quantity Flows
  // ═══════════════════════════════════════════════════════════════════════════
  group('CreateEventScreen — quantity flows', () {
    testWidgets('bypasses quantity dialog when available quantity is 1', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreateEventScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('No items selected yet.'), findsOneWidget);

      final addItemButton = find.widgetWithText(ElevatedButton, 'Add Item');
      await tester.tap(addItemButton);
      await tester.pumpAndSettle();

      final bottomSheetSearchField = find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(TextField));
      await tester.enterText(bottomSheetSearchField, 'Shure');
      await tester.pumpAndSettle();

      final shureText = find.text('Shure SM58 Vocal Microphone');
      expect(shureText, findsOneWidget);

      final addButtons = find.widgetWithText(ElevatedButton, 'Add');
      expect(addButtons, findsOneWidget);
      await tester.tap(addButtons);
      await tester.pumpAndSettle();

      // Quantity dialog should NOT appear for single-quantity items
      expect(find.textContaining('Quantity to Check-out'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text('Shure SM58 Vocal Microphone'), findsOneWidget);
      expect(find.text('Quantity: 1'), findsOneWidget);
    });

    testWidgets('shows quantity dialog for multi-quantity items and validates input', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      DatabaseService.instance = mockDb;
      final now = DateTime.now();

      await mockDb.addItem(Item(
        id: 'MULT-001',
        name: 'Multi-item Mic Stand',
        category: 'Audio',
        brand: 'K&M',
        model: 'Boom',
        serialNumber: 'SN-MULT',
        status: 'Available',
        lastAudited: now,
        nextAuditDue: now.add(const Duration(days: 30)),
        addedDate: now,
        quantity: 5,
      ));

      await tester.pumpWidget(const MaterialApp(home: CreateEventScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
      await tester.pumpAndSettle();

      final bottomSheetSearchField = find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(TextField));
      await tester.enterText(bottomSheetSearchField, 'MULT');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      // Quantity dialog should appear
      expect(find.textContaining('Quantity to Check-out'), findsOneWidget);

      // Enter valid quantity
      final qtyField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(qtyField, '3');
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Add'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Selected: 3'), findsOneWidget);
    });

    testWidgets('search filters items by name, brand, and model', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreateEventScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).last;

      // Search by brand
      await tester.enterText(searchField, 'Shure');
      await tester.pumpAndSettle();
      expect(find.textContaining('Brand: Shure'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Model: SM58'), findsAtLeastNWidgets(1));

      // Search by different brand
      await tester.enterText(searchField, 'Sony');
      await tester.pumpAndSettle();
      expect(find.text('Shure SM58 Vocal Microphone'), findsNothing);
      expect(find.text('Sony FX3 Cinema Camera'), findsOneWidget);

      // Search by model
      await tester.enterText(searchField, 'X32');
      await tester.pumpAndSettle();
      expect(find.text('Behringer X32 Digital Mixer'), findsOneWidget);
    });

    testWidgets('search persists after StatefulBuilder rebuild', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreateEventScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).last;
      await tester.enterText(searchField, 'Sony');
      await tester.pumpAndSettle();

      // Simulate a rebuild
      final statefulBuilderFinder = find.byType(StatefulBuilder);
      expect(statefulBuilderFinder, findsOneWidget);
      tester.element(statefulBuilderFinder).markNeedsBuild();
      await tester.pumpAndSettle();

      // Search filter remains active
      expect(find.text('Shure SM58 Vocal Microphone'), findsNothing);
      expect(find.text('Sony FX3 Cinema Camera'), findsOneWidget);
    });

    testWidgets('interactive add, modify, and remove without closing bottom sheet', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      DatabaseService.instance = mockDb;
      final now = DateTime.now();

      await mockDb.addItem(Item(
        id: 'MULT-001',
        name: 'Multi-item Mic Stand',
        category: 'Audio',
        brand: 'K&M',
        model: 'Boom',
        serialNumber: 'SN-MULT',
        status: 'Available',
        lastAudited: now,
        nextAuditDue: now.add(const Duration(days: 30)),
        addedDate: now,
        quantity: 5,
      ));

      await tester.pumpWidget(const MaterialApp(home: CreateEventScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
      await tester.pumpAndSettle();

      final bottomSheetSearchField = find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(TextField));

      // Add Shure SM58 (qty 1) — should auto-add without dialog
      await tester.enterText(bottomSheetSearchField, 'Shure');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Selected: 1'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Modify'), findsNothing);

      // Add Multi-item (qty 5) via dialog
      await tester.enterText(bottomSheetSearchField, 'MULT');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Quantity to Check-out'), findsOneWidget);
      final qtyField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(qtyField, '2');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Add'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Selected: 2'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Modify'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Remove'), findsOneWidget);

      // Modify Multi-item to qty 3
      await tester.tap(find.widgetWithText(ElevatedButton, 'Modify'));
      await tester.pumpAndSettle();
      expect(find.text('Modify Multi-item Mic Stand'), findsOneWidget);

      final modifyQtyField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(modifyQtyField, '3');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Save'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Selected: 3'), findsOneWidget);

      // Remove Shure SM58
      await tester.enterText(bottomSheetSearchField, 'Shure');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Add'), findsOneWidget);

      // Done → verify main screen
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text('Shure SM58 Vocal Microphone'), findsNothing);
      expect(find.text('Multi-item Mic Stand'), findsOneWidget);
      expect(find.text('Quantity: 3'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 8: Widget Tests — EventDetailsScreen
  // ═══════════════════════════════════════════════════════════════════════════
  group('EventDetailsScreen — batch returns and deletion', () {
    testWidgets('allows selecting items via checkboxes and returning them', (WidgetTester tester) async {
      final testEvent = EventRecord(
        id: 'test-event-123',
        eventName: 'Sunday Service Live',
        eventDate: DateTime.now(),
        items: [
          EventItem(itemId: 'AUD-001', quantityTaken: 1, quantityReturned: 0),
          EventItem(itemId: 'VID-001', quantityTaken: 2, quantityReturned: 1),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: EventDetailsScreen(event: testEvent)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Sunday Service Live'), findsOneWidget);
      expect(find.text('Shure SM58 Vocal Microphone'), findsOneWidget);
      expect(find.text('Sony FX3 Cinema Camera'), findsOneWidget);
      expect(find.textContaining('Brand: Shure'), findsWidgets);
      expect(find.textContaining('Brand: Sony'), findsWidgets);

      expect(find.textContaining('Return Selected Items'), findsNothing);

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));

      await tester.tap(checkboxes.first);
      await tester.pump();
      expect(find.textContaining('Return Selected Items (1)'), findsOneWidget);

      await tester.tap(checkboxes.last);
      await tester.pump();
      expect(find.textContaining('Return Selected Items (2)'), findsOneWidget);

      await tester.tap(find.textContaining('Return Selected Items (2)'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Return Selected Items'), findsNothing);
    });

    testWidgets('blocks deletion of active events', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      DatabaseService.instance = mockDb;

      final activeEvent = EventRecord(
        id: 'active-event',
        eventName: 'Active Camp',
        eventDate: DateTime.now(),
        items: [
          EventItem(itemId: 'AUD-001', quantityTaken: 1, quantityReturned: 0),
        ],
      );

      await tester.pumpWidget(MaterialApp(home: EventDetailsScreen(event: activeEvent)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cannot delete active event'), findsOneWidget);
      expect(find.text('Delete Event?'), findsNothing);
    });

    testWidgets('allows deletion of completed events', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      DatabaseService.instance = mockDb;

      await mockDb.createEvent('Completed Concert', DateTime.now(), [
        EventItem(itemId: 'AUD-002', quantityTaken: 1, quantityReturned: 1),
      ]);
      final eventInDb = (await mockDb.eventsStream.first).firstWhere((e) => e.eventName == 'Completed Concert');

      await tester.pumpWidget(MaterialApp(home: EventDetailsScreen(event: eventInDb)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete Event?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      final events = await mockDb.eventsStream.first;
      expect(events.any((e) => e.id == eventInDb.id), isFalse);
    });

    testWidgets('prompts for quantity when returning multi-quantity item', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      mockDb.reset();
      DatabaseService.instance = mockDb;

      await mockDb.createEvent('Multi Return Event', DateTime.now(), [
        EventItem(itemId: 'VID-001', quantityTaken: 3, quantityReturned: 0),
      ]);
      final eventInDb = (await mockDb.eventsStream.first).firstWhere((e) => e.eventName == 'Multi Return Event');

      await tester.pumpWidget(MaterialApp(home: EventDetailsScreen(event: eventInDb)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap checkbox
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Dialog should show up for multi-quantity
      expect(find.text('Return Sony FX3 Cinema Camera'), findsOneWidget);

      // Test validation: exceed remaining quantity (3)
      final qtyField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(qtyField, '4');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Return'));
      await tester.pumpAndSettle();
      expect(find.text('Cannot exceed 3'), findsOneWidget);

      // Enter valid quantity
      await tester.enterText(qtyField, '2');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Return'));
      await tester.pumpAndSettle();

      expect(find.text('Return Sony FX3 Cinema Camera'), findsNothing);
      expect(find.textContaining('Returning: 2'), findsOneWidget);

      // Execute batch return
      final batchReturnButton = find.widgetWithText(ElevatedButton, 'Return Selected Items (1)');
      expect(batchReturnButton, findsOneWidget);
      await tester.tap(batchReturnButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final events = await mockDb.eventsStream.first;
      final updatedEvent = events.firstWhere((e) => e.id == eventInDb.id);
      expect(updatedEvent.items.firstWhere((i) => i.itemId == 'VID-001').quantityReturned, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 9: Widget Tests — Edit Event Constraints with Specification Quantity
  // ═══════════════════════════════════════════════════════════════════════════
  group('Edit Event — quantity constraints from returned quantities', () {
    testWidgets('edit mode opens, allows modifying items, and saves changes', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      mockDb.reset();
      DatabaseService.instance = mockDb;

      await mockDb.createEvent('Concert check-out', DateTime.now(), [
        EventItem(itemId: 'AUD-001', quantityTaken: 1, quantityReturned: 0),
        EventItem(itemId: 'AUD-002', quantityTaken: 1, quantityReturned: 0),
      ]);

      final event = (await mockDb.eventsStream.first).first;

      await tester.pumpWidget(MaterialApp(home: EventDetailsScreen(event: event)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Concert check-out'), findsOneWidget);

      // Tap Edit icon
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(find.text('Edit Event'), findsOneWidget);

      // Edit event name
      final nameField = find.widgetWithText(TextFormField, 'Event Name');
      await tester.enterText(nameField, 'Concert check-out edited');
      await tester.pumpAndSettle();

      // Add K&M Stand via bottom sheet
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
      await tester.pumpAndSettle();

      final bottomSheetSearchField = find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(TextField));
      await tester.enterText(bottomSheetSearchField, 'K&M');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      // Save changes
      final saveButton = find.widgetWithText(ElevatedButton, 'Save Changes');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Concert check-out edited'), findsOneWidget);
      expect(find.text('K&M Boom Mic Stand Black'), findsOneWidget);

      final updatedEvent = (await mockDb.eventsStream.first).first;
      expect(updatedEvent.eventName, 'Concert check-out edited');
      expect(updatedEvent.items.any((i) => i.itemId == 'AUD-004'), isTrue);
    });

    testWidgets('enforces removal and modify constraints based on returned quantities', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      mockDb.reset();
      DatabaseService.instance = mockDb;

      final now = DateTime.now();
      await mockDb.addItem(Item(
        id: 'MULT-001',
        name: 'Multi-item Mic Stand',
        category: 'Audio',
        brand: 'K&M',
        model: 'Boom',
        serialNumber: 'SN-MULT',
        status: 'Available',
        lastAudited: now,
        nextAuditDue: now.add(const Duration(days: 30)),
        addedDate: now,
        quantity: 5,
      ));

      // Shure SM58 (Qty 1): fully returned
      // Multi-item (Qty 5): 3 checked out, 1 returned
      await mockDb.createEvent('Partially Returned Event', DateTime.now(), [
        EventItem(itemId: 'AUD-001', quantityTaken: 1, quantityReturned: 1),
        EventItem(itemId: 'MULT-001', quantityTaken: 3, quantityReturned: 1),
      ]);

      final event = (await mockDb.eventsStream.first).first;

      // Pump Edit Screen directly
      await tester.pumpWidget(MaterialApp(home: CreateEventScreen(event: event)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Try to remove Shure SM58 (has quantityReturned: 1 — should be blocked)
      final shureRemoveIcon = find.descendant(
        of: find.widgetWithText(Card, 'Shure SM58 Vocal Microphone'),
        matching: find.byIcon(Icons.remove_circle),
      );
      expect(shureRemoveIcon, findsOneWidget);
      await tester.tap(shureRemoveIcon);
      await tester.pumpAndSettle();

      expect(find.text('Shure SM58 Vocal Microphone'), findsOneWidget); // still there
      expect(find.textContaining('Cannot remove "Shure SM58 Vocal Microphone"'), findsOneWidget);

      // Modify Multi-item Mic Stand and try to set quantity below returned amount
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
      await tester.pumpAndSettle();

      final bottomSheetSearchField = find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(TextField));
      await tester.enterText(bottomSheetSearchField, 'Multi-item');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Modify'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Modify Multi-item Mic Stand'), findsOneWidget);

      final qtyField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(qtyField, '0');
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Save'),
      ));
      await tester.pumpAndSettle();

      // Validator should block — min is 1 (returned qty)
      expect(find.text('Must be >= 1'), findsOneWidget);
      expect(find.textContaining('Modify Multi-item Mic Stand'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 10: Widget Tests — Bottom Sheet Sort Order
  // ═══════════════════════════════════════════════════════════════════════════
  group('Bottom sheet item sorting', () {
    testWidgets('select items bottom sheet sorts items alphabetically', (WidgetTester tester) async {
      final mockDb = MockDatabaseService();
      mockDb.reset();
      DatabaseService.instance = mockDb;

      await tester.pumpWidget(const MaterialApp(home: CreateEventScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
      await tester.pumpAndSettle();

      final bottomSheetItemNames = tester.widgetList<Text>(find.descendant(
        of: find.byType(ListTile),
        matching: find.byType(Text),
      )).map((t) => t.data).where((data) => data != null && (data.contains('Mixer') || data.contains('Camera') || data.contains('Microphone') || data.contains('Stand') || data.contains('Gimbal') || data.contains('Cable') || data.contains('Projector') || data.contains('Converter') || data.contains('TV') || data.contains('Switcher'))).toList();

      final sortedBottomSheetNames = List<String>.from(bottomSheetItemNames)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      expect(bottomSheetItemNames, equals(sortedBottomSheetNames));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 11: MockDatabaseService — Event Update Edge Cases
  // ═══════════════════════════════════════════════════════════════════════════
  group('MockDatabaseService — event update edge cases', () {
    test('updateEvent preserves quantityReturned from original items', () async {
      final mockDb = MockDatabaseService();

      await mockDb.createEvent('Preserve Returns', DateTime.now(), [
        EventItem(itemId: 'AUD-001', quantityTaken: 1, quantityReturned: 0),
      ]);

      final events = await mockDb.eventsStream.first;
      final event = events.first;

      // Return the item
      await mockDb.returnEventItem(event.id, 'AUD-001', 1);

      // Now update event — quantityReturned should be preserved
      await mockDb.updateEvent(event.id, 'Updated Preserve', DateTime.now(), [
        EventItem(itemId: 'AUD-001', quantityTaken: 1, quantityReturned: 0), // caller passes 0, service preserves original
      ]);

      final updatedEvents = await mockDb.eventsStream.first;
      final updatedEvent = updatedEvents.firstWhere((e) => e.id == event.id);
      expect(updatedEvent.items.first.quantityReturned, 1); // preserved!
    });

    test('updateEvent adjusts outForEventQuantity when increasing quantity', () async {
      final mockDb = MockDatabaseService();

      // Give VID-001 a higher quantity so we can increase event allocation
      final vid001 = await mockDb.getItemById('VID-001');
      await mockDb.updateItem(vid001!.copyWith(quantity: 10));

      await mockDb.createEvent('Scale Up', DateTime.now(), [
        EventItem(itemId: 'VID-001', quantityTaken: 2, quantityReturned: 0),
      ]);

      var item = await mockDb.getItemById('VID-001');
      expect(item!.outForEventQuantity, 2);

      final events = await mockDb.eventsStream.first;
      final event = events.first;

      // Increase to 5
      await mockDb.updateEvent(event.id, 'Scaled Up', DateTime.now(), [
        EventItem(itemId: 'VID-001', quantityTaken: 5, quantityReturned: 0),
      ]);

      item = await mockDb.getItemById('VID-001');
      expect(item!.outForEventQuantity, 5);
    });

    test('updateEvent throws when event not found', () async {
      final mockDb = MockDatabaseService();
      expect(
        () => mockDb.updateEvent('nonexistent', 'X', DateTime.now(), []),
        throwsException,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 12: MockDatabaseService — Stream and getItemById
  // ═══════════════════════════════════════════════════════════════════════════
  group('MockDatabaseService — streams and lookups', () {
    test('itemsStream emits initial data and then updates', () async {
      final mockDb = MockDatabaseService();
      mockDb.reset();

      final initialItems = await mockDb.itemsStream.first;
      expect(initialItems.length, greaterThan(0));

      final now = DateTime.now();
      await mockDb.addItem(Item(
        id: 'STREAM-001',
        name: 'Stream Test Item',
        category: 'Audio',
        brand: 'B',
        model: 'M',
        serialNumber: 'SN',
        status: 'Available',
        lastAudited: now,
        nextAuditDue: now.add(const Duration(days: 30)),
        addedDate: now,
        quantity: 3,
      ));

      final updatedItems = await mockDb.itemsStream.first;
      expect(updatedItems.any((i) => i.id == 'STREAM-001'), true);
    });

    test('getItemById returns null for nonexistent ID', () async {
      final mockDb = MockDatabaseService();
      final item = await mockDb.getItemById('DOES-NOT-EXIST');
      expect(item, isNull);
    });

    test('eventsStream emits initial data', () async {
      final mockDb = MockDatabaseService();
      mockDb.reset();
      final events = await mockDb.eventsStream.first;
      expect(events, isList);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 13: MockDatabaseService — Multiple Service Records
  // ═══════════════════════════════════════════════════════════════════════════
  group('MockDatabaseService — multiple service dispatches', () {
    test('multiple sendToService calls accumulate inServiceQuantity', () async {
      final mockDb = MockDatabaseService();

      final item = await mockDb.getItemById('AUD-002');
      await mockDb.updateItem(item!.copyWith(quantity: 20));

      await mockDb.sendToService('AUD-002', 'Issue A', DateTime.now().add(const Duration(days: 7)), 5);
      await mockDb.sendToService('AUD-002', 'Issue B', DateTime.now().add(const Duration(days: 14)), 3);

      final updated = await mockDb.getItemById('AUD-002');
      expect(updated!.inServiceQuantity, 8);
      expect(updated.availableQty, 12);

      final history = await mockDb.getServiceHistory('AUD-002');
      final activeRecords = history.where((r) => !r.isReturned).toList();
      expect(activeRecords.length, 2);
    });

    test('returning one service record only decrements its quantity', () async {
      final mockDb = MockDatabaseService();

      final item = await mockDb.getItemById('AUD-002');
      await mockDb.updateItem(item!.copyWith(quantity: 20));

      await mockDb.sendToService('AUD-002', 'Issue A', DateTime.now().add(const Duration(days: 7)), 5);
      await mockDb.sendToService('AUD-002', 'Issue B', DateTime.now().add(const Duration(days: 14)), 3);

      final history = await mockDb.getServiceHistory('AUD-002');
      final firstActive = history.firstWhere((r) => !r.isReturned && r.issueDescription == 'Issue A');

      await mockDb.returnFromService('AUD-002', firstActive.id, 'Fixed A');

      final updated = await mockDb.getItemById('AUD-002');
      expect(updated!.inServiceQuantity, 3); // 8 - 5 = 3
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 14: MockDatabaseService — Audit History ordering
  // ═══════════════════════════════════════════════════════════════════════════
  group('MockDatabaseService — audit history', () {
    test('audit history is sorted newest first', () async {
      final mockDb = MockDatabaseService();

      // Mock data already has AUDIT-001 for AUD-001
      // Add another audit
      await mockDb.auditItem('AUD-001', 'user1@test.com', 'Good', 'First re-audit');
      await Future.delayed(const Duration(milliseconds: 10));
      await mockDb.auditItem('AUD-001', 'user2@test.com', 'Requires Repair', 'Second re-audit');

      final history = await mockDb.getAuditHistory('AUD-001');
      expect(history.length, greaterThanOrEqualTo(2));
      // Newest first
      for (int i = 0; i < history.length - 1; i++) {
        expect(history[i].auditDate.isAfter(history[i + 1].auditDate) ||
            history[i].auditDate.isAtSameMomentAs(history[i + 1].auditDate), true);
      }
    });

    test('service history is sorted newest first', () async {
      final mockDb = MockDatabaseService();

      final item = await mockDb.getItemById('AUD-001');
      await mockDb.updateItem(item!.copyWith(quantity: 10));

      await mockDb.sendToService('AUD-001', 'Issue 1', DateTime.now().add(const Duration(days: 7)), 1);
      await Future.delayed(const Duration(milliseconds: 10));
      await mockDb.sendToService('AUD-001', 'Issue 2', DateTime.now().add(const Duration(days: 14)), 2);

      final history = await mockDb.getServiceHistory('AUD-001');
      for (int i = 0; i < history.length - 1; i++) {
        expect(history[i].sentDate.isAfter(history[i + 1].sentDate) ||
            history[i].sentDate.isAtSameMomentAs(history[i + 1].sentDate), true);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 15: MockDatabaseService — updateItemStatus
  // ═══════════════════════════════════════════════════════════════════════════
  group('MockDatabaseService — updateItemStatus', () {
    test('updateItemStatus changes item status', () async {
      final mockDb = MockDatabaseService();

      await mockDb.updateItemStatus('AUD-001', 'In Service');
      final item = await mockDb.getItemById('AUD-001');
      expect(item!.status, 'In Service');

      await mockDb.updateItemStatus('AUD-001', 'Available');
      final item2 = await mockDb.getItemById('AUD-001');
      expect(item2!.status, 'Available');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 16: MockDatabaseService — deleteEvent
  // ═══════════════════════════════════════════════════════════════════════════
  group('MockDatabaseService — deleteEvent', () {
    test('deleteEvent removes event from list', () async {
      final mockDb = MockDatabaseService();
      mockDb.reset();

      await mockDb.createEvent('To Delete', DateTime.now(), [
        EventItem(itemId: 'AUD-001', quantityTaken: 1, quantityReturned: 0),
      ]);

      var events = await mockDb.eventsStream.first;
      final eventId = events.firstWhere((e) => e.eventName == 'To Delete').id;

      await mockDb.deleteEvent(eventId);

      events = await mockDb.eventsStream.first;
      expect(events.any((e) => e.id == eventId), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP 17: Item Model — Edge Cases
  // ═══════════════════════════════════════════════════════════════════════════
  group('Item Model — edge cases', () {
    test('availableQty clamps to 0 when overallocated', () {
      final item = Item(
        id: 'EDGE-001',
        name: 'Overallocated',
        category: 'Audio',
        brand: 'B',
        model: 'M',
        serialNumber: 'SN',
        status: 'Available',
        lastAudited: DateTime.now(),
        nextAuditDue: DateTime.now().add(const Duration(days: 30)),
        addedDate: DateTime.now(),
        quantity: 2,
        inServiceQuantity: 3, // more than quantity!
        outForEventQuantity: 0,
      );
      expect(item.availableQty, 0); // clamped to 0
    });

    test('copyWith without any arguments returns identical values', () {
      final item = Item(
        id: 'COPY-001',
        name: 'Copy Test',
        category: 'Video',
        brand: 'Brand',
        model: 'Model',
        serialNumber: 'SN-COPY',
        status: 'Available',
        lastAudited: DateTime(2026, 1, 1),
        nextAuditDue: DateTime(2026, 2, 1),
        addedDate: DateTime(2025, 6, 1),
        quantity: 7,
        auditedQuantity: 3,
        inServiceQuantity: 2,
        outForEventQuantity: 1,
      );
      final copy = item.copyWith();
      expect(copy.id, item.id);
      expect(copy.name, item.name);
      expect(copy.category, item.category);
      expect(copy.brand, item.brand);
      expect(copy.model, item.model);
      expect(copy.serialNumber, item.serialNumber);
      expect(copy.status, item.status);
      expect(copy.quantity, item.quantity);
      expect(copy.auditedQuantity, item.auditedQuantity);
      expect(copy.inServiceQuantity, item.inServiceQuantity);
      expect(copy.outForEventQuantity, item.outForEventQuantity);
    });
  });
}
