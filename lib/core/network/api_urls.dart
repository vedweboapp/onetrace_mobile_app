/// Base URL and relative paths for the backend API.
///
/// Paths include trailing slashes to match server routes.
/// Operation ids (OpenAPI-style) are noted in dartdoc where applicable.
abstract final class AppApiUrls {
  const AppApiUrls._();

  /// API host root (no trailing slash; Dio joins paths safely).
  static const String baseUrl = 'http://110.225.254.51:5050';

  /// Purchase orders API (separate host from main CRM API).
  static const String purchaseOrdersBaseUrl = 'http://110.225.254.51:5001';

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

  // ─── Vendors ─────────────────────────────────────────────────────────────

  /// `GET` [vendors_list] · `POST` [vendors_create]
  static const String vendors = '$_v1/vendors/';

  /// `GET` [vendors_read] · `PUT` [vendors_update] · `PATCH` [vendors_partial_update] · `DELETE` [vendors_delete]
  static String vendorsById(String id) => '$_v1/vendors/$id/';

  /// `GET` [vendor-type_list] · `POST` [vendor-type_create]
  static const String vendorTypes = '$_v1/vendor-type/';

  /// `GET` [vendor-type_read] · `PUT` [vendor-type_update] · `PATCH` [vendor-type_partial_update] · `DELETE` [vendor-type_delete]
  static String vendorTypeById(String id) => '$_v1/vendor-type/$id/';

  // ─── Purchase orders (port 5001 — no trailing slash on these routes) ─────

  /// `GET` [purchase-orders_list] · `POST` [purchase-orders_create]
  static const String purchaseOrders = '$_v1/purchase-orders';

  /// `GET` [purchase-orders_read] · `PUT` [purchase-orders_update] · `PATCH` [purchase-orders_partial_update] · `DELETE` [purchase-orders_delete]
  static String purchaseOrderById(String id) => '$_v1/purchase-orders/$id';

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

  /// `GET` jobs linked to a project — `GET /project/{id}/jobs/`.
  static String projectJobs(String projectId) =>
      '$_v1/project/$projectId/jobs/';

  /// `GET` list · `POST` create — server route is singular `invoice/`.
  static const String invoices = '$_v1/invoice/';

  /// `GET` detail by id.
  static String invoiceById(String id) => '$_v1/invoice/$id/';

  /// `GET` generated PDF — endpoint pending backend support.
  static String invoicePdfById(String id) => '$_v1/invoice/$id/pdf/';

  /// `GET` [quotations_list] · `POST` [quotations_create]
  static const String quotations = '$_v1/quotations/';

  /// `GET` [quotations_read] · `PUT` [quotations_update] · `PATCH` [quotations_partial_update] · `DELETE` [quotations_delete]
  static String quotationById(String id) => '$_v1/quotations/$id/';

  /// `GET` [jobs_list] · `POST` [jobs_create]
  static const String jobs = '$_v1/jobs/';

  /// `POST` [jobs_create_from_quotation]
  static const String jobsCreateFromQuotation =
      '$_v1/jobs/create-from-quotation/';

  /// `GET` [jobs_read] · `PUT` [jobs_update] · `PATCH` [jobs_partial_update] · `DELETE` [jobs_delete]
  static String jobById(String id) => '$_v1/jobs/$id/';

  /// `POST` start/stop a job timer for a worker.
  static String jobTimer(int jobId) => '$_v1/jobs/$jobId/timer/';

  /// `GET` timer history for a job.
  static String jobTimers(int jobId) => '$_v1/jobs/$jobId/timers/';

  /// `POST` submit a filled form for a job.
  static String jobSubmitForm(int jobId) => '$_v1/jobs/$jobId/submit-form/';

  /// `GET` all submitted forms for a job.
  static String jobSubmittedForms(int jobId) =>
      '$_v1/jobs/$jobId/submitted-forms/';

  /// `GET` worker earnings summary and list (`?worker=`).
  static const String jobEarnings = '$_v1/job-earnings/';

  /// `POST` mark earning paid/unpaid (admin / manager).
  static String jobEarningsUpdateStatus(int jobId) =>
      '$_v1/job-earnings/$jobId/update-status/';

  /// `GET` one submission record for a job ([submissionId], not job or form id).
  static String jobSubmittedFormById(int jobId, int submissionId) =>
      '$_v1/jobs/$jobId/submitted-forms/$submissionId/';

  /// `PUT` update an existing submission for a job.
  static String jobSubmittedFormUpdate(int jobId, int submissionId) =>
      '$_v1/jobs/$jobId/submitted-forms/$submissionId/update/';

  /// `POST` record a QR scan against a job.
  static String jobScanQr(int jobId) => '$_v1/jobs/$jobId/scan-qr/';

  /// `GET` job status metadata (dropdowns).
  static const String jobStatuses = '$_v1/job-status/';

  /// `GET` [job-status_read] — single job status (`data.id`, `status_name`, …).
  static String jobStatusById(String id) => '$_v1/job-status/$id/';

  /// `GET` [project-type_list] · `POST` [project-type_create]
  static const String projectTypes = '$_v1/project-type/';

