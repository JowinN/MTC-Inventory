class ServiceRecord {
  final String id;
  final String itemId;
  final DateTime sentDate;
  final DateTime expectedReturnDate;
  final DateTime? actualReturnDate;
  final String issueDescription;
  final String resolutionNotes;
  final int quantity;

  ServiceRecord({
    required this.id,
    required this.itemId,
    required this.sentDate,
    required this.expectedReturnDate,
    this.actualReturnDate,
    required this.issueDescription,
    required this.resolutionNotes,
    this.quantity = 1,
  });

  bool get isReturned {
    return actualReturnDate != null;
  }

  bool get isOverdue {
    return actualReturnDate == null && DateTime.now().isAfter(expectedReturnDate);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'sentDate': sentDate.toIso8601String(),
      'expectedReturnDate': expectedReturnDate.toIso8601String(),
      'actualReturnDate': actualReturnDate?.toIso8601String(),
      'issueDescription': issueDescription,
      'resolutionNotes': resolutionNotes,
      'quantity': quantity,
    };
  }

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    return ServiceRecord(
      id: map['id'] ?? '',
      itemId: map['itemId'] ?? '',
      sentDate: map['sentDate'] != null
          ? DateTime.parse(map['sentDate'])
          : DateTime.now(),
      expectedReturnDate: map['expectedReturnDate'] != null
          ? DateTime.parse(map['expectedReturnDate'])
          : DateTime.now(),
      actualReturnDate: map['actualReturnDate'] != null
          ? DateTime.parse(map['actualReturnDate'])
          : null,
      issueDescription: map['issueDescription'] ?? '',
      resolutionNotes: map['resolutionNotes'] ?? '',
      quantity: map['quantity'] ?? 1,
    );
  }
}
