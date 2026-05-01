/// Keys for [LocalStorage] — keep stable so persisted data survives app updates.
abstract final class LocalStorageKeys {
  const LocalStorageKeys._();

  static const authRememberMe = 'auth_remember_me';
  static const authSavedEmail = 'auth_saved_email';

  /// JSON: `{ "documents": [...], "selectedIndex": int }` (legacy; migrated on read)
  static const quoteSession = 'quote_session_v1';

  /// JSON object: block name → `{ "documents": [...], "selectedIndex": int }`
  static const quotationsByBlock = 'quotations_by_block_v1';
}
