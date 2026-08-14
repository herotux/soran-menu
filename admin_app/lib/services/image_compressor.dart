import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressor {
  static Future<Uint8List> compress(
    Uint8List bytes, {
    int maxWidth = 1600,
    int maxHeight = 1600,
    int quality = 80,
  }) async {
    if (bytes.isEmpty) {
      return bytes;
    }

    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: CompressFormat.webp,
    );

    if (result.isEmpty) {
      return bytes;
    }

    return Uint8List.fromList(result);
  }
}
