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
  
  // 1. Add original uncropped image (crucial if crop region misaligns with camera resolution)
  variants.add(bytes);

  final source = img.decodeImage(bytes);
  if (source == null || source.width < 20 || source.height < 20) {
    return variants;
  }

  final x = (source.width * region.left).round().clamp(0, source.width - 1);
  final y = (source.height * region.top).round().clamp(0, source.height - 1);
  final width =
      (source.width * region.width).round().clamp(1, source.width - x);
  final height =
      (source.height * region.height).round().clamp(1, source.height - y);
  
  final cropped =
      img.copyCrop(source, x: x, y: y, width: width, height: height);
  
  // 2. Clean cropped original
  variants.add(Uint8List.fromList(img.encodeJpg(cropped, quality: 96)));

  // 3. Enlarged cropped
  final enlarged = img.copyResize(cropped, width: cropped.width * 2);
  variants.add(Uint8List.fromList(img.encodeJpg(enlarged, quality: 96)));

  // 4. High contrast grayscale
  final grayscale = img.grayscale(enlarged);
  final highContrast =
      img.adjustColor(grayscale, contrast: 1.5, brightness: 1.05);
  variants.add(Uint8List.fromList(img.encodeJpg(highContrast, quality: 96)));

  return variants;
}
