import 'package:camera/camera.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/wattwise_billing.dart';
import '../services/meter_image_cropper.dart';
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
    if (controller == null ||
        !controller.value.isInitialized ||
        _isProcessing) {
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

  Future<void> _readImage(XFile image) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    final temporaryFiles = <File>[];
    try {
      final bytes = await image.readAsBytes();
      final region = _displayType == MeterDisplayType.digital
          ? digitalMeterRegion
          : rollingMeterRegion;
      final croppedVariants = cropMeterImageVariants(bytes, region);
      if (croppedVariants.isEmpty) {
        _showError(
            'This image could not be cropped. Please try another photo.');
        return;
      }
      final store = context.read<WattWiseStore>();
      final meter = store.meters.firstWhere((m) => m.id == widget.meterId);
      final baseline = store.billFor(meter.id)?.currentReading ??
          store.latestReading(meter.id)?.currentReading;
      final readings = <int>[];
      for (var index = 0; index < croppedVariants.length; index++) {
        final croppedFile = File(
            '${Directory.systemTemp.path}/wattwise_meter_${DateTime.now().microsecondsSinceEpoch}_$index.jpg');
        temporaryFiles.add(croppedFile);
        await croppedFile.writeAsBytes(croppedVariants[index], flush: true);
        final recognized = await _textRecognizer.processImage(
          InputImage.fromFilePath(croppedFile.path),
        );
        final candidate = _extractReading(recognized, baseline);
        if (candidate != null) readings.add(candidate);
      }
      final reading = _chooseReading(readings, baseline);
      if (!mounted) return;
      if (reading == null) {
        _showError(
            'OCR could not find a safe meter reading. You can enter it manually.');
        await _showManualEntry();
      } else {
        await _showConfirmationDialog(reading);
      }
    } catch (error) {
      _showError('OCR could not process this image: $error');
    } finally {
      for (final croppedFile in temporaryFiles) {
        try {
          await croppedFile.delete();
        } catch (_) {
          // Temporary OCR files are best-effort cleanup.
        }
      }
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showManualEntry() async {
    String inputValue = '';
    final reading = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter meter reading'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 9,
          onChanged: (val) => inputValue = val,
          decoration: const InputDecoration(
            labelText: 'Whole units only',
            hintText: 'e.g. 42234',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(inputValue.trim());
              if (value == null || value < 0 || value > 999999999) return;
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: const Text('Use reading'),
          ),
        ],
      ),
    );

    if (reading != null && mounted) {
      await _showConfirmationDialog(reading);
    }
  }

  Future<void> _showConfirmationDialog(int reading) async {
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
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Review reading'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Check the OCR result and correct it if needed.',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: current.toString(),
                keyboardType: TextInputType.number,
                maxLength: 9,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed <= 999999999) {
                    setDialogState(() => current = parsed);
                  }
                },
                decoration: const InputDecoration(
                    labelText: 'Current whole-unit reading', counterText: ''),
              ),
              const SizedBox(height: 12),
              Text('Official bill present reading: $previous',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              if (current >= previous) ...[
                const SizedBox(height: 4),
                Text('${current - previous} units used since the bill',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                },
                child: const Text('Cancel')),
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
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    },
              child: const Text('Save scan'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      context.pop();
    }
  }

  int? _extractReading(RecognizedText text, int? baseline) {
    final candidates = <int>{};
    
    String fullText = '';
    for (final block in text.blocks) {
      for (final line in block.lines) {
        fullText += '${line.text} ';
      }
    }
    
    final value = fullText
        .replaceAll('O', '0').replaceAll('o', '0')
        .replaceAll('I', '1').replaceAll('i', '1').replaceAll('l', '1')
        .replaceAll('Z', '2').replaceAll('z', '2')
        .replaceAll('S', '5').replaceAll('s', '5')
        .replaceAll('B', '8')
        .replaceAll('G', '6')
        .replaceAll(' ', '');

    final decimal = RegExp(r'(\d{3,9})\s*[.,·]\s*\d').firstMatch(value);
    if (_displayType == MeterDisplayType.digital && decimal != null) {
      final integer = int.tryParse(decimal.group(1)!);
      if (integer != null) candidates.add(integer);
    }
    
    for (final match in RegExp(r'\d{3,9}').allMatches(value)) {
      final parsed = int.tryParse(match.group(0)!);
      if (parsed != null && parsed <= 999999999) candidates.add(parsed);
    }
    final safe = candidates.where((candidate) {
      if (baseline == null) return true;
      final delta = candidate - baseline;
      return delta >= 0 && delta <= 10000;
    }).toList();
    if (safe.isEmpty) return null;
    safe.sort((a, b) {
      if (baseline == null)
        return b.toString().length.compareTo(a.toString().length);
      return (a - baseline).compareTo(b - baseline);
    });
    return safe.first;
  }

  int? _chooseReading(List<int> readings, int? baseline) {
    if (readings.isEmpty) return null;
    final counts = <int, int>{};
    for (final reading in readings) {
      counts[reading] = (counts[reading] ?? 0) + 1;
    }
    final ranked = counts.keys.toList()
      ..sort((a, b) {
        final countOrder = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        if (countOrder != 0) return countOrder;
        if (baseline == null) return b.compareTo(a);
        return (a - baseline).compareTo(b - baseline);
      });
    return ranked.first;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
          const Text(
              'Place only the number window inside the guide. OCR ignores decimal digits on digital meters.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<MeterDisplayType>(
      segments: const [
        ButtonSegment(
            value: MeterDisplayType.digital,
            label: Text('Digital'),
            icon: Icon(LucideIcons.scanLine)),
        ButtonSegment(
            value: MeterDisplayType.rolling,
            label: Text('Rolling'),
            icon: Icon(LucideIcons.gauge)),
      ],
      selected: {_displayType},
      onSelectionChanged: (value) => setState(() => _displayType = value.first),
    );
  }

  Widget _buildPreview(bool cameraReady) {
    final region = _displayType == MeterDisplayType.digital
        ? digitalMeterRegion
        : rollingMeterRegion;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              if (cameraReady)
                CameraPreview(_cameraController!)
              else
                Container(
                    color: AppTheme.primary,
                    child: Center(
                        child: Text(_cameraError ?? 'Starting camera...',
                            style: const TextStyle(color: Colors.white)))),
              IgnorePointer(child: CustomPaint(painter: _GuidePainter(region))),
              Align(
                alignment: Alignment(
                  (region.left + region.width / 2) * 2 - 1,
                  (region.top + region.height / 2) * 2 - 1,
                ),
                child: FractionallySizedBox(
                  widthFactor: region.width,
                  heightFactor: region.height,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.accent, width: 3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _displayType == MeterDisplayType.digital
                          ? 'Digital number window'
                          : 'Rolling number wheels',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              if (_isProcessing)
                const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(bool cameraReady) {
    return Row(
      children: [
        Expanded(
            child: _ActionButton(
                icon: LucideIcons.camera,
                label: 'Capture',
                enabled: cameraReady && !_isProcessing,
                onPressed: _captureAndRead)),
        const SizedBox(width: 8),
        Expanded(
            child: _ActionButton(
                icon: LucideIcons.image,
                label: 'Upload',
                enabled: !_isProcessing,
                onPressed: _pickImage)),
        const SizedBox(width: 8),
        Expanded(
            child: _ActionButton(
                icon: LucideIcons.pencil,
                label: 'Type',
                enabled: !_isProcessing,
                onPressed: _showManualEntry)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.enabled,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 17),
        label: Flexible(
          child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.visible),
        ));
  }
}

class _GuidePainter extends CustomPainter {
  final MeterCropRegion region;

  _GuidePainter(this.region);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.42);
    final guide = Rect.fromLTWH(
        size.width * region.left,
        size.height * region.top,
        size.width * region.width,
        size.height * region.height);
    canvas.drawPath(
        Path.combine(
            PathOperation.difference,
            Path()..addRect(Offset.zero & size),
            Path()
              ..addRRect(
                  RRect.fromRectAndRadius(guide, const Radius.circular(14)))),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _cameraMessage(CameraException error) {
  if (error.code == 'CameraAccessDenied')
    return 'Camera permission was denied. Upload a photo or type the reading.';
  return 'Camera is unavailable. Upload a photo or type the reading.';
}
