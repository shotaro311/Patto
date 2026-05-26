import 'dart:io';
import 'package:image/image.dart' as img;

class Bounds {
  Bounds(this.minX, this.minY, this.maxX, this.maxY);

  int minX;
  int minY;
  int maxX;
  int maxY;

  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;
}

({double r, double g, double b}) _averageCornerColor(img.Image image) {
  const sampleSize = 96;
  final patches = <(int, int)>[
    (0, 0),
    (image.width - sampleSize, 0),
    (0, image.height - sampleSize),
    (image.width - sampleSize, image.height - sampleSize),
  ];

  double totalR = 0;
  double totalG = 0;
  double totalB = 0;
  int count = 0;

  for (final (startX, startY) in patches) {
    final x0 = startX.clamp(0, image.width - 1);
    final y0 = startY.clamp(0, image.height - 1);
    for (var y = y0; y < (y0 + sampleSize).clamp(0, image.height); y++) {
      for (var x = x0; x < (x0 + sampleSize).clamp(0, image.width); x++) {
        final pixel = image.getPixel(x, y);
        totalR += pixel.r;
        totalG += pixel.g;
        totalB += pixel.b;
        count++;
      }
    }
  }

  return (
    r: totalR / count,
    g: totalG / count,
    b: totalB / count,
  );
}

Bounds _detectSubjectBounds(
  img.Image image, {
  required double bgR,
  required double bgG,
  required double bgB,
}) {
  Bounds? bounds;
  const threshold = 26.0;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final distance = (pixel.r - bgR).abs() +
          (pixel.g - bgG).abs() +
          (pixel.b - bgB).abs();
      if (distance < threshold) {
        continue;
      }

      bounds ??= Bounds(x, y, x, y);
      if (x < bounds.minX) bounds.minX = x;
      if (y < bounds.minY) bounds.minY = y;
      if (x > bounds.maxX) bounds.maxX = x;
      if (y > bounds.maxY) bounds.maxY = y;
    }
  }

  if (bounds == null) {
    throw StateError('Could not detect subject bounds.');
  }

  return bounds;
}

img.Image enlargeIcon(
  img.Image source, {
  double paddingRatio = 0.08,
  double zoomFactor = 1.0,
}) {
  final bg = _averageCornerColor(source);
  final subject = _detectSubjectBounds(
    source,
    bgR: bg.r,
    bgG: bg.g,
    bgB: bg.b,
  );

  final padding =
      (subject.width > subject.height ? subject.width : subject.height) * paddingRatio;
  var cropSize =
      (subject.width > subject.height ? subject.width : subject.height) + padding * 2;
  cropSize = cropSize / zoomFactor;

  final centerX = (subject.minX + subject.maxX) / 2;
  final centerY = (subject.minY + subject.maxY) / 2;

  var left = (centerX - cropSize / 2).round();
  var top = (centerY - cropSize / 2).round();
  var size = cropSize.round();

  if (left < 0) left = 0;
  if (top < 0) top = 0;
  if (left + size > source.width) left = source.width - size;
  if (top + size > source.height) top = source.height - size;

  if (left < 0) {
    left = 0;
    size = source.width;
  }
  if (top < 0) {
    top = 0;
    size = source.height < size ? source.height : size;
  }
  if (left + size > source.width) size = source.width - left;
  if (top + size > source.height) size = source.height - top;

  final cropped = img.copyCrop(source, x: left, y: top, width: size, height: size);
  return img.copyResize(cropped, width: 1024, height: 1024, interpolation: img.Interpolation.cubic);
}

void main(List<String> args) {
  if (args.length < 2 || args.length > 4) {
    stderr.writeln(
      'Usage: dart run tmp/icon_samples/enlarge_app_icon.dart <input> <output> [paddingRatio] [zoomFactor]',
    );
    exit(64);
  }

  final inputFile = File(args[0]);
  final outputFile = File(args[1]);
  final paddingRatio = args.length == 3 ? double.parse(args[2]) : 0.08;
  final zoomFactor = args.length >= 4 ? double.parse(args[3]) : 1.0;
  final decoded = img.decodeImage(inputFile.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Failed to decode image: ${inputFile.path}');
    exit(1);
  }

  final enlarged = enlargeIcon(
    decoded,
    paddingRatio: paddingRatio,
    zoomFactor: zoomFactor,
  );
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsBytesSync(img.encodePng(enlarged));
  stdout.writeln(outputFile.path);
}
