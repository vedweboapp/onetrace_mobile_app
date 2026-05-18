/// Base URL and relative paths for the backend API.
///
/// Paths include trailing slashes to match server routes.
/// Operation ids (OpenAPI-style) are noted in dartdoc where applicable.
abstract final class AppApiUrls {
  const AppApiUrls._();

  /// API host root (no trailing slash; Dio joins paths safely).
  static const String baseUrl = 'http://110.225.254.51:5050';

  static const String _v1 = '/api/v1';

  // ─── Auth ───────────────────────────────────────────────────────────────

  /// `POST` [auth_login_create]
  static const String authLogin = '$_v1/auth/login/';

  /// `POST` [auth_logout_create]
  static const String authLogout = '$_v1/auth/logout/';

  /// `POST` [auth_token_refresh_create]
  static const String authTokenRefresh = '$_v1/auth/token/refresh/';

  /// `POST` [auth_forgot-password_create]
  static const String authForgotPassword = '$_v1/auth/forgot-password/';

  /// `POST` [auth_invite-user_create]
  static const String authInviteUser = '$_v1/auth/invite-user/';

  /// `POST` [auth_send-otp_create]
  static const String authSendOtp = '$_v1/auth/send-otp/';

  /// `POST` [auth_resend-otp_create]
  static const String authResendOtp = '$_v1/auth/resend-otp/';

  /// `POST` [auth_verify-otp_create]
  static const String authVerifyOtp = '$_v1/auth/verify-otp/';

  /// `POST` org user self-registration
  static const String authOrgUserSignup = '$_v1/auth/org-user/signup/';

  /// `GET` · `PUT` · `PATCH` organization company settings
  static String organizationSettingsById(int organizationId) =>
      '$_v1/organizationsettings/$organizationId/';

  // ─── Clients ─────────────────────────────────────────────────────────────

  /// `GET` [clients_list] · `POST` [clients_create]
  static const String clients = '$_v1/clients/';

  /// `GET` [clients_read] · `PUT` [clients_update] · `PATCH` [clients_partial_update] · `DELETE` [clients_delete]
  static String clientsById(String id) => '$_v1/clients/$id/';

  // ─── Contacts ─────────────────────────────────────────────────────────────

  /// `GET` [contact_list] · `POST` [contact_create]
  static const String contacts = '$_v1/contact/';

  /// `GET` [contact_read] · `PUT` [contact_update] · `PATCH` [contact_partial_update] · `DELETE` [contact_delete]
  static String contactById(String id) => '$_v1/contact/$id/';

  // ─── Composite item ──────────────────────────────────────────────────────

  /// `GET` [composite-item_list] · `POST` [composite-item_create]
  static const String compositeItems = '$_v1/composite-item/';

  /// `GET` [composite-item_read] · `PUT` [composite-item_update] · `PATCH` [composite-item_partial_update] · `DELETE` [composite-item_delete]
  static String compositeItemById(String id) => '$_v1/composite-item/$id/';

  // ─── Group ────────────────────────────────────────────────────────────────

  /// `GET` [group_list] · `POST` [group_create]
  static const String groups = '$_v1/group/';

  /// `GET` [group_read] · `PUT` [group_update] · `PATCH` [group_partial_update] · `DELETE` [group_delete]
  static String groupById(String id) => '$_v1/group/$id/';

  // ─── Item ─────────────────────────────────────────────────────────────────

  /// `GET` [item_list] · `POST` [item_create]
  static const String items = '$_v1/item/';

  /// `GET` [item_read] · `PUT` [item_update] · `PATCH` [item_partial_update] · `DELETE` [item_delete]
  static String itemById(String id) => '$_v1/item/$id/';

  // ─── Pin status ───────────────────────────────────────────────────────────

  /// `GET` [pin-status_list] · `POST` [pin-status_create]
  static const String pinStatuses = '$_v1/pin-status/';

  /// `GET` [pin-status_read] · `PUT` [pin-status_update] · `PATCH` [pin-status_partial_update] · `DELETE` [pin-status_delete]
  static String pinStatusById(String id) => '$_v1/pin-status/$id/';

  // ─── Tags (quotations metadata) ───────────────────────────────────────────

  /// `GET` [tag_list] · `POST` [tag_create]
  static const String tags = '$_v1/tag/';

  /// `GET` [tag_read] · `PUT` [tag_update] · `PATCH` [tag_partial_update] · `DELETE` [tag_delete]
  static String tagById(String id) => '$_v1/tag/$id/';

  // ─── Project ───────────────────────────────────────────────────────────────

  /// `GET` [project_list] · `POST` [project_create]
  static const String projects = '$_v1/project/';

  /// `GET` [project_read] · `PUT` [project_update] · `PATCH` [project_partial_update] · `DELETE` [project_delete]
  static String projectById(String id) => '$_v1/project/$id/';

  /// `GET` [quotations_list] · `POST` [quotations_create]
  static const String quotations = '$_v1/quotations/';

  /// `GET` [quotations_read] · `PUT` [quotations_update] · `PATCH` [quotations_partial_update] · `DELETE` [quotations_delete]
  static String quotationById(String id) => '$_v1/quotations/$id/';

  /// `GET` [project_level_list] · `POST` [project_level_create]
  static String projectLevels(String projectId) =>
      '$_v1/project/$projectId/level/';

  /// `GET` [project_level_read] · `PUT` [project_level_update] · `PATCH` [project_level_partial_update] · `DELETE` [project_level_delete]
  static String projectLevelById(String projectId, String id) =>
      '$_v1/project/$projectId/level/$id/';

  // ─── User profile ─────────────────────────────────────────────────────────

  /// `GET` [role_list] · `POST` [role_create]
  static const String roles = '$_v1/role/';

  /// `GET` [user-profile_list]
  static const String userProfiles = '$_v1/user-profile/';

  /// `GET` [user-profile_read] · `PUT` [user-profile_update] · `PATCH` [user-profile_partial_update]
  static String userProfileById(String id) => '$_v1/user-profile/$id/';
}
