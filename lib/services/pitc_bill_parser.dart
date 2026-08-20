import 'package:html/dom.dart' as html_dom;
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
  final html_dom.Document document = html_parser.parse(source);
  final text = document.body?.text ?? '';

  final previous = _valueAfterLabels(text, [
    'PREVIOUS READING',
    'PREV READING',
    'PREVIOUS',
    'PREV READ',
    'PREV. READING',
    'PREV'
  ]);

  final current = _valueAfterLabels(text, [
    'PRESENT READING',
    'PRES READING',
    'CURRENT READING',
    'PRES READ',
    'PRES. READING',
    'PRESENT',
    'PRES'
  ]);

  final units = _valueAfterLabels(
      text, ['UNITS BILLED', 'UNITS CONSUMED', 'TOTAL UNITS', 'UNITS']);

  // If text parsing fails, try table cell searching
  final cellValues = _extractTableData(document);

  final finalPrevious = previous ?? cellValues['previous'];
  final finalCurrent = current ?? cellValues['current'];
  final finalUnits = units ?? cellValues['units'];

  if (finalPrevious == null && finalCurrent == null && finalUnits == null) {
    return null;
  }

  final readingDate = _dateAfterLabels(
          text, ['READING DATE', 'READ DATE', 'DATE OF READING', 'MTR DATE']) ??
      cellValues['dateStr'];

  final now = DateTime.now();
  final defaultMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  final billMonth =
      _monthAfterLabels(text, ['BILL MONTH', 'BILLING MONTH', 'MONTH']) ??
          readingDate?.substring(0, 7) ??
          defaultMonth;

  return ParsedPitcBill(
    referenceNumber:
        _textAfterLabels(text, ['REFERENCE NO', 'REF NO', 'REFERENCE']),
    consumerId:
        _textAfterLabels(text, ['CONSUMER ID', 'CONS ID', 'ACCOUNT NO']),
    billingMonth: billMonth,
    previousReading: finalPrevious,
    currentReading: finalCurrent,
    readingDate:
        readingDate ?? DateTime.now().toIso8601String().substring(0, 10),
    unitsBilled: finalUnits,
    amountPkr: _valueAfterLabels(text, [
      'PAYABLE WITHIN DUE DATE',
      'AMOUNT PAYABLE',
      'PAYABLE',
      'NET AMOUNT',
      'TOTAL PAYABLE'
    ]),
    dueDate: _dateAfterLabels(text, ['DUE DATE', 'PAYABLE BY']),
  );
}

Map<String, dynamic> _extractTableData(html_dom.Document document) {
  final res = <String, dynamic>{};
  try {
    final elements = [
      ...document.getElementsByTagName('td'),
      ...document.getElementsByTagName('th')
    ];
    for (int i = 0; i < elements.length; i++) {
      final t = elements[i].text.trim().toUpperCase();
      if ((t.contains('PREV') || t.contains('PREVIOUS')) &&
          i + 1 < elements.length) {
        final valText = elements[i + 1].text.replaceAll(',', '').trim();
        final val =
            int.tryParse(RegExp(r'\d+').firstMatch(valText)?.group(0) ?? '');
        if (val != null && val > 0) res['previous'] = val;
      }
      if ((t.contains('PRES') ||
              t.contains('PRESENT') ||
              t.contains('CURRENT')) &&
          i + 1 < elements.length) {
        final valText = elements[i + 1].text.replaceAll(',', '').trim();
        final val =
            int.tryParse(RegExp(r'\d+').firstMatch(valText)?.group(0) ?? '');
        if (val != null && val > 0) res['current'] = val;
      }
      if (t.contains('UNITS') && i + 1 < elements.length) {
        final valText = elements[i + 1].text.replaceAll(',', '').trim();
        final val =
            int.tryParse(RegExp(r'\d+').firstMatch(valText)?.group(0) ?? '');
        if (val != null) res['units'] = val;
      }
    }
  } catch (_) {}
  return res;
}

int? _valueAfterLabels(String text, List<String> labels) {
  for (var l in labels) {
    final val = _valueAfterLabel(text, l);
    if (val != null) return val;
  }
  return null;
}

String? _textAfterLabels(String text, List<String> labels) {
  for (var l in labels) {
    final val = _textAfterLabel(text, l);
    if (val != null) return val;
  }
  return null;
}

String? _dateAfterLabels(String text, List<String> labels) {
  for (var l in labels) {
    final val = _dateAfterLabel(text, l);
    if (val != null) return val;
  }
  return null;
}

String? _monthAfterLabels(String text, List<String> labels) {
  for (var l in labels) {
    final val = _monthAfterLabel(text, l);
    if (val != null) return val;
  }
  return null;
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
  final key = value.length >= 3
      ? value.substring(0, 3).toUpperCase()
      : value.toUpperCase();
  return names[key];
}
