class Meter {
  final String id;
  final String nickname;
  final String company;
  final String referenceNumber;
  final String? consumerId;
  final String? notes;
  final int? monthlyLimit;
  final String createdAt;
  final String? lastScanAt;
  final String? lastBillFetchAt;
  final String? nextReadingDateOverride;
  final String kind;
  final int readingDay;

  Meter({
    required this.id,
    required this.nickname,
    required this.company,
    required this.referenceNumber,
    this.consumerId,
    this.notes,
    this.monthlyLimit,
    required this.createdAt,
    this.lastScanAt,
    this.lastBillFetchAt,
    this.nextReadingDateOverride,
    this.kind = 'home',
    this.readingDay = 10,
  });

  factory Meter.fromJson(Map<String, dynamic> json) {
    return Meter(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      company: json['company'] as String,
      referenceNumber: json['referenceNumber'] as String,
      consumerId: json['consumerId'] as String?,
      notes: json['notes'] as String?,
      monthlyLimit: json['monthlyLimit'] as int?,
      createdAt: json['createdAt'] as String,
      lastScanAt: json['lastScanAt'] as String?,
      lastBillFetchAt: json['lastBillFetchAt'] as String?,
      nextReadingDateOverride: json['nextReadingDateOverride'] as String?,
      kind: json['kind'] as String? ?? 'home',
      readingDay: json['readingDay'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'company': company,
      'referenceNumber': referenceNumber,
      'consumerId': consumerId,
      'notes': notes,
      'monthlyLimit': monthlyLimit,
      'createdAt': createdAt,
      'lastScanAt': lastScanAt,
      'lastBillFetchAt': lastBillFetchAt,
      'nextReadingDateOverride': nextReadingDateOverride,
      'kind': kind,
      'readingDay': readingDay,
    };
  }

  Meter copyWith({
    String? nickname,
    String? company,
    String? referenceNumber,
    String? consumerId,
    String? notes,
    int? monthlyLimit,
    String? lastScanAt,
    String? lastBillFetchAt,
    String? nextReadingDateOverride,
    bool clearNextReadingDateOverride = false,
    String? kind,
    int? readingDay,
  }) {
    return Meter(
      id: id,
      nickname: nickname ?? this.nickname,
      company: company ?? this.company,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      consumerId: consumerId ?? this.consumerId,
      notes: notes ?? this.notes,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      createdAt: createdAt,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      lastBillFetchAt: lastBillFetchAt ?? this.lastBillFetchAt,
      nextReadingDateOverride: clearNextReadingDateOverride
          ? null
          : nextReadingDateOverride ?? this.nextReadingDateOverride,
      kind: kind ?? this.kind,
      readingDay: readingDay ?? this.readingDay,
    );
  }
}

class Reading {
  final String id;
  final String meterId;
  final int currentReading;
  final String scannedAt;
  final int previousReading;
  final String cycleStart;
  final String cycleEnd;
  final int unitsConsumed;
  final String source;
  final String billingMonth;

  Reading({
    required this.id,
    required this.meterId,
    required this.currentReading,
    required this.scannedAt,
    required this.previousReading,
    required this.cycleStart,
    required this.cycleEnd,
    required this.unitsConsumed,
    required this.source,
    required this.billingMonth,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['id'] as String,
      meterId: json['meterId'] as String,
      currentReading: json['currentReading'] as int,
      scannedAt: json['scannedAt'] as String,
      previousReading: json['previousReading'] as int,
      cycleStart: json['cycleStart'] as String,
      cycleEnd: json['cycleEnd'] as String,
      unitsConsumed: json['unitsConsumed'] as int,
      source: json['source'] as String? ?? 'ocr',
      billingMonth: json['billingMonth'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meterId': meterId,
      'currentReading': currentReading,
      'scannedAt': scannedAt,
      'previousReading': previousReading,
      'cycleStart': cycleStart,
      'cycleEnd': cycleEnd,
      'unitsConsumed': unitsConsumed,
      'source': source,
      'billingMonth': billingMonth,
    };
  }
}

class BillInfo {
  final String meterId;
  final String fetchedAt;
  final String referenceNumber;
  final String? consumerId;
  final String company;
  final String billingMonth;
  final int previousReading;
  final int currentReading;
  final String readingDate;
  final String nextReadingDate;
  final int unitsBilled;
  final int? amountPkr;
  final String? dueDate;
  final String status;

  BillInfo({
    required this.meterId,
    required this.fetchedAt,
    required this.referenceNumber,
    this.consumerId,
    required this.company,
    required this.billingMonth,
    required this.previousReading,
    required this.currentReading,
    required this.readingDate,
    required this.nextReadingDate,
    required this.unitsBilled,
    this.amountPkr,
    this.dueDate,
    required this.status,
  });

  factory BillInfo.fromJson(Map<String, dynamic> json) {
    return BillInfo(
      meterId: json['meterId'] as String,
      fetchedAt: json['fetchedAt'] as String,
      referenceNumber: json['referenceNumber'] as String,
      consumerId: json['consumerId'] as String?,
      company: json['company'] as String,
      billingMonth: json['billingMonth'] as String,
      previousReading: json['previousReading'] as int,
      currentReading: json['currentReading'] as int,
      readingDate: json['readingDate'] as String,
      nextReadingDate: json['nextReadingDate'] as String,
      unitsBilled: json['unitsBilled'] as int,
      amountPkr: json['amountPkr'] as int?,
      dueDate: json['dueDate'] as String?,
      status: json['status'] as String? ?? 'available',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meterId': meterId,
      'fetchedAt': fetchedAt,
      'referenceNumber': referenceNumber,
      'consumerId': consumerId,
      'company': company,
      'billingMonth': billingMonth,
      'previousReading': previousReading,
      'currentReading': currentReading,
      'readingDate': readingDate,
      'nextReadingDate': nextReadingDate,
      'unitsBilled': unitsBilled,
      'amountPkr': amountPkr,
      'dueDate': dueDate,
      'status': status,
    };
  }
}

class Alert {
  final String key;
  final String meterId;
  final String meterName;
  final String tone; // "info" | "warn" | "danger" | "good"
  final String title;
  final String body;

  Alert({
    required this.key,
    required this.meterId,
    required this.meterName,
    required this.tone,
    required this.title,
    required this.body,
  });
}
