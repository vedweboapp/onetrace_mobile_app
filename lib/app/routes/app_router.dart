import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/app/routes/route_observers.dart';
import 'package:red5/core/auth/auth_redirect_notifier.dart';
import 'package:red5/core/auth/auth_session.dart';
import 'package:red5/core/di/injection.dart';
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
import 'package:red5/features/dashboard/presentation/views/settings/project_type_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/privacy_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/invite_user_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/tags_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/zoho_integration_page.dart';
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
import 'package:red5/features/dashboard/presentation/views/add_bill_page.dart';
import 'package:red5/features/dashboard/presentation/views/bill_detail_page.dart';
import 'package:red5/features/dashboard/presentation/views/bill_preview_page.dart';
import 'package:red5/features/vendors/presentation/views/add_vendor_page.dart';
import 'package:red5/features/vendors/presentation/views/vendor_detail_page.dart';
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
import 'package:red5/employee_role/jobs/presentation/employee_job_confirmation_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_details_page.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_sheet.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_sheet_detail_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_sheet_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_jobs_page.dart';
import 'package:red5/employee_role/reports/data/employee_reports_data.dart';
import 'package:red5/employee_role/reports/presentation/employee_report_product_detail_page.dart';
import 'package:red5/employee_role/sites/presentation/employee_site_detail_page.dart';
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
          return roleHomePath ?? DashboardPage.homePath;
        }
        return null;
      }

      // Block all other routes when not authenticated.
      if (!isLoggedIn) return LoginPage.path;

      // Canonical post-login URL is /home (same shell as /dashboard).
      if (isLoggedIn && location == DashboardPage.path) {
        return roleHomePath ?? DashboardPage.homePath;
      }
      if (isLoggedIn &&
          location == DashboardPage.homePath &&
          roleHomePath != null) {
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
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const TechnicianHomePage(),
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
          var projectName = 'Riverside Tower';
          var activeSites = 3;
          final extra = state.extra;
          if (extra is Map) {
            final m = Map<String, dynamic>.from(extra);
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
          final extra = state.extra;
          if (extra is Map) {
            final rawProjectName = Map<String, dynamic>.from(
              extra,
            )['projectName'];
            if (rawProjectName is String && rawProjectName.trim().isNotEmpty) {
              projectName = rawProjectName.trim();
            }
          }
          return _animatedPage(
            state: state,
            child: EmployeeProjectDetailsPage(projectName: projectName),
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
        path: EmployeeJobConfirmationPage.path,
        name: EmployeeJobConfirmationPage.name,
        pageBuilder: (context, state) {
          String? jobTitle;
          final extra = state.extra;
          if (extra is Map) {
            final rawJobTitle = Map<String, dynamic>.from(extra)['jobTitle'];
            if (rawJobTitle is String && rawJobTitle.trim().isNotEmpty) {
              jobTitle = rawJobTitle.trim();
            }
          }
          return _animatedPage(
            state: state,
            child: EmployeeJobConfirmationPage(jobTitle: jobTitle),
            beginOffset: const Offset(0.08, 0),
          );
        },
      ),
      GoRoute(
        path: EmployeeJobsPage.path,
        name: EmployeeJobsPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const EmployeeJobsPage(),
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
        path: AddPurchaseOrderPage.path,
        name: AddPurchaseOrderPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const AddPurchaseOrderPage(),
          beginOffset: const Offset(0, 0.08),
        ),
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
          return _animatedPage(
            state: state,
            child: ReportSummaryPage(reportId: id),
            beginOffset: const Offset(0.08, 0),
          );
        },
        routes: [
          GoRoute(
            path: 'create-chart',
            name: ReportCreateChartPage.name,
            pageBuilder: (context, state) {
              final id = Uri.decodeComponent(
                (state.pathParameters['reportId'] ?? '').trim(),
              );
              return _animatedPage(
                state: state,
                child: ReportCreateChartPage(reportId: id),
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
            quoteName: 'Project',
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
        path: ZohoIntegrationPage.path,
        name: ZohoIntegrationPage.name,
        pageBuilder: (context, state) => _animatedPage(
          state: state,
          child: const ZohoIntegrationPage(),
          beginOffset: const Offset(0.08, 0),
        ),
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
