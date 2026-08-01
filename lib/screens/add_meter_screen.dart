import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../store/wattwise_store.dart';

class AddMeterScreen extends StatefulWidget {
  const AddMeterScreen({super.key});

  @override
  State<AddMeterScreen> createState() => _AddMeterScreenState();
}

class _AddMeterScreenState extends State<AddMeterScreen> {
  final _formKey = GlobalKey<FormState>();
  String nickname = '';
  String company = 'LESCO';
  String referenceNumber = '';
  int readingDay = 10;
  int? limit;

  final companies = [
    'LESCO',
    'IESCO',
    'GEPCO',
    'FESCO',
    'MEPCO',
    'PESCO',
    'HESCO',
    'SEPCO',
    'QESCO',
    'TESCO'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Meter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Nickname (e.g. Home)'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => nickname = v!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Company'),
                initialValue: company,
                items: companies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => company = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Reference Number (14 digits)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.replaceAll(RegExp(r'\D'), '').length < 10)
                    return 'Too short';
                  return null;
                },
                onSaved: (v) => referenceNumber = v!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Reading Day (1-28)'),
                keyboardType: TextInputType.number,
                initialValue: '10',
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1 || n > 28)
                    return 'Must be between 1 and 28';
                  return null;
                },
                onSaved: (v) => readingDay = int.parse(v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Monthly Limit (Optional)'),
                keyboardType: TextInputType.number,
                onSaved: (v) => limit = int.tryParse(v ?? ''),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    context.read<WattWiseStore>().addMeter(
                          nickname: nickname,
                          company: company,
                          referenceNumber: referenceNumber,
                          readingDay: readingDay,
                          monthlyLimit: limit,
                        );
                    context.pop();
                  }
                },
                child: const Text('Save Meter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
