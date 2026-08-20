import 'dart:typed_data';
import 'package:image/image.dart' as img;

class MeterCropRegion {
  final double left;
  final double top;
  final double width;
  final double height;

  const MeterCropRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

const digitalMeterRegion = MeterCropRegion(
  left: 0.08,
  top: 0.39,
  width: 0.84,
  height: 0.29,
);

const rollingMeterRegion = MeterCropRegion(
  left: 0.05,
  top: 0.34,
  width: 0.90,
  height: 0.32,
);

Uint8List? cropMeterImage(Uint8List bytes, MeterCropRegion region) {
  final variants = cropMeterImageVariants(bytes, region);
  return variants.isEmpty ? null : variants.first;
}

List<Uint8List> cropMeterImageVariants(
    Uint8List bytes, MeterCropRegion region) {
  final variants = <Uint8List>[];

  // 1. Full uncropped image
  variants.add(bytes);

  final source = img.decodeImage(bytes);
  if (source == null || source.width < 20 || source.height < 20) {
    return variants;
  }

  // Helper to crop & process
  void addCroppedVariant(img.Image image, String label) {
    variants.add(Uint8List.fromList(img.encodeJpg(image, quality: 95)));

    // Resize 2x for OCR detail
    final resized = img.copyResize(image, width: image.width * 2);
    variants.add(Uint8List.fromList(img.encodeJpg(resized, quality: 95)));

    // Grayscale + High Contrast
    final gray = img.grayscale(resized);
    final highContrast = img.adjustColor(gray, contrast: 1.6, brightness: 1.05);
    variants.add(Uint8List.fromList(img.encodeJpg(highContrast, quality: 95)));

    // Inverted colors (White text on dark background - ideal for mechanical rolling wheels & LCDs)
    final inverted = img.invert(highContrast);
    variants.add(Uint8List.fromList(img.encodeJpg(inverted, quality: 95)));
  }

  // Variant A: Standard specified region crop
  final xA = (source.width * region.left).round().clamp(0, source.width - 1);
  final yA = (source.height * region.top).round().clamp(0, source.height - 1);
  final wA = (source.width * region.width).round().clamp(1, source.width - xA);
  final hA =
      (source.height * region.height).round().clamp(1, source.height - yA);
  final cropA = img.copyCrop(source, x: xA, y: yA, width: wA, height: hA);
  addCroppedVariant(cropA, 'GuideCrop');

  // Variant B: Generous Center Crop (Middle 80% W x 40% H)
  final xB = (source.width * 0.10).round().clamp(0, source.width - 1);
  final yB = (source.height * 0.30).round().clamp(0, source.height - 1);
  final wB = (source.width * 0.80).round().clamp(1, source.width - xB);
  final hB = (source.height * 0.40).round().clamp(1, source.height - yB);
  final cropB = img.copyCrop(source, x: xB, y: yB, width: wB, height: hB);
  addCroppedVariant(cropB, 'CenterCrop');

  // Variant C: Upper Center Crop (Middle 80% W x 35% H at top 15%)
  final xC = (source.width * 0.10).round().clamp(0, source.width - 1);
  final yC = (source.height * 0.15).round().clamp(0, source.height - 1);
  final wC = (source.width * 0.80).round().clamp(1, source.width - xC);
  final hC = (source.height * 0.35).round().clamp(1, source.height - yC);
  final cropC = img.copyCrop(source, x: xC, y: yC, width: wC, height: hC);
  addCroppedVariant(cropC, 'UpperCrop');

  return variants;
}
