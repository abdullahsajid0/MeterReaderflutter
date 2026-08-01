import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/wattwise_types.dart';
import '../services/wattwise_billing.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';

enum MeterDisplayType { digital, rolling }

class MeterScanScreen extends StatefulWidget {
  final String meterId;

  const MeterScanScreen({super.key, required this.meterId});

  @override
  State<MeterScanScreen> createState() => _MeterScanScreenState();
}

class _MeterScanScreenState extends State<MeterScanScreen> {
  CameraController? _cameraController;
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  MeterDisplayType _displayType = MeterDisplayType.digital;
  bool _isProcessing = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera is available on this device.');
        return;
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _cameraController = controller;
      setState(() {});
    } on CameraException catch (error) {
      if (mounted) setState(() => _cameraError = _cameraMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError = 'Camera could not be started.');
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _captureAndRead() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isProcessing) {
      return;
    }
    try {
      setState(() => _isProcessing = true);
      final image = await controller.takePicture();
      await _readImage(image);
    } catch (error) {
      _showError('Could not capture this image: $error');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickImage() async {
    if (_isProcessing) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2200,
      maxHeight: 2200,
      imageQuality: 95,
    );
    if (image == null) return;
    await _readImage(image);
  }

  Future<void> _takePhotoFromPicker() async {
    if (_isProcessing) return;
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2200,
      maxHeight: 2200,
      imageQuality: 95,
    );
    if (image == null) return;
    await _readImage(image);
  }

  Future<void> _readImage(XFile image) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      final recognized = await _textRecognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      final store = context.read<WattWiseStore>();
      final meter = store.meters.firstWhere((m) => m.id == widget.meterId);
      final baseline = store.billFor(meter.id)?.currentReading ??
          store.latestReading(meter.id)?.currentReading;
      final reading = _extractReading(recognized, baseline);
      if (!mounted) return;
      if (reading == null) {
        _showError('OCR could not find a safe meter reading. You can enter it manually.');
        await _showManualEntry();
      } else {
        _showConfirmationDialog(reading);
      }
    } catch (error) {
      _showError('OCR could not process this image: $error');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showManualEntry() async {
    final controller = TextEditingController();
    final reading = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter meter reading'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 9,
          decoration: const InputDecoration(
            labelText: 'Whole units only',
            hintText: 'e.g. 42234',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0 || value > 999999999) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Use reading'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reading != null && mounted) _showConfirmationDialog(reading);
  }

  void _showConfirmationDialog(int reading) {
    final store = context.read<WattWiseStore>();
    final meter = store.meters.firstWhere((m) => m.id == widget.meterId);
    final bill = store.billFor(meter.id);
    final latest = store.latestReading(meter.id);
    final previous = bill?.currentReading ?? latest?.currentReading;
    if (previous == null) {
      _showError('Fetch the official bill before scanning this meter.');
      return;
    }
    var current = reading;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Review reading'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Check the OCR result and correct it if needed.', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: current.toString(),
                keyboardType: TextInputType.number,
                maxLength: 9,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed <= 999999999) setDialogState(() => current = parsed);
                },
                decoration: const InputDecoration(labelText: 'Current whole-unit reading', counterText: ''),
              ),
              const SizedBox(height: 12),
              Text('Official bill present reading: $previous', style: const TextStyle(color: AppTheme.textSecondary)),
              if (current >= previous) ...[
                const SizedBox(height: 4),
                Text('${current - previous} units used since the bill', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: current < previous
                  ? null
                  : () {
                      final cycle = cycleFor(meter);
                      store.addReading(
                        meterId: meter.id,
                        currentReading: current,
                        previousReading: previous,
                        cycleStart: cycle.startISO,
                        cycleEnd: cycle.endISO,
                        unitsConsumed: current - previous,
                        billingMonth: cycle.billingMonth,
                      );
                      Navigator.pop(dialogContext);
                      context.pop();
                    },
              child: const Text('Save scan'),
            ),
          ],
        ),
      ),
    );
  }

  int? _extractReading(RecognizedText text, int? baseline) {
    final candidates = <int>{};
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final value = line.text.replaceAll('O', '0').replaceAll('I', '1');
        final decimal = RegExp(r'(\d{3,9})\s*[.,·]\s*\d').firstMatch(value);
        if (_displayType == MeterDisplayType.digital && decimal != null) {
          final integer = int.tryParse(decimal.group(1)!);
          if (integer != null) candidates.add(integer);
        }
        for (final match in RegExp(r'\d{3,9}').allMatches(value)) {
          final parsed = int.tryParse(match.group(0)!);
          if (parsed != null && parsed <= 999999999) candidates.add(parsed);
        }
      }
    }
    final safe = candidates.where((candidate) {
      if (baseline == null) return true;
      final delta = candidate - baseline;
      return delta >= 0 && delta <= 10000;
    }).toList();
    if (safe.isEmpty) return null;
    safe.sort((a, b) {
      if (baseline == null) return b.toString().length.compareTo(a.toString().length);
      return (a - baseline).compareTo(b - baseline);
    });
    return safe.first;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cameraReady = _cameraController?.value.isInitialized == true;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Read meter')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildModeSelector(),
          const SizedBox(height: 12),
          _buildPreview(cameraReady),
          const SizedBox(height: 12),
          _buildActions(cameraReady),
          const SizedBox(height: 12),
          const Text('Place only the number window inside the guide. OCR ignores decimal digits on digital meters.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<MeterDisplayType>(
      segments: const [
        ButtonSegment(value: MeterDisplayType.digital, label: Text('Digital'), icon: Icon(LucideIcons.scanText)),
        ButtonSegment(value: MeterDisplayType.rolling, label: Text('Rolling'), icon: Icon(LucideIcons.gauge)),
      ],
      selected: {_displayType},
      onSelectionChanged: (value) => setState(() => _displayType = value.first),
    );
  }

  Widget _buildPreview(bool cameraReady) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraReady) CameraPreview(_cameraController!) else Container(color: AppTheme.primary, child: Center(child: Text(_cameraError ?? 'Starting camera...', style: const TextStyle(color: Colors.white)))),
            IgnorePointer(child: CustomPaint(painter: _GuidePainter())),
            Center(child: Container(width: double.infinity, height: 124, margin: const EdgeInsets.symmetric(horizontal: 28), decoration: BoxDecoration(border: Border.all(color: AppTheme.accent, width: 3), borderRadius: BorderRadius.circular(14)), child: Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(8), child: Text(_displayType == MeterDisplayType.digital ? 'Digital number window' : 'Rolling number wheels', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))))),
            if (_isProcessing) const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(bool cameraReady) {
    return Row(
      children: [
        Expanded(child: _ActionButton(icon: LucideIcons.camera, label: 'Capture', enabled: cameraReady && !_isProcessing, onPressed: _captureAndRead)),
        const SizedBox(width: 8),
        Expanded(child: _ActionButton(icon: LucideIcons.image, label: 'Upload', enabled: !_isProcessing, onPressed: _pickImage)),
        const SizedBox(width: 8),
        Expanded(child: _ActionButton(icon: LucideIcons.pencilLine, label: 'Type', enabled: !_isProcessing, onPressed: _showManualEntry)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({required this.icon, required this.label, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(onPressed: enabled ? onPressed : null, icon: Icon(icon, size: 17), label: Text(label));
  }
}

class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.42);
    final guide = Rect.fromLTWH(28, (size.height - 124) / 2, size.width - 56, 124);
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(RRect.fromRectAndRadius(guide, const Radius.circular(14)))), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _cameraMessage(CameraException error) {
  if (error.code == 'CameraAccessDenied') return 'Camera permission was denied. Upload a photo or type the reading.';
  return 'Camera is unavailable. Upload a photo or type the reading.';
}
