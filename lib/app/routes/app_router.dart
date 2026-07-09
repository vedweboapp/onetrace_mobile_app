import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/app/routes/route_observers.dart';
import 'package:red5/core/auth/auth_redirect_notifier.dart';
import 'package:red5/core/auth/auth_session.dart';
import 'package:red5/core/auth/user_role_navigation.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/notifications/presentation/notifications_page.dart';
import 'package:red5/core/widgets/app_navigator_key.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/dashboard/presentation/views/create_project_page.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/drawing_canvas_page.dart';
import 'package:red5/features/dashboard/presentation/views/add_job_page.dart';
import 'package:red5/features/dashboard/presentation/views/job_details_page.dart';
import 'package:red5/features/dashboard/presentation/views/project_details_page.dart';
import 'package:red5/features/dashboard/presentation/views/project_level_jobs_page.dart';
import 'package:red5/features/dashboard/presentation/views/qr_codes_page.dart';
import 'package:red5/features/dashboard/presentation/views/quote_composite_items_screen.dart';
import 'package:red5/features/dashboard/presentation/views/upload_drawing_page.dart';
import 'package:red5/features/dashboard/presentation/views/quote_details_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/company_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/integration_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/module_metadata_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/change_password_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/password_updated_page.dart';
import 'package:red5/employee_role/presentation/employee_personal_profile_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/job_status_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/pin_status_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/installation_type_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/project_type_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/privacy_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/invite_user_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/tags_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/zoho_integration_finish_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/form_metadata_detail_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/forms_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/module_field_options_page.dart';
import 'package:red5/features/clients/data/client_models.dart';
import 'package:red5/features/clients/presentation/views/add_client_page.dart';
import 'package:red5/features/clients/presentation/views/client_detail_page.dart';
import 'package:red5/features/contacts/presentation/views/add_contact_page.dart';
import 'package:red5/features/contacts/presentation/views/contact_detail_page.dart';
import 'package:red5/features/groups/presentation/views/add_group_page.dart';
import 'package:red5/features/groups/presentation/views/group_detail_page.dart';
import 'package:red5/features/items/data/item_models.dart';
import 'package:red5/features/composite_items/presentation/view/add_composite_item_page.dart';
import 'package:red5/features/composite_items/presentation/view/composite_item_details_page.dart';
import 'package:red5/features/items/presentation/views/add_item_page.dart';
import 'package:red5/features/items/presentation/views/item_detail_page.dart';
import 'package:red5/features/dashboard/presentation/views/add_invoice_page.dart';
import 'package:red5/features/dashboard/presentation/views/add_purchase_order_page.dart';
import 'package:red5/features/dashboard/data/purchase_order_models.dart';
import 'package:red5/features/dashboard/presentation/views/add_bill_page.dart';
import 'package:red5/features/dashboard/presentation/views/bill_detail_page.dart';
import 'package:red5/features/dashboard/presentation/views/bill_preview_page.dart';
import 'package:red5/features/vendors/presentation/views/add_vendor_page.dart';
import 'package:red5/features/vendors/presentation/views/vendor_detail_page.dart';
import 'package:red5/features/dashboard/data/report_chart_config.dart';
import 'package:red5/features/dispatch/presentation/views/create_dispatch_page.dart';
import 'package:red5/features/dispatch/presentation/views/dispatch_detail_page.dart';
import 'package:red5/features/material_requests/presentation/views/create_material_request_page.dart';
import 'package:red5/features/material_requests/presentation/views/material_request_detail_page.dart';
import 'package:red5/features/dashboard/presentation/views/report_configure_page.dart';
import 'package:red5/features/dashboard/presentation/views/widgets/create_new_report_dialog.dart';
import 'package:red5/features/dashboard/presentation/views/report_summary_page.dart';
import 'package:red5/features/dashboard/presentation/views/report_create_chart_page.dart';
import 'package:red5/features/dashboard/presentation/views/purchase_order_detail_page.dart';
import 'package:red5/features/dashboard/presentation/views/purchase_order_preview_page.dart';
import 'package:red5/features/dashboard/presentation/views/invoice_detail_page.dart';
import 'package:red5/features/dashboard/presentation/views/invoice_preview_page.dart';
import 'package:red5/features/quotations/presentation/views/add_quotation_page.dart';
import 'package:red5/features/quotations/presentation/views/quotation_detail_page.dart';
import 'package:red5/features/login/presentation/views/forgot_password_page.dart';
import 'package:red5/features/login/presentation/views/login_page.dart';
import 'package:red5/features/login/presentation/views/otp_verify_page.dart';
import 'package:red5/features/login/presentation/views/reset_password_page.dart';
import 'package:red5/features/quote/presentation/views/quote_project_page.dart';
import 'package:red5/features/sites/presentation/views/add_site_page.dart';
import 'package:red5/features/sites/presentation/views/site_detail_page.dart';
import 'package:red5/features/splash/presentation/views/splash_page.dart';
import 'package:red5/employee_role/data/role_session.dart';
import 'package:red5/employee_role/employee_home/employee_home_page.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/jobs/presentation/employee_checklist_pdf_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_confirmation_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_details_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_form_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_safety_verification_page.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_sheet.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_sheet_detail_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_sheet_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_jobs_page.dart';
import 'package:red5/employee_role/jobs/presentation/operative_job_site_listings_page.dart';
import 'package:red5/employee_role/projects/presentation/operative_site_route_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_qr_scan_page.dart';
import 'package:red5/employee_role/reports/data/employee_reports_data.dart';
import 'package:red5/employee_role/reports/presentation/employee_report_product_detail_page.dart';
import 'package:red5/employee_role/sites/presentation/employee_site_detail_page.dart';
import 'package:red5/employee_role/material_requests/presentation/employee_material_requests_page.dart';
import 'package:red5/employee_role/sites/presentation/employee_sites_page.dart';
import 'package:red5/employee_role/reports/presentation/employee_reports_page.dart';
import 'package:red5/employee_role/projects/presentation/employee_project_details_page.dart';
import 'package:red5/employee_role/projects/presentation/project_map_page.dart';

