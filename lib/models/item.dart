class Item {
  final String id;
  final String name;
  final String category; // 'Audio' or 'Video'
  final String brand;
  final String model;
  final String serialNumber;
  final String status; // 'Available', 'In Service'
  final DateTime lastAudited;
  final DateTime nextAuditDue;
  final DateTime addedDate;

  Item({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.model,
    required this.serialNumber,
    required this.status,
    required this.lastAudited,
    required this.nextAuditDue,
    required this.addedDate,
  });

  bool get isAuditDue {
    return DateTime.now().isAfter(nextAuditDue);
  }

  Item copyWith({
    String? name,
    String? category,
    String? brand,
    String? model,
    String? serialNumber,
    String? status,
    DateTime? lastAudited,
    DateTime? nextAuditDue,
    DateTime? addedDate,
  }) {
    return Item(
      id: this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      status: status ?? this.status,
      lastAudited: lastAudited ?? this.lastAudited,
      nextAuditDue: nextAuditDue ?? this.nextAuditDue,
      addedDate: addedDate ?? this.addedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'brand': brand,
      'model': model,
      'serialNumber': serialNumber,
      'status': status,
      'lastAudited': lastAudited.toIso8601String(),
      'nextAuditDue': nextAuditDue.toIso8601String(),
      'addedDate': addedDate.toIso8601String(),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
      serialNumber: map['serialNumber'] ?? '',
      status: map['status'] ?? 'Available',
      lastAudited: map['lastAudited'] != null
          ? DateTime.parse(map['lastAudited'])
          : DateTime.now(),
      nextAuditDue: map['nextAuditDue'] != null
          ? DateTime.parse(map['nextAuditDue'])
          : DateTime.now(),
      addedDate: map['addedDate'] != null
          ? DateTime.parse(map['addedDate'])
          : DateTime.now(),
    );
  }
}
