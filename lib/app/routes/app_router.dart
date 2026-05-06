import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/app/routes/route_observers.dart';
import 'package:red5/core/auth/auth_session.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/dashboard/presentation/views/create_project_page.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/drawing_canvas_page.dart';
import 'package:red5/features/dashboard/presentation/views/project_details_page.dart';
import 'package:red5/features/dashboard/presentation/views/quote_composite_items_screen.dart';
import 'package:red5/features/dashboard/presentation/views/upload_drawing_page.dart';
import 'package:red5/features/dashboard/presentation/views/quote_details_page.dart';
import 'package:red5/features/clients/presentation/views/add_client_page.dart';
import 'package:red5/features/clients/presentation/views/client_detail_page.dart';
import 'package:red5/features/login/presentation/views/forgot_password_page.dart';
import 'package:red5/features/login/presentation/views/login_page.dart';
import 'package:red5/features/login/presentation/views/otp_verify_page.dart';
import 'package:red5/features/login/presentation/views/reset_password_page.dart';
import 'package:red5/features/quote/presentation/views/quote_project_page.dart';
import 'package:red5/features/splash/presentation/views/splash_page.dart';

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
  // Splash first; static preview (dart-define) only switches quote API, not entry route.
  return GoRouter(
    initialLocation: SplashPage.path,
    observers: <NavigatorObserver>[appRouteObserver],
    redirect: (context, state) {
      final storage = ref.read(localStorageProvider);
      final access = storage.getString(LocalStorageKeys.authAccessToken)?.trim();
      final isLoggedIn = AuthSession.isJwtValid(access);

      final location = state.matchedLocation.trim();
      final isSplash = location == SplashPage.path;
      final isLoginFlow = location.startsWith('/login');

      // Always allow splash + login flow routes.
      if (isSplash || isLoginFlow) {
        // If already logged in, keep user out of login flow screens.
        if (isLoggedIn && isLoginFlow) return DashboardPage.path;
        return null;
      }

      // Block all other routes when not authenticated.
      if (!isLoggedIn) return LoginPage.path;
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
          if (extra is Map) {
            summary = QuoteSummary.fromMap(Map<String, dynamic>.from(extra));
          } else if (extra is QuoteSummary) {
            summary = extra;
          }
          final id = state.pathParameters['projectId'] ?? '';
          summary ??= QuoteSummary(id: id, quoteName: 'Project', quoteNumber: '—');
          return _animatedPage(
            state: state,
            child: ProjectDetailsPage(project: summary),
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
            if (sd is String && sd.trim().isNotEmpty) initialStartDate = sd.trim();
            if (ed is String && ed.trim().isNotEmpty) initialEndDate = ed.trim();
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