/// Resolves `groups` from route [extra]: JSON list or in-memory [QuoteCompositeItemGroup] list.
List<QuoteCompositeItemGroup> _compositeGroupsFromExtra(
  dynamic raw,
  List<QuoteCompositeItemGroup> fallback,
) {
  if (raw is! List || raw.isEmpty) return fallback;
  if (raw.first is QuoteCompositeItemGroup) {
    return List<QuoteCompositeItemGroup>.from(
      raw.cast<QuoteCompositeItemGroup>(),
    );
  }
  final parsed = compositeGroupsFromJson(raw);
  return parsed.isNotEmpty ? parsed : fallback;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = sl<AuthRedirectNotifier>();
  // Splash first; static preview (dart-define) only switches quote API, not entry route.
  return GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: SplashPage.path,
    refreshListenable: authRefresh,
    observers: <NavigatorObserver>[appRouteObserver],
    redirect: (context, state) {
      final storage = sl<LocalStorage>();
      final access = storage
          .getString(LocalStorageKeys.authAccessToken)
          ?.trim();
      final isLoggedIn = AuthSession.isJwtValid(access);

      final location = state.matchedLocation.trim();
      final isSplash = location == SplashPage.path;
      final isLoginFlow = location.startsWith('/login');
      final roleHomePath = RoleSession.homePathForStoredRole(storage);

      // Always allow splash + login flow routes.
      if (isSplash || isLoginFlow) {
        if (isLoggedIn && isLoginFlow) {
          return roleHomePath;
        }
        return null;
      }

      // Block all other routes when not authenticated.
      if (!isLoggedIn) return LoginPage.path;

      final appShell = RoleSession.readAppShell(storage);
      if (appShell == AppShell.admin &&
          location.startsWith(TechnicianHomePage.path)) {
        return DashboardPage.homePath;
      }
      if (appShell == AppShell.employee &&
          (location == DashboardPage.path ||
              location == DashboardPage.homePath)) {
        return roleHomePath;
      }

      // Canonical post-login URL is /home (same shell as /dashboard).
      if (isLoggedIn && location == DashboardPage.path) {
        return roleHomePath;
      }
      if (isLoggedIn &&
          location == DashboardPage.homePath &&
          roleHomePath != DashboardPage.homePath) {
        return roleHomePath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: SplashPage.path,
        name: SplashPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const SplashPage(),
          beginOffset: const Offset(0, 0.06),
        ),
      ),
      GoRoute(
        path: LoginPage.path,
        name: LoginPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const LoginPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: ForgotPasswordPage.path,
        name: ForgotPasswordPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const ForgotPasswordPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: OtpVerifyPage.path,
        name: OtpVerifyPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: otpVerifyPageBuilder(context, state),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: ResetPasswordPage.path,
        name: ResetPasswordPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: resetPasswordPageBuilder(context, state),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: ModuleFieldOptionsPage.path,
        name: ModuleFieldOptionsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const ModuleFieldOptionsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: DashboardPage.path,
        name: DashboardPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const DashboardPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: DashboardPage.homePath,
        name: DashboardPage.homeName,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const DashboardPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: QrCodesPage.path,
        name: QrCodesPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const QrCodesPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: TechnicianHomePage.path,
        name: TechnicianHomePage.name,
        pageBuilder: (context, state) {
          final tab = EmployeeShellTab.fromExtra(state.extra);
          return _animatedPage(
            state: state,
            child: TechnicianHomePage(initialNavPageIndex: tab.navIndex),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: NotificationsPage.path,
        name: NotificationsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const NotificationsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: EmployeeQrScanPage.path,
        name: EmployeeQrScanPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const EmployeeQrScanPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: EmployeePersonalProfilePage.path,
        name: EmployeePersonalProfilePage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const EmployeePersonalProfilePage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: EmployeeTechnicianSettingsRoutes.privacy,
        name: 'technician-privacy',
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const PrivacySettingsPage(useTechnicianSettingsNav: true),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: EmployeeProjectMapPage.path,
        name: EmployeeProjectMapPage.name,
        pageBuilder: (context, state) {
          var projectName = 'Project';
          var activeSites = 0;
          int? projectId;
          final extra = state.extra;
          if (extra is Map) {
            final m = Map<String, dynamic>.from(extra);
            final rawProjectId = m['projectId'];
            if (rawProjectId is int) {
              projectId = rawProjectId;
            } else if (rawProjectId != null) {
              projectId = int.tryParse(rawProjectId.toString().trim());
            }
            final rawProjectName = m['projectName'];
            if (rawProjectName is String && rawProjectName.trim().isNotEmpty) {
              projectName = rawProjectName.trim();
            }
            final rawActiveSites = m['activeSites'];
            if (rawActiveSites is int) {
              activeSites = rawActiveSites;
            } else if (rawActiveSites != null) {
              activeSites =
                  int.tryParse(rawActiveSites.toString().trim()) ?? activeSites;
            }
          }
          return _animatedPage(
            state: state,
            child: EmployeeProjectMapPage(
              projectId: projectId,
              projectName: projectName,
              activeSites: activeSites,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: EmployeeProjectDetailsPage.path,
        name: EmployeeProjectDetailsPage.name,
        pageBuilder: (context, state) {
          String? projectName;
          int? projectId;
          final extra = state.extra;
          if (extra is Map) {
            final map = Map<String, dynamic>.from(extra);
            final rawProjectName = map['projectName'];
            if (rawProjectName is String && rawProjectName.trim().isNotEmpty) {
              projectName = rawProjectName.trim();
            }
            final rawProjectId = map['projectId'];
            if (rawProjectId is int) {
              projectId = rawProjectId;
            } else if (rawProjectId != null) {
              projectId = int.tryParse(rawProjectId.toString().trim());
            }
          }
          return _animatedPage(
            state: state,
            child: EmployeeProjectDetailsPage(
              projectId: projectId,
              projectName: projectName,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: EmployeeJobDetailsPage.path,
        name: EmployeeJobDetailsPage.name,
        pageBuilder: (context, state) {
          int? jobId;
          final extra = state.extra;
          if (extra is Map) {
            final rawJobId = Map<String, dynamic>.from(extra)['jobId'];
            if (rawJobId is int) {
              jobId = rawJobId;
            } else if (rawJobId != null) {
              jobId = int.tryParse(rawJobId.toString().trim());
            }
          }
          return _animatedPage(
            state: state,
            child: EmployeeJobDetailsPage(jobId: jobId),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: OperativeJobSiteListingsPage.path,
        name: OperativeJobSiteListingsPage.name,
        pageBuilder: (context, state) {
          final page = OperativeJobSiteListingsPage.fromExtra(state.extra);
          return _animatedPage(
            state: state,
            child: page ?? const OperativeJobSiteListingsPage(jobId: 0),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: OperativeSiteRoutePage.path,
        name: OperativeSiteRoutePage.name,
        pageBuilder: (context, state) {
          final page = OperativeSiteRoutePage.fromExtra(state.extra);
          return _animatedPage(
            state: state,
            child: page ??
                const OperativeSiteRoutePage(
                  title: 'Site location',
                ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: EmployeeJobSafetyVerificationPage.path,
        name: EmployeeJobSafetyVerificationPage.name,
        pageBuilder: (context, state) {
          int? jobId;
          final extra = state.extra;
          if (extra is Map) {
            final rawJobId = Map<String, dynamic>.from(extra)['jobId'];
            if (rawJobId is int) {
              jobId = rawJobId;
            } else if (rawJobId != null) {
              jobId = int.tryParse(rawJobId.toString().trim());
            }
          }
          return _animatedPage(
            state: state,
            child: EmployeeJobSafetyVerificationPage(jobId: jobId),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: EmployeeJobFormPage.path,
        name: EmployeeJobFormPage.name,
        pageBuilder: (context, state) {
          int? formId;
          int? jobId;
          int? jobFormId;
          int? submissionId;
          final extra = state.extra;
          if (extra is Map) {
            final map = Map<String, dynamic>.from(extra);
            final rawFormId = map['formId'];
            if (rawFormId is int) {
              formId = rawFormId;
            } else if (rawFormId != null) {
              formId = int.tryParse(rawFormId.toString().trim());
            }
            final rawJobId = map['jobId'];
            if (rawJobId is int) {
              jobId = rawJobId;
            } else if (rawJobId != null) {
              jobId = int.tryParse(rawJobId.toString().trim());
            }
            final rawJobFormId = map['jobFormId'];
            if (rawJobFormId is int) {
              jobFormId = rawJobFormId;
            } else if (rawJobFormId != null) {
              jobFormId = int.tryParse(rawJobFormId.toString().trim());
            }
            final rawSubmissionId = map['submissionId'];
            if (rawSubmissionId is int) {
              submissionId = rawSubmissionId;
            } else if (rawSubmissionId != null) {
              submissionId = int.tryParse(rawSubmissionId.toString().trim());
            }
          }
          return _animatedPage(
            state: state,
            child: EmployeeJobFormPage(
              formId: formId ?? 0,
              jobId: jobId,
              jobFormId: jobFormId,
              submissionId: submissionId,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: EmployeeChecklistPdfPage.path,
        name: EmployeeChecklistPdfPage.name,
        pageBuilder: (context, state) {
          var title = 'Checklist';
          var fileUrl = '';
          final extra = state.extra;
          if (extra is Map) {
            final map = Map<String, dynamic>.from(extra);
            final rawTitle = map['title'];
            if (rawTitle is String && rawTitle.trim().isNotEmpty) {
              title = rawTitle.trim();
            }
            final rawFileUrl = map['fileUrl'];
            if (rawFileUrl is String && rawFileUrl.trim().isNotEmpty) {
              fileUrl = rawFileUrl.trim();
            }
          }
          return _animatedPage(
            state: state,
            child: EmployeeChecklistPdfPage(
              title: title,
              fileUrl: fileUrl,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: EmployeeJobConfirmationPage.path,
        name: EmployeeJobConfirmationPage.name,
        pageBuilder: (context, state) {
          String? jobTitle;
          int? jobId;
          final extra = state.extra;
          if (extra is Map) {
            final map = Map<String, dynamic>.from(extra);
            final rawJobTitle = map['jobTitle'];
            if (rawJobTitle is String && rawJobTitle.trim().isNotEmpty) {
              jobTitle = rawJobTitle.trim();
            }
            final rawJobId = map['jobId'];
            if (rawJobId is int) {
              jobId = rawJobId;
            } else if (rawJobId is String) {
              jobId = int.tryParse(rawJobId);
            }
          }
          return _animatedPage(
            state: state,
            child: EmployeeJobConfirmationPage(jobId: jobId, jobTitle: jobTitle),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: EmployeeJobsPage.path,
        name: EmployeeJobsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const TechnicianHomePage(initialNavPageIndex: 1),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: EmployeeJobSheetPage.path,
        name: EmployeeJobSheetPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const EmployeeJobSheetPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: EmployeeJobSheetDetailPage.path,
        name: EmployeeJobSheetDetailPage.name,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final job = extra is EmployeeJobSummary
              ? extra
              : EmployeeJobSheetData.jobs.first;
          return _animatedPage(
            state: state,
            child: EmployeeJobSheetDetailPage(job: job),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: EmployeeReportsPage.path,
        name: EmployeeReportsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const EmployeeReportsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: EmployeeReportProductDetailPage.path,
        name: EmployeeReportProductDetailPage.name,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final product = extra is EmployeeReportProduct
              ? extra
              : EmployeeReportsData.products.first;
          return _animatedPage(
            state: state,
            child: EmployeeReportProductDetailPage(product: product),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: EmployeeSitesPage.path,
        name: EmployeeSitesPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const EmployeeSitesPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: EmployeeMaterialRequestsPage.path,
        name: EmployeeMaterialRequestsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const EmployeeMaterialRequestsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: EmployeeSiteDetailPage.path,
        name: EmployeeSiteDetailPage.name,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final site = extra is EmployeeReportSite
              ? extra
              : EmployeeReportsData.sites.first;
          return _animatedPage(
            state: state,
            child: EmployeeSiteDetailPage(site: site),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),

      GoRoute(
        path: CreateProjectPage.path,
        name: CreateProjectPage.name,
        pageBuilder: (context, state) {
          int? clientId;
          String? clientName;
          final extra = state.extra;
          if (extra is Map) {
            final m = Map<String, dynamic>.from(extra);
            final rawClientId = m['clientId'];
            if (rawClientId is int) {
              clientId = rawClientId;
            } else if (rawClientId != null) {
              clientId = int.tryParse(rawClientId.toString().trim());
            }
            final rawClientName = m['clientName'];
            if (rawClientName is String && rawClientName.trim().isNotEmpty) {
              clientName = rawClientName.trim();
            }
          }
          return _animatedPage(
            state: state,
            child: CreateProjectPage(
              preselectedClientId: clientId,
              preselectedClientName: clientName,
            ),
            beginOffset: const Offset(0, 0.08),
          );
        },
      ),
      GoRoute(
        path: AddClientPage.path,
        name: AddClientPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddClientPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: '${ClientDetailPage.pathPrefix}/:clientId/edit',
        name: AddClientPage.editName,
        pageBuilder: (context, state) {
          final clientId = Uri.decodeComponent(
            (state.pathParameters['clientId'] ?? '').trim(),
          );
          final extra = state.extra;
          final prefill = extra is ClientModel ? extra : null;
          return _animatedPage(
            state: state,
            child: AddClientPage(editClientId: clientId, existing: prefill),
            beginOffset: const Offset(0, 0.08),
          );
        },
      ),
      GoRoute(
        path: AddSitePage.path,
        name: AddSitePage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddSitePage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: '${SiteDetailPage.pathPrefix}/:siteId',
        name: SiteDetailPage.name,
        pageBuilder: (context, state) {
          final siteId = (state.pathParameters['siteId'] ?? '').trim();
          return _animatedPage(
            state: state,
            child: SiteDetailPage(siteId: siteId),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${ClientDetailPage.pathPrefix}/:clientId',
        name: ClientDetailPage.name,
        pageBuilder: (context, state) {
          final clientId = (state.pathParameters['clientId'] ?? '').trim();
          return _animatedPage(
            state: state,
            child: ClientDetailPage(clientId: clientId),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: AddContactPage.path,
        name: AddContactPage.name,
        pageBuilder: (context, state) {
          String? presetClientId;
          final extra = state.extra;
          if (extra is Map) {
            final m = Map<String, dynamic>.from(extra);
            final raw = m['presetClientId'];
            if (raw is String && raw.trim().isNotEmpty) {
              presetClientId = raw.trim();
            }
          }
          return _animatedPage(
            state: state,
            child: AddContactPage(presetClientId: presetClientId),
            beginOffset: const Offset(0, 0.08),
          );
        },
      ),
      GoRoute(
        path: '${ContactDetailPage.pathPrefix}/:contactId',
        name: ContactDetailPage.name,
        pageBuilder: (context, state) {
          final contactId = (state.pathParameters['contactId'] ?? '').trim();
          return _animatedPage(
            state: state,
            child: ContactDetailPage(contactId: contactId),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: AddGroupPage.path,
        name: AddGroupPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddGroupPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: '${GroupDetailPage.pathPrefix}/:groupId',
        name: GroupDetailPage.name,
        pageBuilder: (context, state) {
          final groupId = (state.pathParameters['groupId'] ?? '').trim();
          return _animatedPage(
            state: state,
            child: GroupDetailPage(groupId: groupId),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: AddItemPage.path,
        name: AddItemPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddItemPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: AddCompositeItemPage.path,
        name: AddCompositeItemPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddCompositeItemPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: AddQuotationPage.path,
        name: AddQuotationPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddQuotationPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: AddInvoicePage.path,
        name: AddInvoicePage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddInvoicePage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: AddJobPage.standalonePath,
        name: AddJobPage.standaloneName,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddJobPage(standalone: true),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: AddPurchaseOrderPage.path,
        name: AddPurchaseOrderPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddPurchaseOrderPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: CreateMaterialRequestPage.path,
        name: CreateMaterialRequestPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const CreateMaterialRequestPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: '${MaterialRequestDetailPage.pathPrefix}/:materialRequestId',
        name: MaterialRequestDetailPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['materialRequestId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: MaterialRequestDetailPage(materialRequestId: id),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: CreateDispatchPage.path,
        name: CreateDispatchPage.name,
        pageBuilder: (context, state) {
          final extra = state.extra;
          CreateDispatchRouteExtra? routeExtra;
          if (extra is CreateDispatchRouteExtra) {
            routeExtra = extra;
          }
          return _animatedPage(
            state: state,
            child: CreateDispatchPage(
              initialMaterialRequestId: routeExtra?.materialRequestId,
              initialDispatchTo: routeExtra?.dispatchTo,
            ),
            beginOffset: const Offset(0, 0.08),
          );
        },
      ),
      GoRoute(
        path: '${DispatchDetailPage.pathPrefix}/:dispatchId',
        name: DispatchDetailPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['dispatchId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: DispatchDetailPage(dispatchId: id),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: AddBillPage.path,
        name: AddBillPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddBillPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: '${BillDetailPage.pathPrefix}/:billId/preview',
        name: BillPreviewPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['billId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: BillPreviewPage(billId: id),
            beginOffset: const Offset(0, 0.08),
          );
        },
      ),
      GoRoute(
        path: '${BillDetailPage.pathPrefix}/:billId',
        name: BillDetailPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['billId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: BillDetailPage(billId: id),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${ReportSummaryPage.pathPrefix}/:reportId',
        name: ReportSummaryPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['reportId'] ?? '').trim(),
          );
          final extra = state.extra;
          ReportSummaryRouteExtra? routeExtra;
          if (extra is ReportSummaryRouteExtra) {
            routeExtra = extra;
          }
          return _animatedPage(
            state: state,
            child: ReportSummaryPage(
              reportId: id,
              primaryModule: routeExtra?.primaryModule,
              initialColumnKeys: routeExtra?.columnKeys,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
        routes: [
          GoRoute(
            path: 'configure',
            name: ReportConfigurePage.name,
            pageBuilder: (context, state) {
              final id = Uri.decodeComponent(
                (state.pathParameters['reportId'] ?? '').trim(),
              );
              final extra = state.extra;
              if (extra is! ReportConfigureRouteExtra) {
                return _animatedPage(
                  state: state,
                  child: ReportConfigurePage(
                    reportId: id,
                    primaryModule: ReportPrimaryModule.leads,
                  ),
                  beginOffset: const Offset(0.08, 0),
                );
              }
              return _animatedPage(
                state: state,
                child: ReportConfigurePage(
                  reportId: id,
                  primaryModule: extra.primaryModule,
                  initialState: extra.initialState,
                  replaceOnGenerate: extra.replaceOnGenerate,
                ),
                beginOffset: const Offset(0.08, 0),
              );
            },
          ),
          GoRoute(
            path: 'create-chart',
            name: ReportCreateChartPage.name,
            pageBuilder: (context, state) {
              final id = Uri.decodeComponent(
                (state.pathParameters['reportId'] ?? '').trim(),
              );
              final extra = state.extra;
              return _animatedPage(
                state: state,
                child: ReportCreateChartPage(
                  reportId: id,
                  initialConfig:
                      extra is ReportChartConfig ? extra : null,
                ),
                beginOffset: const Offset(0, 0.08),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AddVendorPage.path,
        name: AddVendorPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddVendorPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: '${VendorDetailPage.pathPrefix}/:vendorId',
        name: VendorDetailPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['vendorId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: VendorDetailPage(vendorId: id),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${PurchaseOrderDetailPage.pathPrefix}/:purchaseOrderId/edit',
        name: AddPurchaseOrderPage.editName,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['purchaseOrderId'] ?? '').trim(),
          );
          final extra = state.extra;
          final prefill = extra is PurchaseOrderDetail ? extra : null;
          return _animatedPage(
            state: state,
            child: AddPurchaseOrderPage(
              editPurchaseOrderId: id,
              existing: prefill,
            ),
            beginOffset: const Offset(0, 0.08),
          );
        },
      ),
      GoRoute(
        path: '${PurchaseOrderDetailPage.pathPrefix}/:purchaseOrderId/preview',
        name: PurchaseOrderPreviewPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['purchaseOrderId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: PurchaseOrderPreviewPage(purchaseOrderId: id),
            beginOffset: const Offset(0, 0.08),
          );
        },
      ),
      GoRoute(
        path: '${PurchaseOrderDetailPage.pathPrefix}/:purchaseOrderId',
        name: PurchaseOrderDetailPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['purchaseOrderId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: PurchaseOrderDetailPage(purchaseOrderId: id),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${InvoiceDetailPage.pathPrefix}/:invoiceId/preview',
        name: InvoicePreviewPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['invoiceId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: InvoicePreviewPage(invoiceId: id),
            beginOffset: const Offset(0, 0.08),
          );
        },
      ),
      GoRoute(
        path: '${InvoiceDetailPage.pathPrefix}/:invoiceId',
        name: InvoiceDetailPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['invoiceId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: InvoiceDetailPage(invoiceId: id),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${QuotationDetailPage.pathPrefix}/:quotationId',
        name: QuotationDetailPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(
            (state.pathParameters['quotationId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: QuotationDetailPage(quotationId: id),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${ItemDetailPage.pathPrefix}/:itemId/edit',
        name: AddItemPage.editName,
        pageBuilder: (context, state) {
          final itemId = (state.pathParameters['itemId'] ?? '').trim();
          final extra = state.extra;
          final prefill = extra is ItemDetailModel ? extra : null;
          return _animatedPage(
            state: state,
            child: AddItemPage(editItemId: itemId, prefill: prefill),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${ItemDetailPage.pathPrefix}/:itemId/edit-composite',
        name: AddCompositeItemPage.editName,
        pageBuilder: (context, state) {
          final itemId = (state.pathParameters['itemId'] ?? '').trim();
          final extra = state.extra;
          final prefill = extra is ItemDetailModel ? extra : null;
          return _animatedPage(
            state: state,
            child: AddCompositeItemPage(editItemId: itemId, prefill: prefill),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${CompositeItemDetailsPage.pathPrefix}/:itemId',
        name: CompositeItemDetailsPage.name,
        pageBuilder: (context, state) {
          final itemId = Uri.decodeComponent(
            (state.pathParameters['itemId'] ?? '').trim(),
          );
          return _animatedPage(
            state: state,
            child: CompositeItemDetailsPage(itemId: itemId),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${ItemDetailPage.pathPrefix}/:itemId',
        name: ItemDetailPage.name,
        pageBuilder: (context, state) {
          final itemId = (state.pathParameters['itemId'] ?? '').trim();
          return _animatedPage(
            state: state,
            child: ItemDetailPage(itemId: itemId),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: DrawingCanvasPage.path,
        name: DrawingCanvasPage.name,
        pageBuilder: (context, state) {
          var title = 'Ground Floor Plan';
          String? filePath;
          String? remoteDrawingUrl;
          String? levelName;
          String? projectName;
          String? projectId;
          String? levelId;
          var viewOnly = false;
          List<Map<String, dynamic>> embeddedLevelPlots = const [];
          final extra = state.extra;
          if (extra is Map) {
            final map = Map<String, dynamic>.from(extra);
            final rawTitle = map['title'];
            if (rawTitle is String && rawTitle.trim().isNotEmpty) {
              title = rawTitle.trim();
            }
            final rawFilePath = map['filePath'];
            if (rawFilePath is String && rawFilePath.trim().isNotEmpty) {
              filePath = rawFilePath.trim();
            }
            final rawDrawingUrl = map['drawingUrl'] ?? map['remoteDrawingUrl'];
            if (rawDrawingUrl is String && rawDrawingUrl.trim().isNotEmpty) {
              remoteDrawingUrl = rawDrawingUrl.trim();
            }
            final rawLevelName = map['levelName'];
            if (rawLevelName is String && rawLevelName.trim().isNotEmpty) {
              levelName = rawLevelName.trim();
            }
            final rawProjectName = map['projectName'];
            if (rawProjectName is String && rawProjectName.trim().isNotEmpty) {
              projectName = rawProjectName.trim();
            }
            final rawProjectId = map['projectId'];
            if (rawProjectId is String && rawProjectId.trim().isNotEmpty) {
              projectId = rawProjectId.trim();
            }
            final rawLevelId = map['levelId'];
            if (rawLevelId is String && rawLevelId.trim().isNotEmpty) {
              levelId = rawLevelId.trim();
            }
            final rawViewOnly = map['viewOnly'];
            if (rawViewOnly == true || rawViewOnly?.toString() == 'true') {
              viewOnly = true;
            }
            final rawPlots = map['embeddedLevelPlots'];
            if (rawPlots is List) {
              embeddedLevelPlots = rawPlots
                  .whereType<Map>()
                  .map((plot) => Map<String, dynamic>.from(plot))
                  .toList(growable: false);
            }
          }
          return _animatedPage(
            state: state,
            child: DrawingCanvasPage(
              title: title,
              filePath: filePath,
              remoteDrawingUrl: remoteDrawingUrl,
              levelName: levelName,
              projectName: projectName,
              projectId: projectId,
              levelId: levelId,
              embeddedLevelPlots: embeddedLevelPlots,
              viewOnly: viewOnly,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${ProjectDetailsPage.pathPrefix}/:projectId',
        name: ProjectDetailsPage.name,
        pageBuilder: (context, state) {
          final extra = state.extra;
          QuoteSummary? summary;
          var initialTabIndex = 0;
          String? jobsRefreshToken;
          if (extra is Map) {
            final map = Map<String, dynamic>.from(extra);
            summary = QuoteSummary.fromMap(map);
            final rawTab = map['initialTabIndex'];
            if (rawTab is int) {
              initialTabIndex = rawTab;
            } else if (rawTab is String) {
              initialTabIndex = int.tryParse(rawTab.trim()) ?? 0;
            }
            final rawRefresh = map['jobsRefreshToken'];
            if (rawRefresh != null) {
              final text = rawRefresh.toString().trim();
              if (text.isNotEmpty) jobsRefreshToken = text;
            }
          } else if (extra is QuoteSummary) {
            summary = extra;
          }
          final id = state.pathParameters['projectId'] ?? '';
          summary ??= QuoteSummary(
            id: id,
            quoteName: 'Untitled Project',
            quoteNumber: '—',
          );
          return _animatedPage(
            state: state,
            child: ProjectDetailsPage(
              project: summary,
              initialTabIndex: initialTabIndex,
              jobsRefreshToken: jobsRefreshToken,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${ProjectDetailsPage.pathPrefix}/:projectId/add-job',
        name: AddJobPage.name,
        pageBuilder: (context, state) {
          final projectId = state.pathParameters['projectId'] ?? '';
          var projectName = '';
          var clientName = '';
          final extra = state.extra;
          if (extra is Map) {
            final m = Map<String, dynamic>.from(extra);
            projectName = (m['projectName'] as String?)?.trim() ?? '';
            clientName = (m['clientName'] as String?)?.trim() ?? '';
          }
          return _animatedPage(
            state: state,
            child: AddJobPage(
              projectId: projectId,
              initialProjectName: projectName,
              initialClientName: clientName,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${ProjectDetailsPage.pathPrefix}/:projectId/level-jobs',
        name: ProjectLevelJobsPage.name,
        pageBuilder: (context, state) {
          final projectId = state.pathParameters['projectId'] ?? '';
          final extra = state.extra;
          final args = extra is ProjectLevelJobsArgs
              ? extra
              : const ProjectLevelJobsArgs(levelName: 'Level', plots: []);
          return _animatedPage(
            state: state,
            child: ProjectLevelJobsPage(
              projectId: projectId,
              args: args,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${ProjectDetailsPage.pathPrefix}/:projectId/jobs/:jobId/edit',
        name: AddJobPage.editJobName,
        pageBuilder: (context, state) {
          final projectId = state.pathParameters['projectId'] ?? '';
          final jobId = state.pathParameters['jobId'] ?? '';
          return _animatedPage(
            state: state,
            child: AddJobPage(
              projectId: projectId,
              editJobId: jobId,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: '${ProjectDetailsPage.pathPrefix}/:projectId/jobs/:jobId',
        name: JobDetailsPage.name,
        pageBuilder: (context, state) {
          final projectId = state.pathParameters['projectId'] ?? '';
          final routeJobId = state.pathParameters['jobId'] ?? '';
          var jobId = Uri.decodeComponent(routeJobId);
          var jobTitle = 'Job';
          var projectName = 'Project';
          var clientName = '--';
          var workerName = 'Assigned Worker';
          DateTime? startDate;
          DateTime? scheduleDate;
          var status = 'Active';
          double? latitude;
          double? longitude;
          final extra = state.extra;
          if (extra is Map) {
            final m = Map<String, dynamic>.from(extra);
            final rawJobId = m['jobId'];
            final rawJobTitle = m['jobTitle'];
            final rawProjectName = m['projectName'];
            final rawClientName = m['clientName'];
            final rawWorkerName = m['workerName'];
            final rawStartDate = m['startDate'];
            final rawScheduleDate = m['scheduleDate'];
            final rawStatus = m['status'];
            final rawLatitude = m['latitude'];
            final rawLongitude = m['longitude'];
            if (rawJobId is String && rawJobId.trim().isNotEmpty) {
              jobId = rawJobId.trim();
            }
            if (rawJobTitle is String && rawJobTitle.trim().isNotEmpty) {
              jobTitle = rawJobTitle.trim();
            }
            if (rawProjectName is String && rawProjectName.trim().isNotEmpty) {
              projectName = rawProjectName.trim();
            }
            if (rawClientName is String && rawClientName.trim().isNotEmpty) {
              clientName = rawClientName.trim();
            }
            if (rawWorkerName is String && rawWorkerName.trim().isNotEmpty) {
              workerName = rawWorkerName.trim();
            }
            if (rawStartDate is String && rawStartDate.trim().isNotEmpty) {
              startDate = DateTime.tryParse(rawStartDate.trim());
            }
            if (rawScheduleDate is String &&
                rawScheduleDate.trim().isNotEmpty) {
              scheduleDate = DateTime.tryParse(rawScheduleDate.trim());
            }
            if (rawStatus is String && rawStatus.trim().isNotEmpty) {
              status = rawStatus.trim();
            }
            if (rawLatitude is num) {
              latitude = rawLatitude.toDouble();
            } else if (rawLatitude is String) {
              latitude = double.tryParse(rawLatitude.trim());
            }
            if (rawLongitude is num) {
              longitude = rawLongitude.toDouble();
            } else if (rawLongitude is String) {
              longitude = double.tryParse(rawLongitude.trim());
            }
          }
          return _animatedPage(
            state: state,
            child: JobDetailsPage(
              projectId: projectId,
              jobId: jobId,
              jobTitle: jobTitle,
              projectName: projectName,
              clientName: clientName,
              workerName: workerName,
              startDate: startDate,
              scheduleDate: scheduleDate,
              status: status,
              latitude: latitude,
              longitude: longitude,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: UploadDrawingPage.path,
        name: UploadDrawingPage.name,
        pageBuilder: (context, state) {
          String projectId = '';
          final extra = state.extra;
          if (extra is Map) {
            final map = Map<String, dynamic>.from(extra);
            final rawId = map['projectId'];
            if (rawId is String && rawId.trim().isNotEmpty) {
              projectId = rawId.trim();
            }
          }
          return _animatedPage(
            state: state,
            child: UploadDrawingPage(projectId: projectId),
            beginOffset: const Offset(0, 0.08),
          );
        },
      ),
      GoRoute(
        path: QuoteCompositeItemGroupsPage.path,
        name: QuoteCompositeItemGroupsPage.name,
        pageBuilder: (context, state) {
          var quoteTitle = 'Preview';
          var groups = sampleCompositeItemGroupsForRouting();
          final extra = state.extra;
          if (extra is Map) {
            final m = Map<String, dynamic>.from(extra);
            final t = m['quoteTitle'];
            if (t is String && t.trim().isNotEmpty) {
              quoteTitle = t.trim();
            }
            final g = m['groups'];
            final resolved = _compositeGroupsFromExtra(g, groups);
            if (resolved.isNotEmpty) groups = resolved;
          }
          return _animatedPage(
            state: state,
            child: QuoteCompositeItemGroupsPage(
              quoteTitle: quoteTitle,
              groups: groups,
            ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: QuoteCompositeGroupItemsPage.path,
        name: QuoteCompositeGroupItemsPage.name,
        pageBuilder: (context, state) {
          final extra = state.extra;
          var quoteTitle = 'Quote';
          QuoteCompositeItemGroup? group;
          if (extra is Map) {
            final m = Map<String, dynamic>.from(extra);
            final t = m['quoteTitle'];
            if (t is String && t.trim().isNotEmpty) {
              quoteTitle = t.trim();
            }
            final raw = m['group'];
            if (raw is QuoteCompositeItemGroup) {
              group = raw;
            } else if (raw is Map) {
              group = QuoteCompositeItemGroup.fromJson(
                Map<String, dynamic>.from(raw),
              );
            }
          }
          return _animatedPage(
            state: state,
            child: group == null
                ? _MissingRouteExtraPage(
                    title: 'Composite items',
                    message: 'Open this screen from a composite group list.',
                    onBack: () => context.pop(),
                  )
                : QuoteCompositeGroupItemsPage(
                    quoteTitle: quoteTitle,
                    group: group,
                  ),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: QuoteProjectPage.path,
        name: QuoteProjectPage.name,
        pageBuilder: (context, state) {
          final extra = state.extra;
          String? initialBlock;
          String? initialProjectId;
          int? initialOrganizationId;
          int? initialClientId;
          String? initialProjectDescription;
          String? initialStartDate;
          String? initialEndDate;
          String? initialPdfUrl;
          String? initialPdfName;
          List<Map<String, dynamic>>? initialProducts;
          if (extra is String && extra.trim().isNotEmpty) {
            initialBlock = extra.trim();
          } else if (extra is Map) {
            final m = Map<String, dynamic>.from(extra);
            final b = m['initialBlockName'];
            final p = m['initialProjectId'];
            final org = m['initialOrganizationId'];
            final cli = m['initialClientId'];
            final desc = m['initialProjectDescription'];
            final sd = m['initialStartDate'];
            final ed = m['initialEndDate'];
            final u = m['initialPdfUrl'];
            final n = m['initialPdfName'];
            final pr = m['initialProducts'];
            if (b is String && b.trim().isNotEmpty) initialBlock = b.trim();
            if (p is String && p.trim().isNotEmpty) initialProjectId = p.trim();
            if (org is int) initialOrganizationId = org;
            if (org is String) initialOrganizationId = int.tryParse(org.trim());
            if (cli is int) initialClientId = cli;
            if (cli is String) initialClientId = int.tryParse(cli.trim());
            if (desc is String && desc.trim().isNotEmpty) {
              initialProjectDescription = desc.trim();
            }
            if (sd is String && sd.trim().isNotEmpty) {
              initialStartDate = sd.trim();
            }
            if (ed is String && ed.trim().isNotEmpty) {
              initialEndDate = ed.trim();
            }
            if (u is String && u.trim().isNotEmpty) initialPdfUrl = u.trim();
            if (n is String && n.trim().isNotEmpty) initialPdfName = n.trim();
            if (pr is List) {
              initialProducts = pr
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
          }
          return _animatedPage(
            state: state,
            child: QuoteProjectPage(
              initialBlockName: initialBlock,
              initialProjectId: initialProjectId,
              initialOrganizationId: initialOrganizationId,
              initialClientId: initialClientId,
              initialProjectDescription: initialProjectDescription,
              initialStartDate: initialStartDate,
              initialEndDate: initialEndDate,
              initialPdfUrl: initialPdfUrl,
              initialPdfName: initialPdfName,
              initialProducts: initialProducts,
            ),
            beginOffset: const Offset(0, 0.08),
          );
        },
      ),
      GoRoute(
        path: '${QuoteDetailsPage.pathPrefix}/:quoteId',
        name: QuoteDetailsPage.name,
        pageBuilder: (context, state) {
          final id = Uri.decodeComponent(state.pathParameters['quoteId']!);
          return _animatedPage(
            state: state,
            child: QuoteDetailsPage(quoteId: id),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: SettingsPage.path,
        name: SettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const SettingsPage(),
          beginOffset: const Offset(0, -0.1),
        ),
      ),
      GoRoute(
        path: PersonalProfilePage.path,
        name: PersonalProfilePage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const PersonalProfilePage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: UsersSettingsPage.path,
        name: UsersSettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const UsersSettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: InviteUserPage.path,
        name: InviteUserPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const InviteUserPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: CompanySettingsPage.path,
        name: CompanySettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const CompanySettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: MetadataSettingsPage.path,
        name: MetadataSettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const MetadataSettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: IntegrationSettingsPage.path,
        name: IntegrationSettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const IntegrationSettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: '${ZohoIntegrationFinishPage.pathPrefix}/:connectionId',
        name: ZohoIntegrationFinishPage.name,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['connectionId'] ?? '') ?? 0;
          return _animatedPage(
            state: state,
            child: ZohoIntegrationFinishPage(connectionId: id),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: ProjectsMetadataPage.path,
        name: ProjectsMetadataPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const ProjectsMetadataPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: QuotationsMetadataPage.path,
        name: QuotationsMetadataPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const QuotationsMetadataPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: FormsSettingsPage.path,
        name: FormsSettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const FormsSettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
        routes: [
          GoRoute(
            path: ':formId',
            name: FormMetadataDetailPage.name,
            pageBuilder: (context, state) {
              final formId =
                  int.tryParse(state.pathParameters['formId'] ?? '') ?? 0;
              return _animatedPage(
                state: state,
                child: FormMetadataDetailPage(formId: formId),
                beginOffset: const Offset(0.08, 0),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: PinStatusSettingsPage.path,
        name: PinStatusSettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const PinStatusSettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: JobStatusSettingsPage.path,
        name: JobStatusSettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const JobStatusSettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: ProjectTypeSettingsPage.path,
        name: ProjectTypeSettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const ProjectTypeSettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: InstallationTypeSettingsPage.path,
        name: InstallationTypeSettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const InstallationTypeSettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: TagsSettingsPage.path,
        name: TagsSettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const TagsSettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: PrivacySettingsPage.path,
        name: PrivacySettingsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const PrivacySettingsPage(),
          beginOffset: const Offset(0.08, 0),
        ),
      ),
      GoRoute(
        path: ChangePasswordPage.path,
        name: ChangePasswordPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const ChangePasswordPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
      GoRoute(
        path: PasswordUpdatedPage.path,
        name: PasswordUpdatedPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const PasswordUpdatedPage(),
          beginOffset: const Offset(0, 0.08),
        ),
      ),
    ],
  );
});

class _MissingRouteExtraPage extends StatelessWidget {
  const _MissingRouteExtraPage({
    required this.title,
    required this.message,
    required this.onBack,
  });

  final String title;
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onBack, child: const Text('Go back')),
            ],
          ),
        ),
      ),
    );
  }
}

CustomTransitionPage<void> _animatedPage({
  required GoRouterState state,
  required Widget child,
  required Offset beginOffset,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final slide = Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(fade);

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 550),
  );
}
