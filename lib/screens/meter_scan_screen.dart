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
    final Map<int, double> candidateScores = {};

    void addCandidate(int candidate, double score) {
      if (candidate <= 0 || candidate > 999999999) return;
      // Exclude common voltage/frequency noise values
      if (candidate == 50 || candidate == 60 || candidate == 220 || candidate == 230 || candidate == 240 || candidate == 110) {
        return;
      }
      candidateScores[candidate] = (candidateScores[candidate] ?? 0.0) + score;
    }

    void processString(String raw, bool isKwhLine) {
      if (raw.trim().isEmpty) return;

      final upper = raw.toUpperCase();
      // Ignore serial numbers / 10+ digit lines
      if (RegExp(r'\d{10,}').hasMatch(raw)) return;

      // 7-segment LCD / Rolling digit repair map
      final cleaned = raw
          .replaceAll(RegExp(r'[O|o|D|Q]'), '0')
          .replaceAll(RegExp(r'[I|i|l|L|\||\!]'), '1')
          .replaceAll(RegExp(r'[Z|z]'), '2')
          .replaceAll(RegExp(r'[E]'), '3')
          .replaceAll(RegExp(r'[A|H]'), '4')
          .replaceAll(RegExp(r'[S|s|\$]'), '5')
          .replaceAll(RegExp(r'[G|b]'), '6')
          .replaceAll(RegExp(r'[T]'), '7')
          .replaceAll(RegExp(r'[B|R]'), '8')
          .replaceAll(RegExp(r'[g|q]'), '9');

      final lineHasKwh = isKwhLine || upper.contains('KWH') | upper.contains('KW') || upper.contains('UNIT');
      final baseScore = lineHasKwh ? 150.0 : 30.0;

      // Decimal pattern (e.g. 04223.4 kWh)
      if (_displayType == MeterDisplayType.digital) {
        final decimalMatch = RegExp(r'(\d{3,9})\s*[.,·]\s*\d').firstMatch(cleaned.replaceAll(' ', ''));
        if (decimalMatch != null) {
          final integer = int.tryParse(decimalMatch.group(1)!);
          if (integer != null) addCandidate(integer, baseScore + 60.0);
        }
      }

      // Continuous digits matching
      final noSpaces = cleaned.replaceAll(RegExp(r'\s+'), '');
      for (final match in RegExp(r'\d{3,9}').allMatches(noSpaces)) {
        final parsed = int.tryParse(match.group(0)!);
        if (parsed != null) {
          final lenBonus = (parsed >= 1000 && parsed <= 999999) ? 40.0 : 10.0;
          addCandidate(parsed, baseScore + lenBonus);
        }
      }

      // Pure digits extraction
      final pureDigits = cleaned.replaceAll(RegExp(r'[^\d]'), '');
      if (pureDigits.length >= 3 && pureDigits.length <= 9) {
        final parsed = int.tryParse(pureDigits);
        if (parsed != null) {
          addCandidate(parsed, baseScore + 20.0);
        }
      }
    }

    for (final block in text.blocks) {
      final blockHasKwh = block.text.toUpperCase().contains('KWH') || block.text.toUpperCase().contains('KW');
      processString(block.text, blockHasKwh);
      for (final line in block.lines) {
        final lineHasKwh = blockHasKwh || line.text.toUpperCase().contains('KWH') || line.text.toUpperCase().contains('KW');
        processString(line.text, lineHasKwh);
      }
    }

    if (candidateScores.isEmpty) return null;

    // Apply baseline proximity bonus
    candidateScores.forEach((candidate, currentScore) {
      if (baseline != null) {
        final delta = candidate - baseline;
        if (delta >= 0 && delta <= 10000) {
          candidateScores[candidate] = currentScore + 120.0 - (delta / 100.0);
        } else if (delta > 10000 && delta <= 50000) {
          candidateScores[candidate] = currentScore + 40.0;
        } else if (delta < 0) {
          // Penalty for being smaller than previous official reading
          candidateScores[candidate] = currentScore - 80.0;
        }
      }
    });

    final sortedCandidates = candidateScores.keys.toList()
      ..sort((a, b) => candidateScores[b]!.compareTo(candidateScores[a]!));

    return sortedCandidates.first;
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
        final deltaA = (a - baseline);
        final deltaB = (b - baseline);
        // Prefer positive deltas over negative deltas relative to baseline
        final scoreA = (deltaA >= 0 && deltaA <= 50000) ? 100000 - deltaA : -100000 - deltaA.abs();
        final scoreB = (deltaB >= 0 && deltaB <= 50000) ? 100000 - deltaB : -100000 - deltaB.abs();
        return scoreB.compareTo(scoreA);
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
          const SizedBox(height: 16),
          _buildActions(cameraReady),
          const SizedBox(height: 16),
          const Text(
              'Place only the number window inside the guide. OCR ignores decimal digits on digital meters.',
              textAlign: TextAlign.center,
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
                onPressed: _captureAndRead,
                color: AppTheme.primary)),
        const SizedBox(width: 12),
        Expanded(
            child: _ActionButton(
                icon: LucideIcons.image,
                label: 'Upload',
                enabled: !_isProcessing,
                onPressed: _pickImage,
                color: AppTheme.accent)),
        const SizedBox(width: 12),
        Expanded(
            child: _ActionButton(
                icon: LucideIcons.pencil,
                label: 'Type',
                enabled: !_isProcessing,
                onPressed: _showManualEntry,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.enabled,
      required this.onPressed,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color.withOpacity(0.08) : AppTheme.border.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? color.withOpacity(0.3) : AppTheme.border,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: enabled ? color : AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled ? color : AppTheme.textSecondary.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
