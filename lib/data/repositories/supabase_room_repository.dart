import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/b2_config.dart';
import '../../domain/entities/room_entity.dart';
import '../services/b2_signed_url_service.dart';
import 'occupancy_repository.dart';
import 'room_photo_repository.dart';
import 'room_repository.dart';

class SupabaseRoomRepository implements RoomRepository {
  final SupabaseClient _client;
  final OccupancyRepository _occupancyRepo;

  SupabaseRoomRepository({
    SupabaseClient? client,
    required OccupancyRepository occupancyRepo,
  })  : _client = client ?? Supabase.instance.client,
        _occupancyRepo = occupancyRepo;

  String _getFallbackKosId() {
    return _client.auth.currentUser?.userMetadata?['kos_id']?.toString() ?? '';
  }

  @override
  Future<List<RoomEntity>> fetchAllRoomsWithOccupancyStatus({
    String? activeKosId,
  }) async {
    final targetKosId = activeKosId ?? _getFallbackKosId();
    final rawRooms = await _client
        .from('rooms')
        .select('id, name, capacity, facilities, photo_asset_paths')
        .eq('kos_id', targetKosId)
        .order('name');

    final rooms = (rawRooms as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (rooms.isEmpty) return const [];

    // Delegasi sepenuhnya ke OccupancyRepository — tidak ada query occupancies di sini.
    final occupiedRoomIds = await _occupancyRepo.fetchOccupiedRoomIds(
      kosId: targetKosId,
    );

    return rooms.map((r) {
      final idStr = r['id']?.toString() ?? '';
      return _mapToEntity(r, isOccupied: occupiedRoomIds.contains(idStr));
    }).toList();
  }

  @override
  Future<List<RoomEntity>> fetchAvailableRooms({String? activeKosId}) async {
    final all = await fetchAllRoomsWithOccupancyStatus(
      activeKosId: activeKosId,
    );
    return all.where((r) => !r.isOccupied).toList();
  }

  @override
  Future<RoomEntity?> fetchRoomById(String roomId) async {
    final rawRoom = await _client
        .from('rooms')
        .select('id, name, capacity, facilities, photo_asset_paths')
        .eq('id', roomId)
        .maybeSingle();

    if (rawRoom == null) return null;
    return _mapToEntity(rawRoom as Map<String, dynamic>);
  }

  // ===========================================================================
  // REGION: CREATE
  // ===========================================================================

  @override
  Future<void> createRoom({
    required String name,
    required int capacity,
    required List<String> facilities,
    required String kosId,
    List<String>? photoObjectPaths,
    String? createdBy,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'capacity': capacity,
      'facilities': facilities,
      'photo_asset_paths': photoObjectPaths ?? [],
      'kos_id': kosId,
      if (createdBy != null) 'created_by': createdBy,
    };
    await _client.from('rooms').insert(payload);
  }


  // ===========================================================================
  // REGION: UPDATE
  // ===========================================================================

  @override
  Future<void> updateRoomBasic({
    required String roomId,
    String? name,
    int? capacity,
    List<String>? facilities,
  }) async {
    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (capacity != null) 'capacity': capacity,
      if (facilities != null) 'facilities': facilities,
    };

    if (payload.isEmpty) return;

    await _client.from('rooms').update(payload).eq('id', roomId);
  }

  @override
  Future<void> updateRoomPhotos({
    required String roomId,
    required List<String> photoObjectPaths,
  }) async {
    await _client
        .from('rooms')
        .update({'photo_asset_paths': photoObjectPaths})
        .eq('id', roomId);
  }


  // ===========================================================================
  // REGION: DELETE
  // ===========================================================================

  @override
  Future<void> deleteRoom({required String roomId}) async {
    // 1. Ambil foto lalu hapus dari B2
    final room = await fetchRoomById(roomId);
    final photoPaths = room?.photoAssetPaths ?? const [];
    if (photoPaths.isNotEmpty) {
      await RoomPhotoRepository()
          .deleteRoomPhotosByObjectPaths(objectPaths: photoPaths);
    }

    // 2. Hapus semua occupancy kamar via OccupancyRepository (bukan query langsung)
    await _occupancyRepo.deleteOccupanciesByRoom(roomId: roomId);

    // 3. Hapus record room
    await _client.from('rooms').delete().eq('id', roomId);
  }

  // ===========================================================================
  // REGION: PHOTO HELPERS
  // ===========================================================================

  @override
  Future<List<String>> uploadRoomPhotos({
    required String roomId,
    required List<File> files,
  }) async {
    final repo = RoomPhotoRepository();
    final results = <String>[];
    for (final f in files) {
      results.add(await repo.roomPhotoObjectPath(roomId: roomId, file: f));
    }
    return results;
  }

  @override
  Future<List<String>> fetchRoomPhotoSignedUrls({
    required String roomId,
    Duration validFor = const Duration(minutes: 10),
  }) async {
    final room = await fetchRoomById(roomId);
    if (room == null) return const [];

    final signed = await Future.wait(
      room.photoAssetPaths.map(
        (objectName) => B2SignedUrlService.instance.getSignedDownloadUrl(
          bucketName: B2Config.bucketRoomPhoto,
          objectName: objectName,
          validFor: validFor,
        ),
      ),
    );

    return signed;
  }

  // ===========================================================================
  // REGION: PRIVATE HELPERS
  // ===========================================================================

  RoomEntity _mapToEntity(
    Map<String, dynamic> r, {
    bool isOccupied = false,
  }) {
    final capRaw = r['capacity'];
    final capacity = capRaw is int
        ? capRaw
        : int.tryParse(capRaw?.toString() ?? '') ?? 1;

    return RoomEntity(
      id: r['id'].toString(),
      name: (r['name'] ?? '').toString(),
      isOccupied: isOccupied,
      capacity: capacity,
      facilities: _parseStringList(r['facilities']),
      photoAssetPaths: _parseStringList(r['photo_asset_paths']),
    );
  }

  List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];

    if (raw is List) {
      return raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    if (raw is String) {
      final cleaned = raw.trim();
      if (cleaned.isEmpty) return const [];

      final unwrapped = (cleaned.startsWith('[') && cleaned.endsWith(']'))
          ? cleaned.substring(1, cleaned.length - 1)
          : cleaned;

      return unwrapped
          .split(',')
          .map((e) => e.trim())
          // Jika DB menyimpan string dengan escaping seperti "\\"TV\\" dan seterusnya",
          // buang karakter kutip yang ter-e-escape.
          .map((e) => e.replaceAll(r'\\"', '"').replaceAll(r'\\', '').replaceAll('"', '').trim())
          .where((e) => e.isNotEmpty)
          .toList();

    }

    return const [];
  }
}