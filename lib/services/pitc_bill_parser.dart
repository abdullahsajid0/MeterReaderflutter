import 'package:html/parser.dart' as html_parser;

class ParsedPitcBill {
  final String? referenceNumber;
  final String? consumerId;
  final String? billingMonth;
  final int? previousReading;
  final int? currentReading;
  final String? readingDate;
  final int? unitsBilled;
  final int? amountPkr;
  final String? dueDate;

  const ParsedPitcBill({
    required this.referenceNumber,
    required this.consumerId,
    required this.billingMonth,
    required this.previousReading,
    required this.currentReading,
    required this.readingDate,
    required this.unitsBilled,
    required this.amountPkr,
    required this.dueDate,
  });
}

ParsedPitcBill? parsePitcBillHtml(String source) {
  final document = html_parser.parse(source);
  final text = document.body?.text ?? '';
  final previous = _valueAfterLabel(text, 'PREVIOUS READING');
  final current = _valueAfterLabel(text, 'PRESENT READING');
  final units = _valueAfterLabel(text, 'UNITS');
  if (previous == null && current == null && units == null) return null;

  final readingDate = _dateAfterLabel(text, 'READING DATE');
  final billMonth =
      _monthAfterLabel(text, 'BILL MONTH') ?? readingDate?.substring(0, 7);
  return ParsedPitcBill(
    referenceNumber: _textAfterLabel(text, 'REFERENCE NO'),
    consumerId: _textAfterLabel(text, 'CONSUMER ID'),
    billingMonth: billMonth,
    previousReading: previous,
    currentReading: current,
    readingDate: readingDate,
    unitsBilled: units,
    amountPkr: _valueAfterLabel(text, 'PAYABLE'),
    dueDate: _dateAfterLabel(text, 'DUE DATE'),
  );
}

int? _valueAfterLabel(String text, String label) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final index = normalized.toUpperCase().indexOf(label);
  if (index < 0) return null;
  final window = normalized.substring(index + label.length,
      (index + label.length + 180).clamp(0, normalized.length));
  final match = RegExp(r'\b\d[\d,]*\b').firstMatch(window);
  return match == null
      ? null
      : int.tryParse(match.group(0)!.replaceAll(',', ''));
}

String? _textAfterLabel(String text, String label) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final index = normalized.toUpperCase().indexOf(label);
  if (index < 0) return null;
  final window = normalized.substring(index + label.length,
      (index + label.length + 100).clamp(0, normalized.length));
  final match = RegExp(r'\S+').firstMatch(window.trim());
  return match?.group(0);
}

String? _dateAfterLabel(String text, String label) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final index = normalized.toUpperCase().indexOf(label);
  if (index < 0) return null;
  final window =
      normalized.substring(index, (index + 180).clamp(0, normalized.length));
  final match =
      RegExp(r'\b(\d{1,2})[ ./-]+([A-Za-z]{3,9}|\d{1,2})[ ./-]+(\d{2,4})\b')
          .firstMatch(window);
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = _monthNumber(match.group(2)!);
  final rawYear = int.tryParse(match.group(3)!);
  if (day == null || month == null || rawYear == null) return null;
  final year = rawYear < 100 ? 2000 + rawYear : rawYear;
  return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

String? _monthAfterLabel(String text, String label) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final index = normalized.toUpperCase().indexOf(label);
  if (index < 0) return null;
  final window =
      normalized.substring(index, (index + 120).clamp(0, normalized.length));
  final match =
      RegExp(r'\b([A-Za-z]{3,9})[ ./-]+(\d{2,4})\b').firstMatch(window);
  if (match == null) return null;
  final month = _monthNumber(match.group(1)!);
  final rawYear = int.tryParse(match.group(2)!);
  if (month == null || rawYear == null) return null;
  final year = rawYear < 100 ? 2000 + rawYear : rawYear;
  return '$year-${month.toString().padLeft(2, '0')}';
}

int? _monthNumber(String value) {
  final number = int.tryParse(value);
  if (number != null && number >= 1 && number <= 12) return number;
  const names = <String, int>{
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };
  return names[value.substring(0, 3).toUpperCase()];
}
