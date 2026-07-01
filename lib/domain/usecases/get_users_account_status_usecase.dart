import '../entities/user_account_status_entity.dart';
import '../entities/user_profile_entity.dart';
import '../repositories/users_account_repository.dart';

class GetUsersAccountStatusUsecase {
  final UsersAccountRepository _repo;

  GetUsersAccountStatusUsecase(this._repo);

  Future<UserAccountStatusEntity?> call() async {
    return _repo.fetchMeWithStatus();
  }

  Future<UserProfileEntity?> fetchProfile() async {
    return _repo.fetchUserProfile();
  }
}

