import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// [RouteData] for for the initial page of an app.
///
/// Subclasses must override one of [build] or [redirect].
abstract class NeonAppRoute extends GoRouteData {
  const NeonAppRoute();

  @override
  Page<void> buildPage(final BuildContext context, final GoRouterState state) => NoTransitionPage(
        child: build(context, state),
      );
}

const appsRouteSuffix = '/apps/';
