class RoomEntity {
  final String id;
  final String name;
  final bool isOccupied;
  final int capacity;
  final List<String> facilities;
  final List<String> photoAssetPaths;

  const RoomEntity({
    required this.id,
    required this.name,
    required this.isOccupied,
    required this.capacity,
    required this.facilities,
    required this.photoAssetPaths,
  });

  RoomEntity copyWith({
    String? id,
    String? name,
    bool? isOccupied,
    int? capacity,
    List<String>? facilities,
    List<String>? photoAssetPaths,
  }) {
    return RoomEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isOccupied: isOccupied ?? this.isOccupied,
      capacity: capacity ?? this.capacity,
      facilities: facilities ?? this.facilities,
      photoAssetPaths: photoAssetPaths ?? this.photoAssetPaths,
    );
  }
}

