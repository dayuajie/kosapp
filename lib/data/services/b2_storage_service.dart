import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../app/b2_config.dart';

class B2StorageService {
  B2StorageService();

  /// 1. Authorize Account (API v4)
  Future<_B2Auth> _authorize() async {
    validateB2Config();

    final authUrl = '${B2Config.apiUrl}/b2api/v4/b2_authorize_account';

    // Basic auth: keyId:applicationKey
    final String credentials = '${B2Config.accountId}:${B2Config.applicationKey}';
    final String base64Credentials = base64Encode(utf8.encode(credentials));

    final res = await http.get(
      Uri.parse(authUrl),
      headers: {
        HttpHeaders.authorizationHeader: 'Basic $base64Credentials',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('B2 authorize failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    final tokenRaw = data['authorizationToken'];
    if (tokenRaw is! String || tokenRaw.isEmpty) {
      throw StateError(
        'B2 authorize: authorizationToken missing/invalid. Response: ${res.body}',
      );
    }

    final apiInfoRaw = data['apiInfo'];
    if (apiInfoRaw is! Map) {
      throw StateError(
        'B2 authorize: apiInfo missing/invalid. Response: ${res.body}',
      );
    }

    final storageApiRaw = apiInfoRaw['storageApi'];
    if (storageApiRaw is! Map) {
      throw StateError(
        'B2 authorize: apiInfo.storageApi missing/invalid. Response: ${res.body}',
      );
    }

    final apiUrlRaw = storageApiRaw['apiUrl'];
    if (apiUrlRaw is! String || apiUrlRaw.isEmpty) {
      throw StateError(
        'B2 authorize: storageApi.apiUrl missing/invalid. Response: ${res.body}',
      );
    }

    final accountIdRaw = data['accountId'];
    final accountId =
        (accountIdRaw is String && accountIdRaw.isNotEmpty) ? accountIdRaw : B2Config.accountId;

    return _B2Auth(
      authorizationToken: tokenRaw,
      apiUrl: apiUrlRaw,
      accountId: accountId,
    );
  }

  /// 2. Get Bucket Info (API v4)
  Future<_B2BucketInfo> _getBucketInfo({

    required String bucketName,
    required String authorizationToken,
    required String apiUrl,
    required String accountId,
  }) async {
    // Pada v4, list_buckets menggunakan POST dan mengirimkan accountId lewat JSON Body
    final url = '$apiUrl/b2api/v4/b2_list_buckets';

    final res = await http.post(
      Uri.parse(url),
      headers: {
        HttpHeaders.authorizationHeader: authorizationToken,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({'accountId': accountId}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('B2 list buckets failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final buckets = (data['buckets'] as List).cast<Map<String, dynamic>>();

    final bucket = buckets.firstWhere(
      (b) => (b['bucketName'] as String) == bucketName,
      orElse: () => throw StateError('B2 bucket not found: $bucketName'),
    );

    final bucketNameRaw = bucket['bucketName'];

    if (bucketNameRaw is! String || bucketNameRaw.isEmpty) {
      throw StateError('B2 bucketName missing/invalid. bucket=$bucket');
    }

    final bucketIdRaw = bucket['bucketId'];
    if (bucketIdRaw is! String || bucketIdRaw.isEmpty) {
      throw StateError('B2 bucketId missing/invalid. bucket=$bucket');
    }

    return _B2BucketInfo(
      bucketId: bucketIdRaw,
      bucketName: bucketNameRaw,
    );
  }

  /// 3. Upload File Flow (API v4)
  Future<String> uploadFile({
    required File file,
    required String bucketName,
    required String objectName,
    required String publicBaseUrl,
  }) async {
    final auth = await _authorize();
    final bucket = await _getBucketInfo(
      bucketName: bucketName,
      authorizationToken: auth.authorizationToken,
      apiUrl: auth.apiUrl,
      accountId: auth.accountId,
    );

    // Catatan: di implementasi ini kita masih memfilter berdasarkan objectName.
    // (bucketId akan diperlukan bila API meminta bucketId secara eksplisit).




    

    // Mengubah b2_get_upload_url ke v4 agar konsisten
    // NOTE: b2_get_upload_url versi v4 membutuhkan bucketId.
    final uploadUrlApi = '${auth.apiUrl}/b2api/v4/b2_get_upload_url';
    final uploadUrlRes = await http.post(
      Uri.parse(uploadUrlApi),
      headers: {
        HttpHeaders.authorizationHeader: auth.authorizationToken,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'bucketId': bucket.bucketId,
      }),
    );


    if (uploadUrlRes.statusCode < 200 || uploadUrlRes.statusCode >= 300) {
      throw StateError(
        'B2 get_upload_url failed: ${uploadUrlRes.statusCode} ${uploadUrlRes.body}',
      );
    }

    final uploadData = jsonDecode(uploadUrlRes.body) as Map<String, dynamic>;
    final uploadUrl = uploadData['uploadUrl'] as String;
    final uploadAuthToken = uploadData['authorizationToken'] as String;
    final bytes = await file.readAsBytes();

    // DEBUG upload flow
    // ignore: avoid_print
    print('[B2StorageService] uploadFile bucket=$bucketName objectName=$objectName bytes=${bytes.length}');
    // ignore: avoid_print
    print('[B2StorageService] uploadUrl=$uploadUrl');

    // Proses upload file b2_upload_file langsung ke uploadUrl endpoint khusus
    final res = await http.post(
      Uri.parse(uploadUrl),
      headers: {
        HttpHeaders.authorizationHeader: uploadAuthToken,
        'Content-Type': 'b2/x-auto',
        'X-Bz-File-Name': Uri.encodeComponent(objectName),
        'Content-Length': bytes.length.toString(),
        'X-Bz-Content-Sha1': 'do_not_verify',
      },
      body: bytes,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      // ignore: avoid_print
      print('[B2StorageService] upload failed status=${res.statusCode} body=${res.body}');
      throw StateError('B2 upload failed: ${res.statusCode} ${res.body}');
    }

    // ignore: avoid_print
    print('[B2StorageService] upload success status=${res.statusCode}');


    if (publicBaseUrl.isEmpty) {
      throw StateError(
        'B2 publicBaseUrl kosong. Pastikan env: B2_BUCKET_TENANT_PHOTO_PUBLIC_BASE_URL / B2_BUCKET_ID_CARD_PHOTO_PUBLIC_BASE_URL terisi dan dotenv berhasil load.',
      );
    }

    final base = publicBaseUrl.endsWith('/')
        ? publicBaseUrl.substring(0, publicBaseUrl.length - 1)
        : publicBaseUrl;

    return '$base/$objectName';
  }

  /// 4. Delete File By Object Name (API v4)
  ///
  /// Catatan:
  /// - Endpoint delete yang tersedia di B2 biasanya membutuhkan fileId.
  /// - Untuk itu kita perlu list versi file untuk objectName, lalu delete file versionnya.
  /// - Jika object tidak ditemukan, method ini akan silently return.
  Future<void> deleteFileByObjectName({
    required String bucketName,
    required String objectName,
  }) async {
    final cleanObjectName = objectName.trim();
    if (cleanObjectName.isEmpty) return;

    final auth = await _authorize();
    final bucket = await _getBucketInfo(
      bucketName: bucketName,
      authorizationToken: auth.authorizationToken,
      apiUrl: auth.apiUrl,
      accountId: auth.accountId,
    );

    // 1) List file versions for objectName (API v4)
    // We use b2_list_file_versions with startFileName and maxFileCount.
    // For simplicity we request first page and then filter by fileName==objectName.
    // This is adequate for typical usage since each objectName is unique per tenant photo.

    final listUrl = '${auth.apiUrl}/b2api/v4/b2_list_file_versions';

    final listRes = await http.post(
      Uri.parse(listUrl),
      headers: {
        HttpHeaders.authorizationHeader: auth.authorizationToken,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'bucketId': bucket.bucketId,
        'startFileName': cleanObjectName,
        'maxFileCount': 100,
      }),
    );

    if (listRes.statusCode < 200 || listRes.statusCode >= 300) {
      throw StateError('B2 list_file_versions failed: ${listRes.statusCode} ${listRes.body}');
    }

    final listData = jsonDecode(listRes.body) as Map<String, dynamic>;
    final versions = (listData['files'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final matching = versions
        .where((f) => (f['fileName'] as String?) == cleanObjectName)
        .toList();

    if (matching.isEmpty) {
      // object doesn't exist
      return;
    }

    // 2) Delete each version
    final deleteUrl = '${auth.apiUrl}/b2api/v4/b2_delete_file_version';

    for (final f in matching) {
      final fileId = f['fileId'];
      final fileName = f['fileName'];

      if (fileId is! String || fileId.isEmpty) continue;
      if (fileName is! String || fileName.isEmpty) continue;

      final fileDeleteRes = await http.post(
        Uri.parse(deleteUrl),
        headers: {
          HttpHeaders.authorizationHeader: auth.authorizationToken,
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode({
          'fileId': fileId,
          'fileName': fileName,
        }),
      );

      if (fileDeleteRes.statusCode < 200 || fileDeleteRes.statusCode >= 300) {
        throw StateError(
          'B2 delete_file_version failed: ${fileDeleteRes.statusCode} ${fileDeleteRes.body}',
        );
      }
    }
  }
}

/// --- Data Models ---

class _B2Auth {
  final String authorizationToken;
  final String apiUrl;
  final String accountId;

  _B2Auth({
    required this.authorizationToken,
    required this.apiUrl,
    required this.accountId,
  });
}

class _B2BucketInfo {
  final String bucketId;
  final String bucketName;

  _B2BucketInfo({
    required this.bucketId,
    required this.bucketName,
  });
}


