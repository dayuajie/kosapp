
abstract class KosRepository {
  String? get currentUserId;
  String? get currentKosId;
  Future<List<Map<String, dynamic>>> fetchKosByOwner(String ownerId);
  Future<String> createKos({
    required String name,
    required String address,
    required String phone,
    required String capacities,
    required String ownerId,
  });

  Future<void> switchActiveKos(String kosId);
}