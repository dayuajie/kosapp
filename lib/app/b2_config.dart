

import 'secrets.dart';

/// Backblaze B2 config reads credentials from `.env` via flutter_dotenv.
class B2Config {
  static String get applicationKey => Secrets.v('B2_APPLICATION_KEY');
  static String get accountId => Secrets.v('B2_ACCOUNT_ID');

  static String get apiUrl {
    final v = Secrets.v('B2_API_URL');
    return v.isEmpty ? 'https://api.backblazeb2.com' : v;
  }

  static String get bucketTenantPhoto {
    final v = Secrets.v('B2_BUCKET_TENANT_PHOTO');
    return v.isEmpty ? 'koskita-tenants' : v;
  }

  static String get bucketIdCardPhoto {
    final v = Secrets.v('B2_BUCKET_ID_CARD_PHOTO');
    return v.isEmpty ? 'koskita-idcard' : v;
  }
  static String get bucketRoomPhoto {
    final v = Secrets.v('B2_BUCKET_ROOM_PHOTO');
    return v.isEmpty ? 'koskita-rooms' : v;
  }

  static String get bucketTenantPhotoPublicBaseUrl =>
      Secrets.v('B2_BUCKET_TENANT_PHOTO_PUBLIC_BASE_URL');

  static String get bucketIdCardPhotoPublicBaseUrl =>
      Secrets.v('B2_BUCKET_ID_CARD_PHOTO_PUBLIC_BASE_URL');

  static String get bucketRoomPhotoPublicBaseUrl =>
      Secrets.v('B2_BUCKET_ROOM_PHOTO_PUBLIC_BASE_URL');
}

void validateB2Config() {
  final missing = <String>[];
  if (B2Config.applicationKey.isEmpty) missing.add('B2_APPLICATION_KEY');
  if (B2Config.accountId.isEmpty) missing.add('B2_ACCOUNT_ID');
  if (B2Config.bucketTenantPhoto.isEmpty) missing.add('B2_BUCKET_TENANT_PHOTO');
  if (B2Config.bucketIdCardPhoto.isEmpty) missing.add('B2_BUCKET_ID_CARD_PHOTO');
  if (B2Config.bucketRoomPhoto.isEmpty) missing.add('B2_BUCKET_ROOM_PHOTO');

  if (missing.isNotEmpty) {
    throw StateError('Missing env var(s) for B2: ${missing.join(', ')}');
  }
}



