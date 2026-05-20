/// Keys for [LocalStorage] — keep stable so persisted data survives app updates.
abstract final class LocalStorageKeys {
  const LocalStorageKeys._();

  static const authRememberMe = 'auth_remember_me';
  static const authSavedEmail = 'auth_saved_email';
  static const authAccessToken = 'auth_access_token';
  static const authRefreshToken = 'auth_refresh_token';

  /// Stringified `data.user.id` from login / verify-otp (for `/user-profile/{id}/`).
  static const authUserId = 'auth_user_id';

  /// Active organization id (login response + [OrganizationIdHeader]).
  static const authOrganizationId = 'auth_organization_id';

  /// JSON: `{ "documents": [...], "selectedIndex": int }` (legacy; migrated on read)
  static const quoteSession = 'quote_session_v1';

  /// JSON object: block name → `{ "documents": [...], "selectedIndex": int }`
  static const quotationsByBlock = 'quotations_by_block_v1';

  /// `drawer` | `bottom_sheet` — how main overflow navigation opens (see [NavMenuStylePreference]).
  static const appNavMenuStyle = 'app_nav_menu_style_v1';
}
