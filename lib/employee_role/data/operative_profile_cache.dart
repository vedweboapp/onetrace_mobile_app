import 'package:red5/employee_role/offline/operative_cache_policy.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart';

/// Session-scoped profile cache so header widgets do not each hit the API.
final class OperativeProfileCache {
  OperativeProfileCache._();

  static OperativeProfileCache? _instance;
  static OperativeProfileCache get instance =>
      _instance ??= OperativeProfileCache._();

  DateTime? _fetchedAt;
  String? _displayName;
  String? _avatarUrl;

  String? get displayName => _displayName;
  String? get avatarUrl => _avatarUrl;

  bool get isFresh =>
      OperativeCachePolicy.isFresh(_fetchedAt, OperativeCachePolicy.profileTtl);

  void apply(UserProfileModel profile, {String? avatarUrl}) {
    final name = '${profile.firstName} ${profile.lastName}'.trim();
    if (name.isNotEmpty) _displayName = name;
    _avatarUrl = avatarUrl;
    _fetchedAt = DateTime.now();
  }

  void clear() {
    _fetchedAt = null;
    _displayName = null;
    _avatarUrl = null;
  }
}
