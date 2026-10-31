import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/app_router.dart';
import '../widgets/presentation_helpers.dart';

@RoutePage()
class TodayTabPage extends AutoRouter {
  const TodayTabPage({super.key});
}

@RoutePage()
class PlantsTabPage extends AutoRouter {
  const PlantsTabPage({super.key});
}

@RoutePage()
class RootShellPage extends StatelessWidget {
  const RootShellPage({super.key});
  @override
  Widget build(BuildContext context) => AutoTabsRouter(
    routes: const [TodayTabRoute(), PlantsTabRoute(), SettingsRoute()],
    builder: (context, child) {
      final s = strings(context);
      final tabs = AutoTabsRouter.of(context);
      return Scaffold(
        // Nested page scaffolds own keyboard avoidance. Resizing both layers
        // can leave no room for the preview banner at large text sizes.
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Semantics(
                liveRegion: false,
                child: Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    s.developmentNotice,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tabs.activeIndex,
          onDestinationSelected: tabs.setActiveIndex,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              label: s.today,
            ),
            NavigationDestination(
              icon: const Icon(Icons.yard_outlined),
              label: s.plants,
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune),
              label: s.settings,
            ),
          ],
        ),
      );
    },
  );
}
