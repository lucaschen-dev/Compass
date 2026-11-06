import 'dart:typed_data';

import 'package:image/image.dart' as img;

// Match the unchanged Python backend: JPEG, <=1600px and <=512 KiB.
Uint8List preparePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('This image could not be read.');
  }
  var image = img.bakeOrientation(decoded);
  for (final edge in [1600, 1280, 1000, 800, 600]) {
    if (image.width > edge || image.height > edge) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? edge : null,
        height: image.height > image.width ? edge : null,
      );
    }
    for (final quality in [85, 70, 55]) {
      final jpeg = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      if (jpeg.length <= 480 * 1024) return jpeg;
    }
  }
  throw const FormatException('Choose a smaller image.');
}
