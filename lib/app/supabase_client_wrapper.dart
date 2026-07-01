import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/supabase_room_repository.dart';

/// Wrapper kecil agar RoomDetailPage bisa ambil kosId.
/// (Dipisahkan supaya tidak perlu akses langsung ke repository private field.)
class SupabaseClientWrapper {
  static String? getKosId() {
    return Supabase.instance.client.auth.currentUser?.userMetadata?['kos_id']?.toString();
  }

  static String? kosId(SupabaseRoomRepository _) => getKosId();
}

