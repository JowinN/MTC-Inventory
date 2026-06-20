class EventItem {
  final String itemId;
  final int quantityTaken;
  final int quantityReturned;

  EventItem({
    required this.itemId,
    required this.quantityTaken,
    this.quantityReturned = 0,
  });

  bool get isFullyReturned => quantityReturned >= quantityTaken;

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'quantityTaken': quantityTaken,
      'quantityReturned': quantityReturned,
    };
  }

  factory EventItem.fromMap(Map<String, dynamic> map) {
    return EventItem(
      itemId: map['itemId'] ?? '',
      quantityTaken: map['quantityTaken'] ?? 1,
      quantityReturned: map['quantityReturned'] ?? 0,
    );
  }
}

class EventRecord {
  final String id;
  final String eventName;
  final DateTime eventDate;
  final List<EventItem> items;

  EventRecord({
    required this.id,
    required this.eventName,
    required this.eventDate,
    required this.items,
  });

  bool get isCompleted => items.isNotEmpty && items.every((item) => item.isFullyReturned);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventName': eventName,
      'eventDate': eventDate.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory EventRecord.fromMap(Map<String, dynamic> map) {
    return EventRecord(
      id: map['id'] ?? '',
      eventName: map['eventName'] ?? '',
      eventDate: map['eventDate'] != null ? DateTime.parse(map['eventDate']) : DateTime.now(),
      items: (map['items'] as List<dynamic>?)
              ?.map((itemMap) => EventItem.fromMap(itemMap as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
