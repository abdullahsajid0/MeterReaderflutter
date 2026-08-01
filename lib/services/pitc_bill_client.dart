import 'package:http/http.dart' as http;
import '../models/wattwise_types.dart';
import 'pitc_bill_parser.dart';

const String pitcBaseUrl = 'https://bill.pitc.com.pk';

const Map<String, String> pitcProviderSlugs = {
  'LESCO': 'lescobill',
  'IESCO': 'iescobill',
  'GEPCO': 'gepcobill',
  'FESCO': 'fescobill',
  'MEPCO': 'mepcobill',
  'PESCO': 'pescobill',
  'HESCO': 'hescobill',
  'SEPCO': 'sepcobill',
  'QESCO': 'qescobill',
  'TESCO': 'tescobill',
};

Future<BillInfo> fetchPitcBill(
  String referenceNumber,
  String company, {
  String meterId = 'temp',
}) async {
  final cleanReference = referenceNumber.replaceAll(RegExp(r'\D'), '');
  final slug = pitcProviderSlugs[company.toUpperCase()];
  if (!RegExp(r'^\d{10,14}$').hasMatch(cleanReference)) {
    throw Exception(
        'Enter the 10 to 14 digit reference number printed on the bill');
  }
  if (slug == null) {
    throw Exception('This electricity provider is not supported yet');
  }

  final uri = Uri.parse('$pitcBaseUrl/$slug');
  final headers = {
    'User-Agent':
        'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/120 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };
  final client = http.Client();
  try {
    final initial = await client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));
    if (initial.statusCode < 200 || initial.statusCode >= 300) {
      throw Exception('$company bill page returned ${initial.statusCode}');
    }
    final form = _hiddenFields(initial.body);
    form['rbSearchByList'] = 'refno';
    form['searchTextBox'] = cleanReference;
    form['ruCodeTextBox'] = '';
    form['btnSearch'] = 'Search';
    final response = await client
        .post(
          uri,
          headers: {
            ...headers,
            'Referer': uri.toString(),
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: form,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$company bill lookup returned ${response.statusCode}');
    }
    final parsed = parsePitcBillHtml(response.body);
    if (parsed == null ||
        parsed.previousReading == null ||
        parsed.currentReading == null ||
        parsed.readingDate == null) {
      throw Exception(
          'The official page opened, but did not contain real meter readings');
    }
    final current = parsed.currentReading!;
    final previous = parsed.previousReading!;
    final readingDate = parsed.readingDate!;
    return BillInfo(
      meterId: meterId,
      fetchedAt: DateTime.now().toUtc().toIso8601String(),
      referenceNumber: parsed.referenceNumber ?? cleanReference,
      consumerId: parsed.consumerId,
      company: company,
      billingMonth: parsed.billingMonth ?? readingDate.substring(0, 7),
      previousReading: previous,
      currentReading: current,
      readingDate: readingDate,
      nextReadingDate: _addMonth(readingDate),
      unitsBilled:
          parsed.unitsBilled ?? (current - previous).clamp(0, 999999).toInt(),
      amountPkr: parsed.amountPkr,
      dueDate: parsed.dueDate,
      status: 'available',
    );
  } finally {
    client.close();
  }
}

Map<String, String> _hiddenFields(String source) {
  final fields = <String, String>{};
  for (final match
      in RegExp(r'<input\b([^>]*)>', caseSensitive: false).allMatches(source)) {
    final attributes = match.group(1)!;
    final name = _attribute(attributes, 'name');
    if (name != null) fields[name] = _attribute(attributes, 'value') ?? '';
  }
  return fields;
}

String? _attribute(String attributes, String name) {
  final match = RegExp('$name\\s*=\\s*["\\\']([^"\\\']*)', caseSensitive: false)
      .firstMatch(attributes);
  return match?.group(1);
}

String _addMonth(String iso) {
  final date = DateTime.parse(iso);
  final next = DateTime(date.year, date.month + 1, date.day);
  return '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
}
