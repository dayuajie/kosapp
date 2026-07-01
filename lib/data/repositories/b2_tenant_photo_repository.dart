import 'dart:io';

import '../../app/b2_config.dart';
import '../services/b2_storage_service.dart';
import '../services/image_compress_service.dart';

class B2TenantPhotoRepository {
  final B2StorageService _service;
  final ImageCompressService _compressService;

  B2TenantPhotoRepository({
    B2StorageService? service,
    ImageCompressService? compressService,
  })  : _service = service ?? B2StorageService(),
        _compressService = compressService ?? ImageCompressService();


  // =============================================================
  // NOTE: untuk perbaikan preview dengan B2 signed URL:
  // kita simpan object path B2 ke DB (tenants_url / idcard_url),
  // bukan public URL.
  // =============================================================

  Future<String> tenantPhotoObjectPath({
    required String tenantId,
    required File file,
  }) async {
    final objectName =
        'tenants/$tenantId/photo_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Enforce max 100KB agar tetap tajam (best-effort).
    final compressed = await _compressService.compressJpegToMax(
      file,
      maxBytes: 100 * 1024,
      maxQuality: 92,
      minQuality: 35,
      qualityStep: 5,
      targetWidth: 1200,
    );

    await _service.uploadFile(
      file: compressed,
      bucketName: B2Config.bucketTenantPhoto,
      objectName: objectName,
      // publicBaseUrl tidak dipakai untuk DB, tapi tetap dibutuhkan oleh service.
      publicBaseUrl: B2Config.bucketTenantPhotoPublicBaseUrl,
    );

    return objectName;
  }

  Future<String> idCardPhotoObjectPath({
    required String tenantId,
    required File file,
  }) async {
    final objectName =
        'idcard/$tenantId/idcard_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Enforce max 100KB agar tetap tajam (best-effort).
    final compressed = await _compressService.compressJpegToMax(
      file,
      maxBytes: 100 * 1024,
      maxQuality: 92,
      minQuality: 30,
      qualityStep: 5,
      targetWidth: 1200,
    );

    await _service.uploadFile(
      file: compressed,
      bucketName: B2Config.bucketIdCardPhoto,
      objectName: objectName,
      // publicBaseUrl tidak dipakai untuk DB, tapi tetap dibutuhkan oleh service.
      publicBaseUrl: B2Config.bucketIdCardPhotoPublicBaseUrl,
    );

    return objectName;
  }

  Future<void> deleteTenantPhotoByObjectPath({
    required String? tenantsUrlPath,
  }) async {
    final objectName = (tenantsUrlPath ?? '').trim();
    if (objectName.isEmpty) return;

    await _service.deleteFileByObjectName(
      bucketName: B2Config.bucketTenantPhoto,
      objectName: objectName,
    );
  }

  Future<void> deleteIdCardPhotoByObjectPath({
    required String? idCardUrlPath,
  }) async {
    final objectName = (idCardUrlPath ?? '').trim();
    if (objectName.isEmpty) return;

    await _service.deleteFileByObjectName(
      bucketName: B2Config.bucketIdCardPhoto,
      objectName: objectName,
    );
  }
}



