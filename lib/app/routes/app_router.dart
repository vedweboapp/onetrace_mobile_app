import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/quote_composite_items_screen.dart';
import 'package:red5/features/dashboard/presentation/views/quote_details_page.dart';
import 'package:red5/features/login/presentation/views/login_page.dart';
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
          String? initialPdfUrl;
          String? initialPdfName;
          List<Map<String, dynamic>>? initialProducts;
          if (extra is String && extra.trim().isNotEmpty) {
            initialBlock = extra.trim();
          } else if (extra is Map) {
            final m = Map<String, dynamic>.from(extra);
            final b = m['initialBlockName'];
            final u = m['initialPdfUrl'];
            final n = m['initialPdfName'];
            final pr = m['initialProducts'];
            if (b is String && b.trim().isNotEmpty) initialBlock = b.trim();
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
