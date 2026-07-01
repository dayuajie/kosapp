import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Utility kompresi JPEG untuk memenuhi target ukuran (mis. max 100KB)
/// dengan menjaga ketajaman semaksimal mungkin.
class ImageCompressService {
  /// Kompresi JPEG hingga <= [maxBytes] (best-effort) dengan iterasi quality.
  ///
  /// Catatan:
  /// - Jika hasil tetap > maxBytes, function akan mengembalikan hasil terbaik terakhir.
  /// - Works untuk file JPEG/JPG (jika input PNG/WebP, output tetap JPEG).
  Future<File> compressJpegToMax(
    File input, {
    required int maxBytes,
    int minQuality = 35,
    int maxQuality = 92,
    int qualityStep = 5,
    int? targetWidth,
  }) async {
    // Baca bytes awal ukuran kasar.
    final originBytes = await input.length();
    if (originBytes <= maxBytes) {
      return input;
    }

    // Opsional: resize untuk menurunkan ukuran lebih cepat.
    // targetWidth di sini hanya untuk mempercepat, tidak wajib.

    // Iterasi quality dari maxQuality turun sampai <= maxBytes.
    File? lastFile;
    for (int q = maxQuality; q >= minQuality; q -= qualityStep) {
      final outPath = '${input.path}.compress_q$q.jpg';

      final resultBytes = await FlutterImageCompress.compressWithFile(
        input.absolute.path,
        minWidth: targetWidth ?? 1000,
        // Jika targetWidth null, gunakan default agar tetap mengecilkan ukuran.
        quality: q,
        format: CompressFormat.jpeg,
      );

      if (resultBytes == null || resultBytes.isEmpty) {
        continue;
      }

      lastFile = await _writeBytesToFile(outPath, resultBytes);

      final outSize = await lastFile!.length();
      if (outSize <= maxBytes) {
        return lastFile;
      }

      // lanjut ke quality lebih rendah
    }

    // Jika tidak berhasil memenuhi maxBytes, kembalikan best-effort terakhir.
    return lastFile ?? input;
  }

  Future<File> _writeBytesToFile(String path, List<int> bytes) async {
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }
}