  /// `GET` [project-type_read] · `PUT` [project-type_update] · `PATCH` [project-type_partial_update] · `DELETE` [project-type_delete]
  static String projectTypeById(String id) => '$_v1/project-type/$id/';

  /// `GET` [installation-type_list] · `POST` [installation-type_create]
  static const String installationTypes = '$_v1/installation-type/';

  /// `GET` [installation-type_read] · `PUT` [installation-type_update] · `PATCH` [installation-type_partial_update] · `DELETE` [installation-type_delete]
  static String installationTypeById(String id) =>
      '$_v1/installation-type/$id/';

  // ─── Site ──────────────────────────────────────────────────────────────────

  /// `GET` [site_list] · `POST` [site_create]
  static const String sites = '$_v1/site/';

  /// `GET` [site_read] · `PUT` [site_update] · `PATCH` [site_partial_update] · `DELETE` [site_delete]
  static String siteById(String id) => '$_v1/site/$id/';

  // ─── Forms ─────────────────────────────────────────────────────────────────

  /// `GET` [forms_list] · `POST` [forms_create]
  static const String forms = '$_v1/forms/';

  /// `GET` [forms_read] · `PUT` [forms_update] · `PATCH` [forms_partial_update] · `DELETE` [forms_delete]
  static String formById(String id) => '$_v1/forms/$id/';

  /// `GET` [forms_metadata]
  static String formMetadataById(String id) => '$_v1/forms/$id/metadata/';

  /// `GET` [forms_rules_read] · `POST` [forms_rules_create] · `PUT` [forms_rules_update] · `DELETE` [forms_rules_delete]
  static String formRules(String formId) => '$_v1/forms/$formId/rules/';

  /// `GET` [forms_rules_read] · `PUT` [forms_rules_update] · `DELETE` [forms_rules_delete]
  static String formRuleById(String formId, String ruleId) =>
      '$_v1/forms/$formId/rules/$ruleId/';

  /// `POST` add section to a form
  static String formSections(String formId) => '$_v1/forms/$formId/section/';

  // ─── Project forms (operative / technician) ───────────────────────────────

  /// `GET` project forms for a project — `GET /project-forms/?project_id=`.
  static const String projectForms = '$_v1/project-forms/';

  /// `GET` project form template linked to a project (`project_form_id`).
  static String projectFormById(String id) => '$_v1/project-forms/$id/';

  /// `GET` operative form layout — `GET /project-forms/{id}/metadata/`.
  static String projectFormMetadataById(String id) =>
      '$_v1/project-forms/$id/metadata/';

  /// `GET` project form validation rules.
  static String projectFormRules(String formId) =>
      '$_v1/project-forms/$formId/rules/';

  /// `GET` [qr_codes_list] · `POST` [qr_codes_create]
  static const String qrCodes = '$_v1/qr-codes/';

  /// `POST` [qr_codes_generate]
  static const String qrCodesGenerate = '$_v1/qr-codes/generate/';

  /// `GET` [qr_codes_read] · `PUT` [qr_codes_update] · `PATCH` [qr_codes_partial_update] · `DELETE` [qr_codes_delete]
  static String qrCodeById(int id) => '$_v1/qr-codes/$id/';

  /// `GET` public job details for a QR code value (e.g. `QR-10001`).
  static String qrCodeDetailsByCode(String qrCode) =>
      '$_v1/qr-codes/${Uri.encodeComponent(qrCode)}/details/';

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

  /// `GET` [user-profile_read] · `PATCH` [user-profile_partial_update]
  static String userProfileById(String id) => '$_v1/user-profile/$id/';

  // ─── Notifications ────────────────────────────────────────────────────────

  /// `GET` [notifications_list] (`?type=unread` · `?cursor=`)
  static const String notifications = '$_v1/notifications/';

  /// `GET` unread badge count
  static const String notificationsUnreadCount =
      '$_v1/notifications/unread-count/';

  /// `PATCH` mark a single notification as read
  static String notificationMarkRead(String id) =>
      '$_v1/notifications/$id/mark-read/';

  // ─── Material requests / dispatch / returns ───────────────────────────────

  /// `GET` · `POST` material requests (`?job=` · `?worker=` · `?status=`)
  static const String materialRequests = '$_v1/material-requests/';

  /// `GET` · `PUT` · `PATCH` · `DELETE` material request by id
  static String materialRequestById(String id) => '$_v1/material-requests/$id/';

  /// `GET` · `POST` dispatches (`?job=` · `?worker=`)
  static const String dispatches = '$_v1/dispatch/';

  /// `GET` · `PUT` · `PATCH` · `DELETE` dispatch by id
  static String dispatchById(String id) => '$_v1/dispatch/$id/';

  /// `GET` · `POST` return requests (`?job=` · `?worker=`)
  static const String returnRequests = '$_v1/return-request/';

  /// `GET` · `PUT` · `PATCH` · `DELETE` return request by id
  static String returnRequestById(String id) => '$_v1/return-request/$id/';

  // ─── Integrations (Zoho Inventory) ───────────────────────────────────────

  /// Start Zoho Inventory OAuth — returns `authorization_url` and `connection_id`.
  static const String zohoConnect = '$_v1/integrations/zoho/connect/';
}
