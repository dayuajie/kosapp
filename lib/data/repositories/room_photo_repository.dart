import 'dart:io';
import '../../app/b2_config.dart';
import '../services/b2_storage_service.dart';
import '../services/image_compress_service.dart';

/// Repository khusus untuk upload/hapus foto room ke Backblaze B2.
///
/// - DB menyimpan object path B2 (bukan signed/public URL).
/// - Untuk preview, object path tersebut diubah jadi signed URL via B2SignedUrlService.
class RoomPhotoRepository {
  final B2StorageService _service;
  final ImageCompressService _compressService;

  RoomPhotoRepository({
    B2StorageService? service,
    ImageCompressService? compressService,
  })  : _service = service ?? B2StorageService(),
        _compressService = compressService ?? ImageCompressService();

  /// Upload foto room ke bucket `bucketRoomPhoto`.
  /// Returns objectName yang siap disimpan ke kolom `photo_asset_paths`.
  Future<String> roomPhotoObjectPath({
    required String roomId,
    required File file,
  }) async {
    // Di DB kolom namanya masih `photo_asset_paths`.
    // Untuk konsistensi, kita simpan object path di sana.
    final objectName =
        'rooms/$roomId/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Enforce size agar ringan.
    final compressed = await _compressService.compressJpegToMax(
      file,
      maxBytes: 150 * 1024,
      maxQuality: 92,
      minQuality: 40,
      qualityStep: 5,
      targetWidth: 1600,
    );

    // DEBUG: pastikan nama object dan ukuran hasil kompres sebelum upload.
    // ignore: avoid_print
    print('[RoomPhotoRepository] uploadRoomPhoto roomId=$roomId');
    // ignore: avoid_print
    print('[RoomPhotoRepository] objectName=$objectName');
    // ignore: avoid_print
    print('[RoomPhotoRepository] bucket=${B2Config.bucketRoomPhoto}');
    // ignore: avoid_print
    print('[RoomPhotoRepository] compressedExists=${await compressed.exists()}');

    await _service.uploadFile(
      file: compressed,
      bucketName: B2Config.bucketRoomPhoto,
      objectName: objectName,
      publicBaseUrl: B2Config.bucketRoomPhotoPublicBaseUrl,
    );

    return objectName;
  }


  /// Hapus foto room berdasarkan object path yang disimpan di DB.
  Future<void> deleteRoomPhotosByObjectPaths({
    required Iterable<String?> objectPaths,
  }) async {
    final paths = objectPaths
        .map((e) => (e ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (final objectName in paths) {
      await _service.deleteFileByObjectName(
        bucketName: B2Config.bucketRoomPhoto,
        objectName: objectName,
      );
    }
  }
}

