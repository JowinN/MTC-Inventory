class AuditRecord {
  final String id;
  final String itemId;
  final DateTime auditDate;
  final String auditorEmail;
  final String condition; // 'Good', 'Requires Repair'
  final String notes;

  AuditRecord({
    required this.id,
    required this.itemId,
    required this.auditDate,
    required this.auditorEmail,
    required this.condition,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'auditDate': auditDate.toIso8601String(),
      'auditorEmail': auditorEmail,
      'condition': condition,
      'notes': notes,
    };
  }

  factory AuditRecord.fromMap(Map<String, dynamic> map) {
    return AuditRecord(
      id: map['id'] ?? '',
      itemId: map['itemId'] ?? '',
      auditDate: map['auditDate'] != null
          ? DateTime.parse(map['auditDate'])
          : DateTime.now(),
      auditorEmail: map['auditorEmail'] ?? '',
      condition: map['condition'] ?? 'Good',
      notes: map['notes'] ?? '',
    );
  }
}
