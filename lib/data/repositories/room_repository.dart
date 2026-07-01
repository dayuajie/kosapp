import 'dart:io';
import '../../domain/entities/room_entity.dart';

abstract class RoomRepository {
  Future<List<RoomEntity>> fetchAllRoomsWithOccupancyStatus({
    String? activeKosId,
  });
  Future<List<RoomEntity>> fetchAvailableRooms({
    String? activeKosId,
  });
  Future<RoomEntity?> fetchRoomById(String roomId);
  Future<void> createRoom({
    required String name,
    required int capacity,
    required List<String> facilities,
    required String kosId,
    List<String>? photoObjectPaths,
    String? createdBy,
  });
  Future<void> updateRoomBasic({
    required String roomId,
    String? name,
    int? capacity,
    List<String>? facilities,
  });
  Future<void> updateRoomPhotos({
    required String roomId,
    required List<String> photoObjectPaths,
  });
  Future<void> deleteRoom({required String roomId});
  Future<List<String>> uploadRoomPhotos({
    required String roomId,
    required List<File> files,
  });

  /// Mengambil signed URL untuk semua foto sebuah kamar.
  Future<List<String>> fetchRoomPhotoSignedUrls({
    required String roomId,
    Duration validFor = const Duration(minutes: 10),
  });
}