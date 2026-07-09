/// TTL rules for operative list/profile caches (reduces repeat API calls).

abstract final class OperativeCachePolicy {

  const OperativeCachePolicy._();



  /// Jobs / projects lists refresh at most once per interval unless forced.

  static const jobsListTtl = Duration(minutes: 10);

  static const projectsListTtl = Duration(minutes: 10);



  /// Background jobs refresh for assignment notifications.

  static const notificationPollInterval = Duration(minutes: 10);



  static const profileTtl = Duration(minutes: 30);



  static bool isFresh(DateTime? fetchedAt, Duration ttl) {

    if (fetchedAt == null) return false;

    return DateTime.now().difference(fetchedAt) < ttl;

  }

}


