import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../app/b2_config.dart';

abstract class SignedUrlService {
  Future<String> getSignedDownloadUrl({
    required String bucketName,
    required String objectName,
    Duration validFor = const Duration(minutes: 10),
  });
  
  void dispose();
}

/// B2 signed URL service yang dioptimalkan untuk kecepatan dan efisiensi memori.
class B2SignedUrlService implements SignedUrlService {
  // Gunakan satu client untuk memanfaatkan HTTP Keep-Alive (performa melesat)
  final http.Client _client;

  B2SignedUrlService({http.Client? client}) : _client = client ?? http.Client();

  // Cache berupa Future untuk menghindari race-condition / double request
  static Future<_B2Auth>? _authFuture;
  static DateTime? _authExpiresAt;

  // Cache bucket ID menggunakan Future agar request nama bucket yang sama tidak bentrok
  static final Map<String, Future<String>> _bucketIdFutures = {};
  static final Map<String, DateTime> _bucketIdExpiresAt = {};

  static const _authRefreshSkew = Duration(seconds: 30);

  @override
  Future<String> getSignedDownloadUrl({
    required String bucketName,
    required String objectName,
    Duration validFor = const Duration(minutes: 10),
  }) async {
    // 1 & 2. Dapatkan auth dan bucket ID secara paralel untuk efisiensi waktu
    final authAndBucket = await Future.wait([
      _getOrAuthorize(),
      _getOrGetBucketId(bucketName),
    ]);

    final auth = authAndBucket[0] as _B2Auth;
    final bucketId = authAndBucket[1] as String;

    // 3. Request token otorisasi spesifik untuk file tersebut
    final url = '${auth.apiUrl}/b2api/v4/b2_get_download_authorization';
    
    final res = await _client.post(
      Uri.parse(url),
      headers: {
        HttpHeaders.authorizationHeader: auth.authorizationToken,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'bucketId': bucketId,
        'fileNamePrefix': objectName,
        'validDurationInSeconds': validFor.inSeconds,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('B2 get_download_authorization failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final authToken = data['authorizationToken']?.toString();

    if (authToken == null || authToken.isEmpty) {
      throw StateError('B2 download authorizationToken missing/invalid.');
    }

    // 4. Susun URL akhir dengan efisien
    final prefix = auth.downloadUrl.endsWith('/') ? auth.downloadUrl : '${auth.downloadUrl}/';
    final encodedToken = Uri.encodeQueryComponent(authToken);

    return '${prefix}file/$bucketName/$objectName?Authorization=$encodedToken';
  }

  Future<_B2Auth> _getOrAuthorize() {
    final now = DateTime.now();

    // Jika cache valid, langsung kembalikan Future yang sudah ada
    if (_authFuture != null && _authExpiresAt != null) {
      if (now.isBefore(_authExpiresAt!.subtract(_authRefreshSkew))) {
        return _authFuture!;
      }
    }

    // Set expiration secara konservatif sebelum memulai request
    _authExpiresAt = now.add(const Duration(minutes: 20));
    
    // Simpan Future-nya ke dalam variable static. 
    // Request lain yang masuk bersamaan akan menunggu Future yang sama ini.
    _authFuture = _authorize().catchError((Object e) {
      // Jika gagal, bersihkan cache agar request berikutnya bisa mencoba lagi
      _authFuture = null;
      _authExpiresAt = null;
      throw e;
    });

    return _authFuture!;
  }

  Future<_B2Auth> _authorize() async {
    final authUrl = '${B2Config.apiUrl}/b2api/v4/b2_authorize_account';
    final credentials = '${B2Config.accountId}:${B2Config.applicationKey}';
    final base64Credentials = base64Encode(utf8.encode(credentials));

    final res = await _client.get(
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
    final token = data['authorizationToken']?.toString();
    final accountId = data['accountId']?.toString();

    final apiInfo = data['apiInfo'] as Map<String, dynamic>?;
    final storageApi = apiInfo?['storageApi'] as Map<String, dynamic>?;
    final apiUrl = storageApi?['apiUrl']?.toString();
    final downloadUrl = storageApi?['downloadUrl']?.toString();

    if (token == null || apiUrl == null || accountId == null || downloadUrl == null) {
      throw StateError('B2 authorize: Missing required response fields.');
    }

    return _B2Auth(
      authorizationToken: token,
      apiUrl: apiUrl,
      accountId: accountId,
      downloadUrl: downloadUrl,
    );
  }

  Future<String> _getOrGetBucketId(String bucketName) {
    final now = DateTime.now();
    final cachedFuture = _bucketIdFutures[bucketName];
    final expiresAt = _bucketIdExpiresAt[bucketName];

    if (cachedFuture != null && expiresAt != null && now.isBefore(expiresAt)) {
      return cachedFuture;
    }

    _bucketIdExpiresAt[bucketName] = now.add(const Duration(days: 7));
    
    final future = _getBucketId(bucketName).catchError((Object e) {
      _bucketIdFutures.remove(bucketName);
      _bucketIdExpiresAt.remove(bucketName);
      throw e;
    });

    _bucketIdFutures[bucketName] = future;
    return future;
  }

  Future<String> _getBucketId(String bucketName) async {
    // Memastikan auth sudah siap terlebih dahulu khusus untuk internal call pembuka
    final auth = await _getOrAuthorize();
    
    final url = '${auth.apiUrl}/b2api/v4/b2_list_buckets';
    final res = await _client.post(
      Uri.parse(url),
      headers: {
        HttpHeaders.authorizationHeader: auth.authorizationToken,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({'accountId': auth.accountId}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('B2 list buckets failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final buckets = data['buckets'] as List? ?? [];

    for (final b in buckets) {
      if (b is Map<String, dynamic> && b['bucketName']?.toString() == bucketName) {
        final id = b['bucketId']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    }

    throw StateError('B2 bucket not found or invalid id: $bucketName');
  }

  /// PENTING: Panggil fungsi ini jika service dihancurkan (misal di dispose bloc/provider)
  @override
  void dispose() {
    _client.close();
  }
}

class _B2Auth {
  final String authorizationToken;
  final String apiUrl;
  final String accountId;
  final String downloadUrl;

  const _B2Auth({
    required this.authorizationToken,
    required this.apiUrl,
    required this.accountId,
    required this.downloadUrl,
  });
}