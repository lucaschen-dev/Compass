import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

const galleryPhotoLimit = 4;
const galleryPhotoEncodedLimit = 160000;
const _sourceImageLimit = 8 * 1024 * 1024;

// Shared photos are embedded in the existing post document. Four bounded
// values leave room for the caption and document overhead under 1 MiB.
bool isSharedGalleryPhoto(String value) {
  if (value.length < 32 ||
      value.length > galleryPhotoEncodedLimit ||
      value.length % 4 != 0 ||
      !value.startsWith('iVBORw0KGgo') ||
      !_base64Image.hasMatch(value)) {
    return false;
  }
  final header = ByteData.sublistView(base64Decode(value.substring(0, 32)));
  // PNG's first chunk is IHDR. Reject larger dimensions before rendering.
  final width = header.getUint32(16);
  final height = header.getUint32(20);
  return header.getUint32(12) == 0x49484452 &&
      width > 0 &&
      width <= 720 &&
      height > 0 &&
      height <= 720;
}

final _base64Image = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');

Future<List<String>> chooseGalleryPhotos(int remaining) async {
  final files = await openFiles(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Photos',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        uniformTypeIdentifiers: ['public.image'],
      ),
    ],
  );
  if (files.length > remaining) {
    throw ArgumentError('Choose no more than $remaining more photos.');
  }
  final photos = <String>[];
  for (final file in files) {
    if (await file.length() > _sourceImageLimit) {
      throw ArgumentError('Choose photos smaller than 8 MB each.');
    }
    photos.add(await encodeGalleryPhoto(await file.readAsBytes()));
  }
  return photos;
}

Future<String> encodeGalleryPhoto(Uint8List source) async {
  if (source.length > _sourceImageLimit) {
    throw ArgumentError('Choose photos smaller than 8 MB each.');
  }
  final codec = await ui.instantiateImageCodec(source);
  try {
    final image = (await codec.getNextFrame()).image;
    try {
      if (image.width * image.height > 50 * 1000 * 1000) {
        throw ArgumentError('Choose a smaller photo.');
      }
      final longest = image.width > image.height ? image.width : image.height;
      final edges = {
        for (final size in [720, 560, 420, 320, 240, 180])
          size.clamp(1, longest),
      };
      for (final edge in edges) {
        final png = await _galleryPng(image, edge / longest);
        if (png != null &&
            (png.lengthInBytes + 2) ~/ 3 * 4 <= galleryPhotoEncodedLimit) {
          return base64Encode(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          );
        }
      }
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
  throw ArgumentError('This photo could not be made small enough to share.');
}

Future<ByteData?> _galleryPng(ui.Image image, double scale) async {
  // Drawing resized pixels into a fresh PNG works on the browser renderer and
  // excludes the original file's EXIF data, such as GPS and capture time.
  final width = (image.width * scale).round().clamp(1, 720);
  final height = (image.height * scale).round().clamp(1, 720);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  try {
    final resized = await picture.toImage(width, height);
    try {
      return await resized.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      resized.dispose();
    }
  } finally {
    picture.dispose();
  }
}
